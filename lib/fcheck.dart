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
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/localization/localization_delegate.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue.dart';
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
import 'package:fcheck/src/exports/svg/export_folders/export_svg_folders.dart';
import 'package:fcheck/src/exports/svg/export_packages/export_package_platform_warning_collector.dart';
import 'package:fcheck/src/exports/svg/export_packages/export_svg_package_dependencies.dart';
import 'package:fcheck/src/fcheck_pubspec_info.dart';
import 'package:fcheck/src/fcheck_test_analysis.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/input_output/path_style_utils.dart';
import 'package:fcheck/src/models/code_size_thresholds.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:path/path.dart' as p;

export 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
export 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
export 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
export 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
export 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
export 'package:fcheck/src/analyzers/layers/layers_issue.dart';
export 'package:fcheck/src/analyzers/localization/localization_issue.dart';
export 'package:fcheck/src/analyzers/localization/localization_issue_detail.dart';
export 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
export 'package:fcheck/src/analyzers/project_metrics.dart';
export 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
export 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
export 'package:fcheck/src/models/code_size_thresholds.dart';
export 'package:fcheck/src/models/fcheck_config.dart';
export 'package:fcheck/src/models/file_metrics.dart';
export 'package:fcheck/src/models/package_platform_warning.dart';
export 'package:fcheck/src/models/project_results_breakdown.dart';
export 'package:fcheck/src/models/project_type.dart';

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

  /// Creates an engine configured like the `fcheck` CLI from a loaded
  /// `.fcheck` [config]: its analysis root, exclude patterns (plus
  /// [extraExcludePatterns]), enabled analyzers and thresholds.
  ///
  /// [duplicateCodeSimilarityThreshold] and
  /// [duplicateCodeMinNonEmptyLineCount] override the configured values,
  /// e.g. to surface near-duplicates for a review.
  ///
  /// Tools embedding fcheck use this so their results match the CLI's:
  /// ```dart
  /// final config = FcheckConfig.loadForInputDirectory(Directory('my_app'));
  /// final metrics = AnalyzeFolder.fromConfig(config).analyze();
  /// ```
  factory AnalyzeFolder.fromConfig(
    FcheckConfig config, {
    bool fix = false,
    List<String> extraExcludePatterns = const [],
    double? duplicateCodeSimilarityThreshold,
    int? duplicateCodeMinNonEmptyLineCount,
  }) {
    return AnalyzeFolder(
      config.analysisDirectory,
      fix: fix,
      excludePatterns: config.mergeExcludePatterns(extraExcludePatterns),
      enabledAnalyzers: config.effectiveEnabledAnalyzers,
      duplicateCodeSimilarityThreshold:
          duplicateCodeSimilarityThreshold ??
          config.duplicateCodeSimilarityThreshold,
      duplicateCodeMinTokenCount: config.duplicateCodeMinTokens,
      duplicateCodeMinNonEmptyLineCount:
          duplicateCodeMinNonEmptyLineCount ??
          config.duplicateCodeMinNonEmptyLines,
      codeSizeThresholds: config.codeSizeThresholds,
    );
  }

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
      customExcludedDartFilesCount,
    ) = FileUtils.scanDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );
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
    final localizationEnabled = _isAnalyzerEnabled(AnalyzerDomain.localization);
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
      if (localizationEnabled) LocalizationDelegate(fix: fix),
    ];

    final unifiedAnalyzer = AnalyzerRunner(
      projectDir: projectDir,
      excludePatterns: excludePatterns,
      delegates: delegates,
      dartFiles: dartFiles,
    );

    final unifiedResult = unifiedAnalyzer.analyzeAll();
    final analyzedContexts = unifiedResult.contextsByPath.values.toList(
      growable: false,
    );
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
            DocumentationAnalyzer(projectRoot: projectRoot)
                .analyze(documentationIssuesRaw),
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
    final reportedLayersIssues = layersEnabled
        ? buildReportedLayersIssuesFromFolderGraph(layersResult)
        : <LayersIssue>[];

    final metricsAggregation = MetricsAnalyzer().aggregate(
      unifiedResult.resultsByType[MetricsFileData]
              ?.cast<MetricsFileData>()
              .toList() ??
          [],
    );
    final projectDependencyGraph = buildProjectDependencyGraph(
      analyzedContexts,
      rootPath: projectRoot.path,
      packageName: pubspecInfo.packageName,
    );
    final testAnalysisSummary = analyzeTestFiles(
      projectDir: projectDir,
      rootPath: projectRoot.path,
      packageName: pubspecInfo.packageName,
      analyzedPaths: projectDependencyGraph.keys.toSet(),
    );
    final testConsumption = analyzeTestConsumption(
      dependencyGraph: projectDependencyGraph,
      fileMetrics: metricsAggregation.fileMetrics,
      analysisRootPath: projectDir.path,
      importedPathsSet: testAnalysisSummary.importedPaths,
    );
    final codeSizeArtifacts = codeSizeEnabled
        ? _collectCodeSizeArtifacts(
            unifiedResult,
            metricsAggregation.fileMetrics,
          )
        : <CodeSizeArtifact>[];

    // Perform project-wide localization analysis
    final localizationIssues = localizationEnabled
        ? LocalizationDelegate(fix: fix)
              .analyzeProject(projectDir, analyzedContexts: analyzedContexts)
        : <LocalizationIssue>[];

    final packagePlatformWarnings = collectPackagePlatformWarnings(
      loadPackageDependencyGraphData(projectDir),
    );

    return ProjectMetrics(
      totalFolders: totalFolders,
      totalFiles: totalFiles,
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: metricsAggregation.totalLinesOfCode,
      totalCommentLines: metricsAggregation.totalCommentLines,
      analysisRootPath: projectDir.path,
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
      layersIssues: reportedLayersIssues,
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
      testCaseCount: testAnalysisSummary.testCaseCount,
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
      localizationIssues: localizationIssues,
      duplicateCodeIssues: duplicateCodeIssues,
      deadCodeIssues: deadCodeIssues,
      packagePlatformWarnings: packagePlatformWarnings,
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
      localizationAnalyzerEnabled: localizationEnabled,
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
            filePath: toRelativePathForDisplay(
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
            filePath: toRelativePathForDisplay(
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

  /// Heuristically detects whether the project uses Flutter localization.
  ///
  /// Signals localization when:
  /// - `l10n.yaml` exists (and optionally specifies arb-dir), or
  /// - `.arb` files are present (in configured or default locations), or
  /// - Source files reference `AppLocalizations` / `flutter_gen/gen_l10n`.
  bool detectLocalization(List<File> dartFiles) {
    final l10nConfigPath = p.join(projectDir.path, 'l10n.yaml');
    final l10nConfig = File(l10nConfigPath);
    if (l10nConfig.existsSync()) {
      // Parse l10n.yaml to get the configured arb-dir
      final arbDir = _extractArbDirFromL10nConfig(l10nConfigPath);
      if (arbDir != null) {
        final customL10nDir = Directory(p.join(projectDir.path, arbDir));
        if (customL10nDir.existsSync()) {
          final hasArb = customL10nDir
              .listSync(recursive: true)
              .whereType<File>()
              .any((file) => file.path.endsWith('.arb'));
          if (hasArb) {
            return true;
          }
        }
      }
      // l10n.yaml exists but no arb-dir specified or dir not found
      // still consider it localized if the file exists
      return true;
    }

    // Fallback: check default location
    final defaultL10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    if (defaultL10nDir.existsSync()) {
      final hasArb = defaultL10nDir
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

  /// Extracts the arb-dir value from l10n.yaml configuration file.
  String? _extractArbDirFromL10nConfig(String configPath) {
    try {
      final content = File(configPath).readAsStringSync();
      final arbDirMatch = RegExp(
        r'^arb-dir:\s*(.+)$',
        multiLine: true,
      ).firstMatch(content);
      if (arbDirMatch != null) {
        return arbDirMatch.group(1)?.trim();
      }
    } catch (_) {
      // Failed to read or parse config file
    }
    return null;
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
