// ignore: fcheck_secrets

// A Flutter/Dart code quality analysis tool.
//
// This library provides functionality to analyze Flutter and Dart projects
// for code quality metrics including:
// - File and folder counts
// - Lines of code metrics
// - Comment ratio analysis
// - One class per file rule compliance
// - Hardcoded string detection
// - Source code member sorting validation
//
// Usage:
// ```dart
// import 'package:fcheck/fcheck.dart';
//
// final engine = AnalyzeFolder(projectDirectory);
// final metrics = engine.analyze();
// ```

import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegates.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner_result.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_analyzer.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_file_data.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/metrics/project_metrics.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The main engine for analyzing Flutter/Dart project quality.
///
/// This class provides comprehensive analysis of Dart projects, examining
/// code metrics, comment ratios, and compliance with coding standards.
/// It uses the Dart analyzer to parse source code and extract meaningful
/// quality metrics.
class AnalyzeFolder {
  /// The root directory of the project to analyze.
  final Directory projectDir;

  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// List of glob patterns to exclude from analysis.
  final List<String> excludePatterns;

  /// Creates a new analyzer engine for the specified project directory.
  ///
  /// [projectDir] should point to the root of a Flutter/Dart project.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  /// [excludePatterns] optional list of glob patterns to exclude files/folders.
  /// [ignoreConfig] optional configuration for global ignores.
  AnalyzeFolder(
    this.projectDir, {
    this.fix = false,
    this.excludePatterns = const [],
    this.ignoreConfig = const {},
    this.enabledAnalyzers,
  });

  /// Global ignore configuration from .fcheck file and constructor.
  final Map<String, bool> ignoreConfig;

  /// Explicit analyzer allowlist. When provided, it takes precedence.
  final Set<AnalyzerDomain>? enabledAnalyzers;

  /// Cached pubspec.yaml metadata for this analysis session.
  late final _PubspecInfo _pubspecInfo = _PubspecInfo.load(projectDir);

  bool _isAnalyzerEnabled(AnalyzerDomain analyzer) {
    final enabled = enabledAnalyzers;
    if (enabled != null) {
      return enabled.contains(analyzer);
    }
    return !(ignoreConfig[analyzer.configName] ?? false);
  }

  /// Analyzes the layers architecture and returns the result.
  ///
  /// This method performs dependency analysis and layer assignment
  /// for the project.
  ///
  /// Returns a [LayersAnalysisResult] containing issues and layer assignments.
  LayersAnalysisResult analyzeLayers() {
    if (!_isAnalyzerEnabled(AnalyzerDomain.layers)) {
      return LayersAnalysisResult(
        issues: [],
        layers: {},
        dependencyGraph: {},
      );
    }

    final pubspecInfo = _pubspecInfo;
    final projectRoot = pubspecInfo.projectRoot ?? projectDir;
    final unifiedAnalyzer = AnalyzerRunner(
      projectDir: projectDir,
      excludePatterns: excludePatterns,
      delegates: [
        LayersDelegate(projectRoot, pubspecInfo.packageName),
      ],
    );
    final unifiedResult = unifiedAnalyzer.analyzeAll();
    final layersFileData = _extractLayersFileData(unifiedResult);

    final layersAnalyzer = LayersAnalyzer(
      projectDir,
      projectRoot: projectRoot,
      packageName: pubspecInfo.packageName,
    );
    return layersAnalyzer.analyzeFromFileData(
      layersFileData,
    );
  }

  /// Lists all excluded files and directories in the project.
  ///
  /// This method identifies files and directories that are excluded from analysis
  /// due to hidden directories, default excluded directories, or custom exclude patterns.
  /// This is useful for understanding what files are being skipped during analysis.
  ///
  /// Returns a tuple containing:
  /// - List of excluded Dart files
  /// - List of excluded non-Dart files
  /// - List of excluded directories
  ///
  /// Example usage:
  /// ```dart
  /// final engine = AnalyzeFolder(projectDir);
  /// final (excludedDart, excludedNonDart, excludedDirs) = engine.listExcludedFiles();
  /// final excludedCount = excludedDart.length;
  /// ```
  (
    List<File> excludedDartFiles,
    List<File> excludedNonDartFiles,
    List<Directory> excludedDirectories
  ) listExcludedFiles() {
    return FileUtils.listExcludedFiles(
      projectDir,
      excludePatterns: excludePatterns,
    );
  }

