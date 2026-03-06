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

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner_result.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_delegate.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_file_data.dart';
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
import 'package:fcheck/src/analyzers/metrics/metrics_analyzer.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_delegate.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_file_data.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/analyzers/secrets/secret_delegate.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/shared/dependency_uri_utils.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/source_sort_delegate.dart';
import 'package:fcheck/src/fcheck_pubspec_info.dart';
import 'package:fcheck/src/fcheck_test_summary.dart';
import 'package:fcheck/src/fcheck_test_visitor.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/models/code_size_thresholds.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:path/path.dart' as p;

const Set<String> _testDirectoryNames = {'test', 'integration_test'};
const String _androidPlatformFolder = 'android';
const String _iosPlatformFolder = 'ios';
const String _macosPlatformFolder = 'macos';
const String _windowsPlatformFolder = 'windows';
const String _linuxPlatformFolder = 'linux';
const String _webPlatformFolder = 'web';

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

  /// LOC thresholds used by code-size analyzer scoring/reporting.
  final CodeSizeThresholds codeSizeThresholds;

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
  /// [codeSizeThresholds] oversized LOC thresholds for file/class/function/method.
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
    this.codeSizeThresholds = const CodeSizeThresholds(),
  });

  /// Global ignore configuration from .fcheck file and constructor.
  final Map<String, bool> ignoreConfig;

  /// Explicit analyzer allowlist. When provided, it takes precedence.
  final Set<AnalyzerDomain>? enabledAnalyzers;

  /// Cached pubspec.yaml metadata for this analysis session.
  late final PubspecInfo _pubspecInfo = PubspecInfo.load(projectDir);

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
    List<Directory> excludedDirectories,
  )
  listExcludedFiles() {
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

    final (
      dartFiles,
      totalFolders,
      totalFiles,
      excludedDartFilesCount,
      _,
      _,
      testDirectoriesCount,
      testFilesCount,
      testDartFilesCount,
    ) = FileUtils.scanDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );
    final customExcludedDartFilesCount = FileUtils.countCustomExcludedDartFiles(
      projectDir,
      excludePatterns: excludePatterns,
    );
    final testCaseCount = _countTestCases();
    final projectVersion = pubspecInfo.version;
    final projectName = pubspecInfo.name;
    final projectType = pubspecInfo.projectType;
    final supportedPlatforms = _detectSupportedPlatforms(projectRoot);
    final oneClassPerFileEnabled = _isAnalyzerEnabled(
      AnalyzerDomain.oneClassPerFile,
    );
    final codeSizeEnabled = _isAnalyzerEnabled(AnalyzerDomain.codeSize);
    final hardcodedStringsEnabled = _isAnalyzerEnabled(
      AnalyzerDomain.hardcodedStrings,
    );
    final magicNumbersEnabled = _isAnalyzerEnabled(AnalyzerDomain.magicNumbers);
    final sourceSortingEnabled = _isAnalyzerEnabled(
      AnalyzerDomain.sourceSorting,
    );
    final layersEnabled = _isAnalyzerEnabled(AnalyzerDomain.layers);
    final secretsEnabled = _isAnalyzerEnabled(AnalyzerDomain.secrets);
    final deadCodeEnabled = _isAnalyzerEnabled(AnalyzerDomain.deadCode);
    final duplicateCodeEnabled = _isAnalyzerEnabled(
      AnalyzerDomain.duplicateCode,
    );
    final documentationEnabled = _isAnalyzerEnabled(
      AnalyzerDomain.documentation,
    );
    final hardcodedStringsFocus = projectType == ProjectType.flutter
        ? HardcodedStringFocus.flutterWidgets
        : projectType == ProjectType.dart
        ? HardcodedStringFocus.dartPrint
        : HardcodedStringFocus.general;

    final usesLocalization = detectLocalization(dartFiles);
    final delegates = <AnalyzerDelegate>[
      MetricsDelegate(globallyIgnoreOneClassPerFile: !oneClassPerFileEnabled),
      if (codeSizeEnabled) CodeSizeDelegate(),
      if (hardcodedStringsEnabled)
        HardcodedStringDelegate(
          focus: hardcodedStringsFocus,
          usesLocalization: usesLocalization,
        ),
      if (magicNumbersEnabled) MagicNumberDelegate(),
      if (sourceSortingEnabled)
        SourceSortDelegate(fix: fix, packageName: pubspecInfo.packageName),
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

    final unifiedAnalyzer = AnalyzerRunner(
      projectDir: projectDir,
      excludePatterns: excludePatterns,
      delegates: delegates,
    );

    final unifiedResult = unifiedAnalyzer.analyzeAll();
    final allListResults =
        unifiedResult.getResults<List<dynamic>>() ?? <List<dynamic>>[];

    final hardcodedStringIssues = allListResults
        .whereType<HardcodedStringIssue>()
        .toList();
    final magicNumberIssues = allListResults
        .whereType<MagicNumberIssue>()
        .toList();
    final sourceSortIssues = allListResults
        .whereType<SourceSortIssue>()
        .toList();
    final secretIssues = allListResults.whereType<SecretIssue>().toList();
    final documentationIssuesRaw = allListResults
        .whereType<DocumentationIssue>()
        .toList();
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
            ).analyze(documentationIssuesRaw),
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
        : LayersAnalysisResult(issues: [], layers: {}, dependencyGraph: {});

    final metricsAggregation = MetricsAnalyzer().aggregate(
      unifiedResult.resultsByType[MetricsFileData]
              ?.cast<MetricsFileData>()
              .toList() ??
          [],
    );
    final projectDependencyGraph = _buildProjectDependencyGraph(
      dartFiles,
      rootPath: projectRoot.path,
      packageName: pubspecInfo.packageName,
    );
    final testConsumption = _analyzeTestConsumption(
      dependencyGraph: projectDependencyGraph,
      fileMetrics: metricsAggregation.fileMetrics,
      rootPath: projectRoot.path,
      packageName: pubspecInfo.packageName,
      analysisRootPath: projectDir.path,
    );
    final codeSizeArtifacts = codeSizeEnabled
        ? _collectCodeSizeArtifacts(
            unifiedResult,
            metricsAggregation.fileMetrics,
          )
        : <CodeSizeArtifact>[];

    return ProjectMetrics(
      totalFolders: totalFolders,
      totalFiles: totalFiles,
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: metricsAggregation.totalLinesOfCode,
      totalCommentLines: metricsAggregation.totalCommentLines,
      totalFunctionCount: metricsAggregation.totalFunctionCount,
      totalStringLiteralCount: metricsAggregation.totalStringLiteralCount,
      totalNumberLiteralCount: metricsAggregation.totalNumberLiteralCount,
      duplicatedStringLiteralCount:
          metricsAggregation.duplicatedStringLiteralCount,
      duplicatedNumberLiteralCount:
          metricsAggregation.duplicatedNumberLiteralCount,
      totalStatelessWidgetCount: metricsAggregation.totalStatelessWidgetCount,
      totalStatefulWidgetCount: metricsAggregation.totalStatefulWidgetCount,
      stringLiteralFrequencies: metricsAggregation.stringLiteralFrequencies,
      numberLiteralFrequencies: metricsAggregation.numberLiteralFrequencies,
      fileMetrics: metricsAggregation.fileMetrics,
      codeSizeArtifacts: codeSizeArtifacts,
      codeSizeThresholds: codeSizeThresholds,
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
      dependencyCount: pubspecInfo.dependencyCount,
      devDependencyCount: pubspecInfo.devDependencyCount,
      supportsAndroid: supportedPlatforms.android,
      supportsIos: supportedPlatforms.ios,
      supportsMacos: supportedPlatforms.macos,
      supportsWindows: supportedPlatforms.windows,
      supportsLinux: supportedPlatforms.linux,
      supportsWeb: supportedPlatforms.web,
      usesLocalization: usesLocalization,
      excludedFilesCount: excludedDartFilesCount,
      testDirectoriesCount: testDirectoriesCount,
      testFilesCount: testFilesCount,
      testDartFilesCount: testDartFilesCount,
      testCaseCount: testCaseCount,
      testImportCount: testConsumption.importedPaths.length,
      testConsumedFilesCount: testConsumption.consumedPaths.length,
      testConsumedLinesOfCode: testConsumption.linesOfCode,
      testConsumedClassCount: testConsumption.classCount,
      testConsumedMethodCount: testConsumption.methodCount,
      testConsumedTopLevelFunctionCount: testConsumption.topLevelFunctionCount,
      testImportedPaths: testConsumption.importedPaths,
      testConsumedPaths: testConsumption.consumedPaths,
      customExcludedFilesCount: customExcludedDartFilesCount,
      ignoreDirectivesCount: metricsAggregation.ignoreDirectivesCount,
      ignoreDirectiveFiles: metricsAggregation.ignoreDirectiveCountsByFile.keys
          .toList(),
      ignoreDirectiveCountsByFile:
          metricsAggregation.ignoreDirectiveCountsByFile,
      secretIssues: secretIssues,
      documentationIssues: documentationIssues,
      duplicateCodeIssues: duplicateCodeIssues,
      deadCodeIssues: deadCodeIssues,
      oneClassPerFileAnalyzerEnabled: oneClassPerFileEnabled,
      codeSizeAnalyzerEnabled: codeSizeEnabled,
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

  /// Combines file LOC metrics with AST-derived class/function/method LOC data.
  List<CodeSizeArtifact> _collectCodeSizeArtifacts(
    AnalysisRunnerResult unifiedResult,
    List<FileMetrics> fileMetrics,
  ) {
    final artifacts = <CodeSizeArtifact>[
      for (final metric in fileMetrics)
        if (metric.linesOfCode > 0 &&
            !isGeneratedDartFilePath(metric.path) &&
            !isGeneratedLocalizationDartFilePath(metric.path) &&
            !isLibL10nPath(metric.path))
          CodeSizeArtifact(
            kind: CodeSizeArtifactKind.file,
            name: p.basename(metric.path),
            filePath: metric.path,
            linesOfCode: metric.linesOfCode,
            startLine: 1,
            endLine: metric.linesOfCode,
          ),
    ];

    final codeSizeDataRaw =
        unifiedResult.resultsByType[CodeSizeFileData] ?? <dynamic>[];
    final seenIds = <String>{};
    for (final fileData in codeSizeDataRaw.whereType<CodeSizeFileData>()) {
      for (final artifact in fileData.artifacts) {
        if (artifact.linesOfCode <= 0) {
          continue;
        }
        if (seenIds.add(artifact.stableId)) {
          artifacts.add(artifact);
        }
      }
    }

    return artifacts;
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

    final normalizedRoot = p.normalize(
      Directory(analysisRootPath).absolute.path,
    );
    return issues
        .map(
          (issue) => DocumentationIssue(
            type: issue.type,
            filePath: _toRelativePathForDisplay(
              issue.filePath,
              normalizedRootPath: normalizedRoot,
            ),
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

    final normalizedRoot = p.normalize(
      Directory(analysisRootPath).absolute.path,
    );
    return issues
        .map(
          (issue) => DeadCodeIssue(
            type: issue.type,
            filePath: _toRelativePathForDisplay(
              issue.filePath,
              normalizedRootPath: normalizedRoot,
            ),
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
          .any((file) => file.path.endsWith('.arb'));
      if (hasArb) {
        return true;
      }
    }

    final arbAnywhere = projectDir
        .listSync(recursive: true)
        .whereType<File>()
        .any((file) => file.path.endsWith('.arb'));
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

  /// Counts project test cases by scanning `test` and `integration_test` Dart files.
  int _countTestCases() {
    var totalTestCases = 0;
    for (final file in _listTestDartFiles(projectDir)) {
      try {
        final content = file.readAsStringSync();
        final parseResult = parseString(
          content: content,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
        final counter = TestCaseVisitor();
        parseResult.unit.accept(counter);
        totalTestCases += counter.testCaseCount;
      } catch (_) {
        // Ignore unreadable/unparseable test files and continue.
      }
    }
    return totalTestCases;
  }

  /// Lists Dart files located under canonical test directories.
  List<File> _listTestDartFiles(Directory dir) {
    final files = <File>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || p.extension(entity.path) != '.dart') {
        continue;
      }
      final relativePath = p.relative(entity.path, from: dir.path);
      final pathParts = p.split(relativePath);
      final isHidden = pathParts.any((part) => part.startsWith('.'));
      if (isHidden) {
        continue;
      }
      final isTestFile = pathParts.any(_testDirectoryNames.contains);
      if (isTestFile) {
        files.add(entity);
      }
    }
    return files;
  }

  /// Builds a normalized project-only dependency graph for analyzed Dart files.
  ///
  /// Each key is the normalized absolute path of an analyzed file and each
  /// value contains the normalized project dependencies referenced from that
  /// file through imports, exports, and parts.
  Map<String, List<String>> _buildProjectDependencyGraph(
    List<File> dartFiles, {
    required String rootPath,
    required String packageName,
  }) {
    final dependencyGraph = <String, List<String>>{};
    for (final file in dartFiles) {
      final normalizedPath = p.normalize(file.path);
      dependencyGraph[normalizedPath] = _collectProjectDependenciesFromFile(
        file,
        rootPath: rootPath,
        packageName: packageName,
      );
    }
    return Map<String, List<String>>.unmodifiable(dependencyGraph);
  }

  /// Resolves which analyzed files are statically exercised by test imports.
  ///
  /// The analysis starts from project files imported by test files, then walks
  /// the dependency graph transitively to estimate consumed files, LOC,
  /// classes, methods, and top-level functions.
  TestConsumptionSummary _analyzeTestConsumption({
    required Map<String, List<String>> dependencyGraph,
    required List<FileMetrics> fileMetrics,
    required String rootPath,
    required String packageName,
    required String analysisRootPath,
  }) {
    if (dependencyGraph.isEmpty) {
      return const TestConsumptionSummary.empty();
    }

    final analyzedPaths = dependencyGraph.keys.toSet();
    final importedPathsSet = <String>{};
    for (final testFile in _listTestDartFiles(projectDir)) {
      importedPathsSet.addAll(
        _collectProjectDependenciesFromFile(
          testFile,
          rootPath: rootPath,
          packageName: packageName,
        ).where(analyzedPaths.contains),
      );
    }

    if (importedPathsSet.isEmpty) {
      return const TestConsumptionSummary.empty();
    }

    final queue = Queue<String>()..addAll(importedPathsSet);
    final consumedPathsSet = <String>{};
    while (queue.isNotEmpty) {
      final currentPath = queue.removeFirst();
      if (!consumedPathsSet.add(currentPath)) {
        continue;
      }
      for (final dependency
          in dependencyGraph[currentPath] ?? const <String>[]) {
        if (!analyzedPaths.contains(dependency) ||
            consumedPathsSet.contains(dependency)) {
          continue;
        }
        queue.add(dependency);
      }
    }

    final metricsByPath = <String, FileMetrics>{
      for (final metric in fileMetrics) p.normalize(metric.path): metric,
    };
    var linesOfCode = 0;
    var classCount = 0;
    var methodCount = 0;
    var topLevelFunctionCount = 0;
    for (final path in consumedPathsSet) {
      final metric = metricsByPath[path];
      if (metric == null) {
        continue;
      }
      linesOfCode += metric.linesOfCode;
      classCount += metric.classCount;
      methodCount += metric.methodCount;
      topLevelFunctionCount += metric.topLevelFunctionCount;
    }

    final normalizedAnalysisRoot = p.normalize(
      Directory(analysisRootPath).absolute.path,
    );
    final importedPaths =
        importedPathsSet
            .map(
              (path) => _toRelativePathForDisplay(
                path,
                normalizedRootPath: normalizedAnalysisRoot,
              ),
            )
            .toList(growable: false)
          ..sort();
    final consumedPaths =
        consumedPathsSet
            .map(
              (path) => _toRelativePathForDisplay(
                path,
                normalizedRootPath: normalizedAnalysisRoot,
              ),
            )
            .toList(growable: false)
          ..sort();

    return TestConsumptionSummary(
      importedPaths: importedPaths,
      consumedPaths: consumedPaths,
      linesOfCode: linesOfCode,
      classCount: classCount,
      methodCount: methodCount,
      topLevelFunctionCount: topLevelFunctionCount,
    );
  }

  /// Collects normalized in-project Dart dependencies declared by [file].
  ///
  /// Only project-resolvable imports, exports, and part directives are
  /// returned. Unreadable or unparsable files fall back to an empty list.
  List<String> _collectProjectDependenciesFromFile(
    File file, {
    required String rootPath,
    required String packageName,
  }) {
    try {
      final content = file.readAsStringSync();
      final parseResult = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final dependencies = <String>[];
      for (final directive in parseResult.unit.directives) {
        if (directive is ImportDirective) {
          addDirectiveDartDependencies(
            uri: directive.uri.stringValue,
            configurations: directive.configurations,
            packageName: packageName,
            filePath: p.normalize(file.path),
            rootPath: p.normalize(rootPath),
            dependencies: dependencies,
          );
          continue;
        }
        if (directive is ExportDirective) {
          addDirectiveDartDependencies(
            uri: directive.uri.stringValue,
            configurations: directive.configurations,
            packageName: packageName,
            filePath: p.normalize(file.path),
            rootPath: p.normalize(rootPath),
            dependencies: dependencies,
          );
          continue;
        }
        if (directive is PartDirective) {
          addResolvedProjectDartDependency(
            uri: directive.uri.stringValue,
            packageName: packageName,
            filePath: p.normalize(file.path),
            rootPath: p.normalize(rootPath),
            dependencies: dependencies,
          );
        }
      }
      final uniqueDependencies =
          dependencies.map(p.normalize).toSet().toList(growable: false)..sort();
      return uniqueDependencies;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Detects supported platform folders in the effective project root.
  ///
  /// A platform is considered supported when its canonical directory exists:
  /// `android/`, `ios/`, `macos/`, `windows/`, `web/`, `linux/`.
  ({bool android, bool ios, bool macos, bool windows, bool web, bool linux})
  _detectSupportedPlatforms(Directory root) {
    bool hasFolder(String folderName) =>
        Directory(p.join(root.path, folderName)).existsSync();

    return (
      android: hasFolder(_androidPlatformFolder),
      ios: hasFolder(_iosPlatformFolder),
      macos: hasFolder(_macosPlatformFolder),
      windows: hasFolder(_windowsPlatformFolder),
      linux: hasFolder(_linuxPlatformFolder),
      web: hasFolder(_webPlatformFolder),
    );
  }
}
