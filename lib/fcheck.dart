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
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner_result.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_analyzer.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_delegate.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_file_data.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_analyzer.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_delegate.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_analyzer.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_delegate.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_file_data.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_delegate.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_delegate.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_delegate.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_delegate.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/source_sort_delegate.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_delegate.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_file_data.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_analyzer.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/project_type.dart';
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

  /// Similarity threshold used by duplicate-code analysis.
  ///
  /// This value typically comes from `.fcheck` configuration (default `0.90`)
  /// when invoked through the CLI.
  final double duplicateCodeSimilarityThreshold;

  /// Minimum normalized token count for duplicate-code snippets.
  final int duplicateCodeMinTokenCount;

  /// Minimum non-empty lines for duplicate-code snippets.
  final int duplicateCodeMinNonEmptyLineCount;

  /// Creates a new analyzer engine for the specified project directory.
  ///
  /// [projectDir] should point to the root of a Flutter/Dart project.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  /// [excludePatterns] optional list of glob patterns to exclude files/folders.
  /// [ignoreConfig] optional configuration for global ignores.
  /// [duplicateCodeSimilarityThreshold] minimum similarity ratio for duplicates.
  /// CLI usage typically provides this from `.fcheck` (default `0.90`).
  /// [duplicateCodeMinTokenCount] minimum normalized tokens for snippets.
  /// [duplicateCodeMinNonEmptyLineCount] minimum non-empty lines for snippets.
  AnalyzeFolder(
    this.projectDir, {
    this.fix = false,
    this.excludePatterns = const [],
    this.ignoreConfig = const {},
    this.enabledAnalyzers,
    this.duplicateCodeSimilarityThreshold =
        DuplicateCodeAnalyzer.defaultSimilarityThreshold,
    this.duplicateCodeMinTokenCount =
        DuplicateCodeDelegate.defaultMinTokenCount,
    this.duplicateCodeMinNonEmptyLineCount =
        DuplicateCodeDelegate.defaultMinNonEmptyLineCount,
  });

  /// Global ignore configuration from .fcheck file and constructor.
  final Map<String, bool> ignoreConfig;

  /// Explicit analyzer allowlist. When provided, it takes precedence.
  final Set<AnalyzerDomain>? enabledAnalyzers;

  /// Cached pubspec.yaml metadata for this analysis session.
  late final _PubspecInfo _pubspecInfo = _PubspecInfo.load(projectDir);

  /// Resolves whether [analyzer] should run for this analysis pass.
  ///
  /// When [enabledAnalyzers] is provided it acts as an explicit allowlist.
  /// Otherwise the legacy `ignoreConfig` disabled flags are applied.
  bool _isAnalyzerEnabled(AnalyzerDomain analyzer) {
    final enabled = enabledAnalyzers;
    if (enabled != null) {
      return enabled.contains(analyzer);
    }
    return !(ignoreConfig[analyzer.configName] ?? false);
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
    final (dartFiles, totalFolders, totalFiles, excludedDartFilesCount, _, _) =
        FileUtils.scanDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );
    final customExcludedDartFilesCount = FileUtils.countCustomExcludedDartFiles(
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
    final duplicateCodeEnabled =
        _isAnalyzerEnabled(AnalyzerDomain.duplicateCode);
    final documentationEnabled =
        _isAnalyzerEnabled(AnalyzerDomain.documentation);
    final hardcodedStringsFocus = projectType == ProjectType.flutter
        ? HardcodedStringFocus.flutterWidgets
        : projectType == ProjectType.dart
            ? HardcodedStringFocus.dartPrint
            : HardcodedStringFocus.general;

    final usesLocalization = detectLocalization(dartFiles);

    // Build delegates for unified analysis
    final delegates = <AnalyzerDelegate>[
      MetricsDelegate(globallyIgnoreOneClassPerFile: !oneClassPerFileEnabled),
      if (hardcodedStringsEnabled)
        HardcodedStringDelegate(
          focus: hardcodedStringsFocus,
          usesLocalization: usesLocalization,
        ),
      if (magicNumbersEnabled) MagicNumberDelegate(),
      if (sourceSortingEnabled) SourceSortDelegate(fix: fix),
      if (layersEnabled) LayersDelegate(projectRoot, pubspecInfo.packageName),
      if (secretsEnabled) SecretDelegate(),
      if (duplicateCodeEnabled)
        DuplicateCodeDelegate(
          minTokenCount: duplicateCodeMinTokenCount,
          minNonEmptyLineCount: duplicateCodeMinNonEmptyLineCount,
        ),
      if (deadCodeEnabled)
        DeadCodeDelegate(
          projectRoot: projectRoot,
          packageName: pubspecInfo.packageName,
        ),
      if (documentationEnabled) DocumentationDelegate(),
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
    final documentationIssuesRaw =
        allListResults.whereType<DocumentationIssue>().toList();
    final duplicateCodeFileDataRaw = duplicateCodeEnabled
        ? (unifiedResult.resultsByType[DuplicateCodeFileData] ?? <dynamic>[])
        : <dynamic>[];

    final duplicateCodeIssues = duplicateCodeEnabled
        ? DuplicateCodeAnalyzer(
            similarityThreshold: duplicateCodeSimilarityThreshold,
          ).analyze(
            duplicateCodeFileDataRaw
                .whereType<DuplicateCodeFileData>()
                .toList(),
          )
        : <DuplicateCodeIssue>[];

    final deadCodeFileDataRaw = deadCodeEnabled
        ? (unifiedResult.resultsByType[DeadCodeFileData] ?? <dynamic>[])
        : <dynamic>[];
    final deadCodeIssues = deadCodeEnabled
        ? _toRelativeDeadCodeIssues(
            DeadCodeAnalyzer(
              projectRoot: projectRoot,
              packageName: pubspecInfo.packageName,
              projectType: projectType,
            ).analyze(
              deadCodeFileDataRaw.whereType<DeadCodeFileData>().toList(),
            ),
            analysisRootPath: projectDir.path,
          )
        : <DeadCodeIssue>[];
    final documentationIssues = documentationEnabled
        ? _toRelativeDocumentationIssues(
            DocumentationAnalyzer(
              projectRoot: projectRoot,
            ).analyze(
              documentationIssuesRaw,
            ),
            analysisRootPath: projectDir.path,
          )
        : <DocumentationIssue>[];

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

    // Extract file metrics from unified results using metrics analyzer
    final metricsAggregation = MetricsAnalyzer().aggregate(
      unifiedResult.resultsByType[MetricsFileData]
              ?.cast<MetricsFileData>()
              .toList() ??
          [],
    );

    return ProjectMetrics(
      totalFolders: totalFolders,
      totalFiles: totalFiles,
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: metricsAggregation.totalLinesOfCode,
      totalCommentLines: metricsAggregation.totalCommentLines,
      totalFunctionCount: metricsAggregation.totalFunctionCount,
      totalStringLiteralCount: metricsAggregation.totalStringLiteralCount,
      totalNumberLiteralCount: metricsAggregation.totalNumberLiteralCount,
      fileMetrics: metricsAggregation.fileMetrics,
      hardcodedStringIssues: hardcodedStringIssues,
      magicNumberIssues: magicNumberIssues,
      sourceSortIssues: sourceSortIssues,
      layersIssues: layersResult.issues,
      layersEdgeCount: layersResult.edgeCount,
      layersCount: layersResult.layerCount,
      dependencyGraph: layersResult.dependencyGraph,
      layersByFile: layersResult.layers,
      projectName: projectName,
      projectType: projectType,
      version: projectVersion,
      usesLocalization: usesLocalization,
      excludedFilesCount: excludedDartFilesCount,
      customExcludedFilesCount: customExcludedDartFilesCount,
      ignoreDirectivesCount: metricsAggregation.ignoreDirectivesCount,
      ignoreDirectiveFiles:
          metricsAggregation.ignoreDirectiveCountsByFile.keys.toList(),
      ignoreDirectiveCountsByFile:
          metricsAggregation.ignoreDirectiveCountsByFile,
      secretIssues: secretIssues,
      documentationIssues: documentationIssues,
      duplicateCodeIssues: duplicateCodeIssues,
      deadCodeIssues: deadCodeIssues,
      oneClassPerFileAnalyzerEnabled: oneClassPerFileEnabled,
      hardcodedStringsAnalyzerEnabled: hardcodedStringsEnabled,
      magicNumbersAnalyzerEnabled: magicNumbersEnabled,
      sourceSortingAnalyzerEnabled: sourceSortingEnabled,
      layersAnalyzerEnabled: layersEnabled,
      secretsAnalyzerEnabled: secretsEnabled,
      deadCodeAnalyzerEnabled: deadCodeEnabled,
      duplicateCodeAnalyzerEnabled: duplicateCodeEnabled,
      documentationAnalyzerEnabled: documentationEnabled,
    );
  }

  /// Extracts validated layer input maps from unified analyzer results.
  ///
  /// Only entries containing `filePath`, `dependencies`, and `isEntryPoint`
  /// with expected runtime types are preserved.
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

  /// Converts documentation issue paths to be relative to [analysisRootPath].
  List<DocumentationIssue> _toRelativeDocumentationIssues(
    List<DocumentationIssue> issues, {
    required String analysisRootPath,
  }) {
    if (issues.isEmpty) {
      return const <DocumentationIssue>[];
    }

    final normalizedRoot =
        p.normalize(Directory(analysisRootPath).absolute.path);
    return issues
        .map(
          (issue) => DocumentationIssue(
            type: issue.type,
            filePath: _toRelativePathForDisplay(issue.filePath,
                normalizedRootPath: normalizedRoot),
            lineNumber: issue.lineNumber,
            subject: issue.subject,
          ),
        )
        .toList(growable: false);
  }

  /// Converts dead-code issue paths to be relative to [analysisRootPath].
  List<DeadCodeIssue> _toRelativeDeadCodeIssues(
    List<DeadCodeIssue> issues, {
    required String analysisRootPath,
  }) {
    if (issues.isEmpty) {
      return const <DeadCodeIssue>[];
    }

    final normalizedRoot =
        p.normalize(Directory(analysisRootPath).absolute.path);
    return issues
        .map(
          (issue) => DeadCodeIssue(
            type: issue.type,
            filePath: _toRelativePathForDisplay(issue.filePath,
                normalizedRootPath: normalizedRoot),
            lineNumber: issue.lineNumber,
            name: issue.name,
            owner: issue.owner,
          ),
        )
        .toList(growable: false);
  }

  /// Returns [path] rebased to [normalizedRootPath] for user-facing output.
  String _toRelativePathForDisplay(
    String path, {
    required String normalizedRootPath,
  }) {
    if (path.isEmpty) {
      return path;
    }

    final absolutePath = p.isAbsolute(path)
        ? p.normalize(path)
        : p.normalize(p.join(normalizedRootPath, path));
    return p.relative(absolutePath, from: normalizedRootPath);
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

  /// Package identifier resolved from `pubspec.yaml`.
  ///
  /// This alias keeps call sites explicit when they need a package-style name
  /// instead of the generic project [name] field.
  String get packageName => name;

  /// Resolves project metadata from `pubspec.yaml` for [startDir].
  ///
  /// Resolution order:
  /// 1. Normalize [startDir] to an absolute path.
  /// 2. Walk upward from [startDir] to the filesystem root and use the first
  ///    `pubspec.yaml` found.
  /// 3. If no ancestor pubspec exists, inspect Dart files under [startDir] and
  ///    resolve each file to its nearest ancestor `pubspec.yaml` inside
  ///    [startDir].
  /// 4. If all Dart files map to one unique descendant pubspec, use that
  ///    metadata.
  ///
  /// Returns `unknown` metadata when no pubspec can be resolved or when
  /// multiple descendant pubspecs are discovered (ambiguous/monorepo layout).
  static _PubspecInfo load(Directory startDir) {
    final normalizedStartDir = Directory(p.normalize(startDir.absolute.path));
    Directory? currentDir = normalizedStartDir;

    while (currentDir != null) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return _loadFromPubspecFile(pubspecFile, currentDir);
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    final descendantPubspecInfo =
        _loadFromSingleDescendantPubspec(normalizedStartDir);
    if (descendantPubspecInfo != null) {
      return descendantPubspecInfo;
    }

    return _unknown();
  }

  /// Attempts to resolve pubspec metadata from a single descendant package.
  ///
  /// Returns `null` when no Dart files exist, any Dart file cannot be mapped
  /// to a pubspec under [startDir], or multiple pubspec roots are discovered.
  static _PubspecInfo? _loadFromSingleDescendantPubspec(Directory startDir) {
    final dartFiles = FileUtils.listDartFiles(startDir);
    if (dartFiles.isEmpty) {
      return null;
    }

    final Set<String> pubspecPaths = <String>{};
    final Map<String, File> pubspecByPath = <String, File>{};
    for (final dartFile in dartFiles) {
      final pubspecFile = _findNearestPubspecForFile(
        dartFile: dartFile,
        rootDirectory: startDir,
      );
      if (pubspecFile == null) {
        return null;
      }

      final pubspecPath = p.normalize(pubspecFile.absolute.path);
      pubspecPaths.add(pubspecPath);
      pubspecByPath[pubspecPath] = pubspecFile;

      if (pubspecPaths.length > 1) {
        return null;
      }
    }

    if (pubspecPaths.length != 1) {
      return null;
    }

    final pubspecFile = pubspecByPath[pubspecPaths.single];
    if (pubspecFile == null) {
      return null;
    }

    return _loadFromPubspecFile(pubspecFile, pubspecFile.parent);
  }

  /// Finds the closest ancestor `pubspec.yaml` for a Dart file inside root.
  static File? _findNearestPubspecForFile({
    required File dartFile,
    required Directory rootDirectory,
  }) {
    final normalizedRootPath = p.normalize(rootDirectory.absolute.path);
    Directory currentDir = dartFile.parent;

    while (_isSameOrWithin(normalizedRootPath, currentDir.absolute.path)) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return pubspecFile;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    return null;
  }

  /// Internal helper used by fcheck analysis and reporting.
  static bool _isSameOrWithin(String rootPath, String candidatePath) {
    final normalizedRootPath = p.normalize(rootPath);
    final normalizedCandidatePath = p.normalize(candidatePath);
    return normalizedRootPath == normalizedCandidatePath ||
        p.isWithin(normalizedRootPath, normalizedCandidatePath);
  }

  /// Parses project metadata from a concrete `pubspec.yaml` file.
  static _PubspecInfo _loadFromPubspecFile(
    File pubspecFile,
    Directory projectRoot,
  ) {
    try {
      final yaml = loadYaml(pubspecFile.readAsStringSync());
      if (yaml is YamlMap) {
        final name = _readStringField(yaml, 'name');
        final version = _readStringField(yaml, 'version');
        final projectType = _detectProjectType(yaml);
        return _PubspecInfo(
          projectRoot: projectRoot,
          name: name,
          version: version,
          projectType: projectType,
        );
      }
      return _PubspecInfo(
        projectRoot: projectRoot,
        name: 'unknown',
        version: 'unknown',
        projectType: ProjectType.dart,
      );
    } catch (_) {
      return _PubspecInfo(
        projectRoot: projectRoot,
        name: 'unknown',
        version: 'unknown',
        projectType: ProjectType.unknown,
      );
    }
  }

  /// Internal helper used by fcheck analysis and reporting.
  static _PubspecInfo _unknown() {
    return const _PubspecInfo(
      projectRoot: null,
      name: 'unknown',
      version: 'unknown',
      projectType: ProjectType.unknown,
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
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

  /// Internal helper used by fcheck analysis and reporting.
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