  /// Analyzes the entire project and returns comprehensive quality metrics.
  ///
  /// This method performs all analysis types in a single file traversal,
  /// significantly improving performance by eliminating redundant file operations.
  /// Each file is parsed once and the results are shared across all analyzers.
  ///
  /// Returns a [ProjectMetrics] object with complete analysis results.
  ProjectMetrics analyze() {
    final pubspecInfo = _pubspecInfo;
    final projectRoot = pubspecInfo.projectRoot ?? projectDir;

    // Perform unified directory scan to get all file system metrics in one pass
    final (
      dartFiles,
      totalFolders,
      totalFiles,
      excludedDartFilesCount,
      excludedFoldersCount,
      excludedFilesCount
    ) = FileUtils.scanDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );
    final projectVersion = pubspecInfo.version;
    final projectName = pubspecInfo.name;
    final projectType = pubspecInfo.projectType;
    final oneClassPerFileEnabled =
        _isAnalyzerEnabled(AnalyzerDomain.oneClassPerFile);
    final hardcodedStringsEnabled =
        _isAnalyzerEnabled(AnalyzerDomain.hardcodedStrings);
    final magicNumbersEnabled = _isAnalyzerEnabled(AnalyzerDomain.magicNumbers);
    final sourceSortingEnabled =
        _isAnalyzerEnabled(AnalyzerDomain.sourceSorting);
    final layersEnabled = _isAnalyzerEnabled(AnalyzerDomain.layers);
    final secretsEnabled = _isAnalyzerEnabled(AnalyzerDomain.secrets);
    final deadCodeEnabled = _isAnalyzerEnabled(AnalyzerDomain.deadCode);
    final hardcodedStringsFocus = projectType == ProjectType.flutter
        ? HardcodedStringFocus.flutterWidgets
        : projectType == ProjectType.dart
            ? HardcodedStringFocus.dartPrint
            : HardcodedStringFocus.general;

    // Build delegates for unified analysis
    final delegates = <AnalyzerDelegate>[
      if (hardcodedStringsEnabled)
        HardcodedStringDelegate(focus: hardcodedStringsFocus),
      if (magicNumbersEnabled) MagicNumberDelegate(),
      if (sourceSortingEnabled) SourceSortDelegate(fix: fix),
      if (layersEnabled) LayersDelegate(projectRoot, pubspecInfo.packageName),
      if (secretsEnabled) SecretDelegate(),
      if (deadCodeEnabled)
        DeadCodeDelegate(
          projectRoot: projectRoot,
          packageName: pubspecInfo.packageName,
        ),
    ];

    // Perform unified analysis
    final unifiedAnalyzer = AnalyzerRunner(
      projectDir: projectDir,
      excludePatterns: excludePatterns,
      delegates: delegates,
    );

    final unifiedResult = unifiedAnalyzer.analyzeAll();

    // Extract results from unified analysis
    final allListResults =
        unifiedResult.getResults<List<dynamic>>() ?? <List<dynamic>>[];

    // Separate results by type
    final hardcodedStringIssues =
        allListResults.whereType<HardcodedStringIssue>().toList();
    final magicNumberIssues =
        allListResults.whereType<MagicNumberIssue>().toList();
    final sourceSortIssues =
        allListResults.whereType<SourceSortIssue>().toList();
    final secretIssues = allListResults.whereType<SecretIssue>().toList();

    final deadCodeFileDataRaw = deadCodeEnabled
        ? (unifiedResult.resultsByType[DeadCodeFileData] ?? <dynamic>[])
        : <dynamic>[];
    final deadCodeIssues = deadCodeEnabled
        ? DeadCodeAnalyzer(
            projectRoot: projectRoot,
            packageName: pubspecInfo.packageName,
            projectType: projectType,
          ).analyze(deadCodeFileDataRaw.whereType<DeadCodeFileData>().toList())
        : <DeadCodeIssue>[];

    final layersResult = layersEnabled
        ? LayersAnalyzer(
            projectDir,
            projectRoot: projectRoot,
            packageName: pubspecInfo.packageName,
          ).analyzeFromFileData(
            _extractLayersFileData(unifiedResult),
            analyzedFilePaths: dartFiles.map((file) => file.path).toSet(),
          )
        : LayersAnalysisResult(
            issues: [],
            layers: {},
            dependencyGraph: {},
          );

    // File metrics analysis (still needed for LOC and comment analysis)
    final fileMetricsList = <FileMetrics>[];
    int totalLoc = 0;
    int totalComments = 0;

    for (var file in dartFiles) {
      final metrics = analyzeFile(
        file,
        globallyIgnoreOneClassPerFile: !oneClassPerFileEnabled,
      );
      fileMetricsList.add(metrics);
      totalLoc += metrics.linesOfCode;
      totalComments += metrics.commentLines;
    }

    final usesLocalization = detectLocalization(dartFiles);

    return ProjectMetrics(
      totalFolders: totalFolders,
      totalFiles: totalFiles,
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: totalLoc,
      totalCommentLines: totalComments,
      fileMetrics: fileMetricsList,
      hardcodedStringIssues: hardcodedStringIssues,
      magicNumberIssues: magicNumberIssues,
      sourceSortIssues: sourceSortIssues,
      layersIssues: layersResult.issues,
      layersEdgeCount: layersResult.edgeCount,
      layersCount: layersResult.layerCount,
      dependencyGraph: layersResult.dependencyGraph,
      projectName: projectName,
      projectType: projectType,
      version: projectVersion,
      usesLocalization: usesLocalization,
      excludedFilesCount: excludedDartFilesCount,
      secretIssues: secretIssues,
      deadCodeIssues: deadCodeIssues,
      oneClassPerFileAnalyzerEnabled: oneClassPerFileEnabled,
      hardcodedStringsAnalyzerEnabled: hardcodedStringsEnabled,
      magicNumbersAnalyzerEnabled: magicNumbersEnabled,
      sourceSortingAnalyzerEnabled: sourceSortingEnabled,
      layersAnalyzerEnabled: layersEnabled,
      secretsAnalyzerEnabled: secretsEnabled,
      deadCodeAnalyzerEnabled: deadCodeEnabled,
    );
  }

  List<Map<String, dynamic>> _extractLayersFileData(
    AnalysisRunnerResult unifiedResult,
  ) {
    final layersFileData = <Map<String, dynamic>>[];
    for (final typeResults in unifiedResult.resultsByType.values) {
      for (final result in typeResults) {
        if (result is! Map<String, dynamic>) {
          continue;
        }
        final filePath = result['filePath'];
        final dependencies = result['dependencies'];
        final isEntryPoint = result['isEntryPoint'];
        if (filePath is String &&
            dependencies is List<String> &&
            isEntryPoint is bool) {
          layersFileData.add(result);
        }
      }
    }
    return layersFileData;
  }

  /// Analyzes a single Dart file and returns its metrics.
  ///
  /// This method parses a single Dart file using the Dart analyzer and
  /// extracts quality metrics including:
  /// - Lines of code
  /// - Comment lines
  /// - Class count
  /// - StatefulWidget detection
  /// - One class per file compliance
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a [FileMetrics] object containing quality metrics for the file.
  FileMetrics analyzeFile(
    File file, {
    bool globallyIgnoreOneClassPerFile = false,
  }) {
    final content = file.readAsStringSync();
    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final hasIgnoreDirective = hasIgnoreOneClassPerFileDirective(content);
    final ignoreOneClassPerFile =
        hasIgnoreDirective || globallyIgnoreOneClassPerFile;

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return FileMetrics(
        path: file.path,
        linesOfCode: 0,
        commentLines: 0,
        classCount: 0,
        isStatefulWidget: false,
        ignoreOneClassPerFile: ignoreOneClassPerFile,
      );
    }

    final CompilationUnit unit = result.unit;
    final List<String> lines = content.split('\n');
    final int commentLines = countCommentLines(unit, lines);
    final _QualityVisitor visitor = _QualityVisitor();
    unit.accept(visitor);

    return FileMetrics(
      path: file.path,
      linesOfCode: lines.length,
      commentLines: commentLines,
      classCount: visitor.classCount,
      isStatefulWidget: visitor.hasStatefulWidget,
      ignoreOneClassPerFile: ignoreOneClassPerFile,
    );
  }

  /// Counts the number of comment lines in a Dart file.
  ///
  /// This method counts lines that contain Dart comment markers:
  /// - `//` (single-line or documentation comments)
  /// - `/*` (start of block comment)
  /// - `*/` (end of block comment)
  ///
  /// It counts a line as a comment line if it starts with a marker or
  /// contains a marker (even if preceded by code).
  ///
  /// [unit] The parsed compilation unit (currently unused in this implementation).
  /// [lines] The raw lines of the file.
  ///
  /// Returns the number of lines that contain comments.
  int countCommentLines(CompilationUnit _, List<String> lines) {
    // This is a simplified comment counter.
    // The analyzer's beginToken/endToken are useful for more complex scenarios.
    // We'll count lines that contain comments.
    int count = 0;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('/*') ||
          trimmed.endsWith('*/')) {
        count++;
      } else if (trimmed.contains('//') || trimmed.contains('/*')) {
        // Part of the line is a comment
        count++;
      }
    }
    return count;
  }

  /// Checks for a top-of-file directive to ignore the "one class per file" rule.
  ///
  /// The directive must appear in the leading comment block(s) at the top of
  /// the file (before any code). Example:
  /// ```dart
  /// // ignore: fcheck_one_class_per_file
  /// ```
  bool hasIgnoreOneClassPerFileDirective(String content) {
    return IgnoreConfig.hasIgnoreForFileDirective(
      content,
      IgnoreConfig.ignoreDirectiveForOneClassPerFile,
    );
  }

  /// Heuristically detects whether the project uses Flutter localization.
  ///
  /// Signals localization when:
  /// - `l10n.yaml` exists, or
  /// - `.arb` files are present (commonly under lib/l10n), or
  /// - Source files reference `AppLocalizations` / `flutter_gen/gen_l10n`.
  bool detectLocalization(List<File> dartFiles) {
    final l10nConfig = File(p.join(projectDir.path, 'l10n.yaml'));
    if (l10nConfig.existsSync()) {
      return true;
    }

    final l10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    if (l10nDir.existsSync()) {
      final hasArb = l10nDir
          .listSync(recursive: true)
          .whereType<File>()
          .any((f) => f.path.endsWith('.arb'));
      if (hasArb) {
        return true;
      }
    }

    final arbAnywhere = projectDir
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('.arb'));
    if (arbAnywhere) {
      return true;
    }

    final appLocImport = RegExp(
      r'''^\s*import\s+["']package:flutter_gen/gen_l10n/app_localizations\.dart["'];''',
      multiLine: true,
    );

    for (final file in dartFiles) {
      try {
        final content = file.readAsStringSync();
        if (appLocImport.hasMatch(content)) {
          return true;
        }
      } catch (_) {
        // Ignore unreadable files
      }
    }
    return false;
  }
}

/// Parsed pubspec.yaml metadata for a project.
class _PubspecInfo {
  final Directory? projectRoot;
  final String name;
  final String version;
  final ProjectType projectType;

  const _PubspecInfo({
    required this.projectRoot,
    required this.name,
    required this.version,
    required this.projectType,
  });

  String get packageName => name;

  static _PubspecInfo load(Directory startDir) {
    Directory? currentDir = startDir;

    while (currentDir != null) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        try {
          final yaml = loadYaml(pubspecFile.readAsStringSync());
          if (yaml is YamlMap) {
            final name = _readStringField(yaml, 'name');
            final version = _readStringField(yaml, 'version');
            final projectType = _detectProjectType(yaml);
            return _PubspecInfo(
              projectRoot: currentDir,
              name: name,
              version: version,
              projectType: projectType,
            );
          }
          return _PubspecInfo(
            projectRoot: currentDir,
            name: 'unknown',
            version: 'unknown',
            projectType: ProjectType.dart,
          );
        } catch (_) {
          return _PubspecInfo(
            projectRoot: currentDir,
            name: 'unknown',
            version: 'unknown',
            projectType: ProjectType.unknown,
          );
        }
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    return const _PubspecInfo(
      projectRoot: null,
      name: 'unknown',
      version: 'unknown',
      projectType: ProjectType.unknown,
    );
  }

  static String _readStringField(YamlMap yaml, String field) {
    final value = yaml[field];
    if (value == null) {
      return 'unknown';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  static ProjectType _detectProjectType(YamlMap yaml) {
    final dependencies = yaml['dependencies'];
    if (dependencies is YamlMap && dependencies.containsKey('flutter')) {
      return ProjectType.flutter;
    }
    final devDependencies = yaml['dev_dependencies'];
    if (devDependencies is YamlMap && devDependencies.containsKey('flutter')) {
      return ProjectType.flutter;
    }
    return ProjectType.dart;
  }
}

/// A visitor that traverses the AST to collect quality metrics.
///
/// This internal visitor class extends the analyzer's AST visitor to
/// count class declarations and detect StatefulWidget usage in Dart files.
/// It accumulates metrics during the AST traversal process.
///
/// Only public classes (not starting with `_`) are counted for the
/// "one class per file" rule checks.
class _QualityVisitor extends RecursiveAstVisitor<void> {
  /// The total number of public class declarations found in the visited file.
  int classCount = 0;

  /// Whether any of the classes in the file extend StatefulWidget.
  ///
  /// This affects the "one class per file" rule compliance, as StatefulWidget
  /// files are allowed to have up to 2 classes (widget + state).
  bool hasStatefulWidget = false;

  /// Visits a class declaration node in the AST.
  ///
  /// This method is called for each class declaration encountered during
  /// AST traversal. It increments the class count (if the class is public)
  /// and checks if the class extends StatefulWidget.
  ///
  /// [node] The class declaration node being visited.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.toString();

    // Only count public classes for the "one class per file" rule
    // Private classes (starting with _) are implementation details
    if (!className.startsWith('_')) {
      classCount++;
    }

    final superclass = node.extendsClause?.superclass.toString();
    if (superclass == 'StatefulWidget') {
      hasStatefulWidget = true;
    }

    super.visitClassDeclaration(node);
  }
}
