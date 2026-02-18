import 'package:fcheck/src/analyzers/metrics/metrics_input.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_analyzer.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/models/project_results.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/project_results_breakdown.dart';
import 'package:fcheck/src/models/project_type.dart';

/// Represents the overall quality metrics for a Flutter/Dart project.
///
/// This class aggregates metrics from all analyzed files in a project,
/// providing insights into code quality, size, and compliance with
/// coding standards.
class ProjectMetrics {
  static const MetricsAnalyzer _metricsAnalyzer = MetricsAnalyzer();

  /// The detected type of the analyzed project.
  final ProjectType projectType;

  /// Total number of folders in the project.
  final int totalFolders;

  /// Total number of files in the project.
  final int totalFiles;

  /// Total number of Dart files in the project.
  final int totalDartFiles;

  /// Total lines of code across all Dart files.
  final int totalLinesOfCode;

  /// Total comment lines across all Dart files.
  final int totalCommentLines;

  /// Metrics for each individual Dart file.
  final List<FileMetrics> fileMetrics;

  /// List of secret issues found in the project.
  final List<SecretIssue> secretIssues;

  /// List of hardcoded string issues found in the project.
  final List<HardcodedStringIssue> hardcodedStringIssues;

  /// List of detected magic number literals across the project.
  final List<MagicNumberIssue> magicNumberIssues;

  /// List of source sorting issues found in the project.
  final List<SourceSortIssue> sourceSortIssues;

  /// List of layers architecture issues found in the project.
  final List<LayersIssue> layersIssues;

  /// List of dead code issues found in the project.
  final List<DeadCodeIssue> deadCodeIssues;

  /// List of duplicate code issues found in the project.
  final List<DuplicateCodeIssue> duplicateCodeIssues;

  /// List of documentation issues found in the project.
  final List<DocumentationIssue> documentationIssues;

  /// Total number of dependency edges in the layers graph.
  final int layersEdgeCount;

  /// Number of layers in the project.
  final int layersCount;

  /// The dependency graph used for analysis (filePath -> list of dependencies).
  final Map<String, List<String>> dependencyGraph;

  /// Per-file layer assignments computed during layers analysis.
  ///
  /// This is used by CLI graph exporters to avoid re-running layers analysis.
  final Map<String, int> layersByFile;

  /// Total number of functions and methods in the project.
  final int totalFunctionCount;

  /// Total number of string literals in the project.
  final int totalStringLiteralCount;

  /// Total number of numeric literals in the project.
  final int totalNumberLiteralCount;

  /// Number of files successfully skipped based on exclusion glob patterns.
  final int excludedFilesCount;

  /// Number of Dart files excluded by user-provided glob patterns.
  final int customExcludedFilesCount;

  /// Count of `// ignore: fcheck_*` directives found in analyzed Dart files.
  final int ignoreDirectivesCount;

  /// Unique file paths containing at least one `// ignore: fcheck_*` directive.
  final List<String> ignoreDirectiveFiles;

  /// Per-file count of `// ignore: fcheck_*` directives.
  final Map<String, int> ignoreDirectiveCountsByFile;

  /// Whether the project appears to be using Flutter localization (l10n).
  ///
  /// Detection is based on the presence of `l10n.yaml`, `.arb` files,
  /// or imports of generated localization files.
  final bool usesLocalization;

  /// The version of the analyzed project as defined in its pubspec.yaml.
  final String version;

  /// The name of the analyzed project as defined in its pubspec.yaml.
  final String projectName;

  /// Number of entries in `dependencies` from pubspec.yaml.
  final int dependencyCount;

  /// Number of entries in `dev_dependencies` from pubspec.yaml.
  final int devDependencyCount;

  /// Whether the one-class-per-file analyzer was enabled for this run.
  final bool oneClassPerFileAnalyzerEnabled;

  /// Whether the hardcoded-strings analyzer was enabled for this run.
  final bool hardcodedStringsAnalyzerEnabled;

  /// Whether the magic-numbers analyzer was enabled for this run.
  final bool magicNumbersAnalyzerEnabled;

  /// Whether the source-sorting analyzer was enabled for this run.
  final bool sourceSortingAnalyzerEnabled;

  /// Whether the layers analyzer was enabled for this run.
  final bool layersAnalyzerEnabled;

  /// Whether the secrets analyzer was enabled for this run.
  final bool secretsAnalyzerEnabled;

  /// Whether the dead-code analyzer was enabled for this run.
  final bool deadCodeAnalyzerEnabled;

  /// Whether the duplicate-code analyzer was enabled for this run.
  final bool duplicateCodeAnalyzerEnabled;

  /// Whether the documentation analyzer was enabled for this run.
  final bool documentationAnalyzerEnabled;

  /// Creates a new ProjectMetrics instance.
  ///
  /// [totalFolders] Total number of folders in the project.
  /// [totalFiles] Total number of files in the project.
  /// [totalDartFiles] Total number of Dart files in the project.
  /// [totalLinesOfCode] Total lines of code across all Dart files.
  /// [totalCommentLines] Total comment lines across all Dart files.
  /// [totalFunctionCount] Total number of functions and methods in the project.
  /// [totalStringLiteralCount] Total number of string literals in the project.
  /// [totalNumberLiteralCount] Total number of numeric literals in the project.
  /// [fileMetrics] Metrics for each individual Dart file.
  /// [secretIssues] List of secret issues found in the project.
  /// [hardcodedStringIssues] List of hardcoded string issues found in the project.
  /// [magicNumberIssues] List of detected magic number literals across the project.
  /// [sourceSortIssues] List of source sorting issues found in the project.
  /// [layersIssues] List of layers architecture issues found in the project.
  /// [deadCodeIssues] List of dead code issues found in the project.
  /// [duplicateCodeIssues] List of duplicate code issues found in the project.
  /// [layersEdgeCount] Total number of dependency edges in the layers graph.
  /// [layersCount] Number of layers in the project.
  /// [dependencyGraph] The dependency graph used for analysis.
  /// [projectName] The name of the analyzed project.
  /// [version] The version of the analyzed project.
  /// [projectType] The detected project type (Flutter, Dart, or Unknown).
  /// [usesLocalization] Whether the project appears to be using Flutter localization.
  /// [excludedFilesCount] Number of files successfully skipped based on exclusion glob patterns.
  /// [customExcludedFilesCount] Number of Dart files excluded by custom glob patterns.
  /// [ignoreDirectivesCount] Number of `// ignore: fcheck_*` directives found.
  /// [ignoreDirectiveFiles] Unique file paths containing `// ignore: fcheck_*`.
  /// [ignoreDirectiveCountsByFile] Per-file counts for `// ignore: fcheck_*`.
  ProjectMetrics({
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    this.totalFunctionCount = 0,
    this.totalStringLiteralCount = 0,
    this.totalNumberLiteralCount = 0,
    required this.fileMetrics,
    required this.secretIssues,
    required this.hardcodedStringIssues,
    required this.magicNumberIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.deadCodeIssues,
    this.duplicateCodeIssues = const [],
    this.documentationIssues = const [],
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
    this.layersByFile = const {},
    required this.projectName,
    required this.version,
    required this.projectType,
    this.dependencyCount = 0,
    this.devDependencyCount = 0,
    this.usesLocalization = false,
    this.excludedFilesCount = 0,
    this.customExcludedFilesCount = 0,
    this.ignoreDirectivesCount = 0,
    this.ignoreDirectiveFiles = const [],
    this.ignoreDirectiveCountsByFile = const {},
    this.oneClassPerFileAnalyzerEnabled = true,
    this.hardcodedStringsAnalyzerEnabled = true,
    this.magicNumbersAnalyzerEnabled = true,
    this.sourceSortingAnalyzerEnabled = true,
    this.layersAnalyzerEnabled = true,
    this.secretsAnalyzerEnabled = true,
    this.deadCodeAnalyzerEnabled = true,
    this.duplicateCodeAnalyzerEnabled = true,
    this.documentationAnalyzerEnabled = true,
  });

  late final ProjectMetricsAnalysisResult _analysisResult =
      _metricsAnalyzer.analyze(
    ProjectMetricsAnalysisInput(
      totalDartFiles: totalDartFiles,
      totalLinesOfCode: totalLinesOfCode,
      fileMetrics: fileMetrics,
      hardcodedStringIssues: hardcodedStringIssues,
      magicNumberIssues: magicNumberIssues,
      sourceSortIssues: sourceSortIssues,
      layersIssues: layersIssues,
      secretIssues: secretIssues,
      deadCodeIssues: deadCodeIssues,
      duplicateCodeIssues: duplicateCodeIssues,
      documentationIssues: documentationIssues,
      layersEdgeCount: layersEdgeCount,
      usesLocalization: usesLocalization,
      ignoreDirectivesCount: ignoreDirectivesCount,
      customExcludedFilesCount: customExcludedFilesCount,
      disabledAnalyzersCount: disabledAnalyzersCount,
      oneClassPerFileAnalyzerEnabled: oneClassPerFileAnalyzerEnabled,
      hardcodedStringsAnalyzerEnabled: hardcodedStringsAnalyzerEnabled,
      magicNumbersAnalyzerEnabled: magicNumbersAnalyzerEnabled,
      sourceSortingAnalyzerEnabled: sourceSortingAnalyzerEnabled,
      layersAnalyzerEnabled: layersAnalyzerEnabled,
      secretsAnalyzerEnabled: secretsAnalyzerEnabled,
      deadCodeAnalyzerEnabled: deadCodeAnalyzerEnabled,
      duplicateCodeAnalyzerEnabled: duplicateCodeAnalyzerEnabled,
      documentationAnalyzerEnabled: documentationAnalyzerEnabled,
    ),
  );

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'project': {
          'name': projectName,
          'version': version,
          'type': projectType.label,
        },
        'stats': {
          'folders': totalFolders,
          'files': totalFiles,
          'dartFiles': totalDartFiles,
          'excludedFiles': excludedFilesCount,
          'customExcludedFiles': customExcludedFilesCount,
          'ignoreDirectives': ignoreDirectivesCount,
          'disabledAnalyzers': disabledAnalyzersCount,
          'suppressionPenalty': suppressionPenaltyPoints,
          'linesOfCode': totalLinesOfCode,
          'commentLines': totalCommentLines,
          'commentRatio': commentRatio,
          'functions': totalFunctionCount,
          'stringLiterals': totalStringLiteralCount,
          'numberLiterals': totalNumberLiteralCount,
          'hardcodedStrings': hardcodedStringIssues.length,
          'magicNumbers': magicNumberIssues.length,
          'secretIssues': secretIssues.length,
          'deadCodeIssues': deadCodeIssues.length,
          'duplicateCodeIssues': duplicateCodeIssues.length,
          'documentationIssues': documentationIssues.length,
          'complianceScore': complianceScore,
        },
        'layers': {
          'count': layersCount,
          'dependencies': layersEdgeCount,
          'violations': layersIssues.map((i) => i.toJson()).toList(),
          'graph': dependencyGraph,
        },
        'files': fileMetrics.map((m) => m.toJson()).toList(),
        'hardcodedStrings':
            hardcodedStringIssues.map((i) => i.toJson()).toList(),
        'magicNumbers': magicNumberIssues.map((i) => i.toJson()).toList(),
        'sourceSorting': sourceSortIssues.map((i) => i.toJson()).toList(),
        'secretIssues': secretIssues.map((i) => i.toJson()).toList(),
        'deadCodeIssues': deadCodeIssues.map((i) => i.toJson()).toList(),
        'duplicateCodeIssues':
            duplicateCodeIssues.map((i) => i.toJson()).toList(),
        'documentationIssues':
            documentationIssues.map((i) => i.toJson()).toList(),
        'localization': {'usesLocalization': usesLocalization},
        'compliance': {
          'score': complianceScore,
          'suppressionPenalty': suppressionPenaltyPoints,
          'focusArea': complianceFocusAreaKey,
          'focusAreaLabel': complianceFocusAreaLabel,
          'focusAreaIssues': complianceFocusAreaIssueCount,
          'nextInvestment': complianceNextInvestment,
        },
      };

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

  /// Number of analyzers disabled for this run.
  int get disabledAnalyzersCount => [
        oneClassPerFileAnalyzerEnabled,
        hardcodedStringsAnalyzerEnabled,
        magicNumbersAnalyzerEnabled,
        sourceSortingAnalyzerEnabled,
        layersAnalyzerEnabled,
        secretsAnalyzerEnabled,
        deadCodeAnalyzerEnabled,
        duplicateCodeAnalyzerEnabled,
        documentationAnalyzerEnabled,
      ].where((enabled) => !enabled).length;

  /// Equal-share quality score across enabled analyzers from 0 to 100.
  ///
  /// Higher is better. A score of 100 means no detected compliance penalties
  /// across all enabled analyzers.
  ///
  /// Formula:
  /// - `domainAverage = sum(enabledDomainScores) / enabledDomainCount`
  /// - `baseScore = clamp(domainAverage * 100, 0, 100)`
  /// - `score = round(clamp(baseScore - suppressionPenaltyPoints, 0, 100))`
  ///
  /// Special rule:
  /// - If rounding yields `100` while any enabled domain is `< 1.0`,
  ///   result is forced to `99` so perfect score remains strict.
  int get complianceScore => _analysisResult.complianceScore;

  /// Budget-adjusted score penalty from suppressions (`ignore`, excludes, disabled analyzers).
  ///
  /// The penalty is capped to keep suppressions impactful but not dominant.
  int get suppressionPenaltyPoints => _analysisResult.suppressionPenaltyPoints;

  /// Machine-readable key for the area with highest score impact.
  ///
  /// Returns `none` when all enabled analyzers are fully compliant.
  ///
  /// Highest impact is selected by `penaltyImpact = (1 - score)`.
  /// Tie-breaker is higher issue count.
  String get complianceFocusAreaKey => _analysisResult.complianceFocusAreaKey;

  /// Human-readable label for [complianceFocusAreaKey].
  ///
  /// Returns `None` when all enabled analyzers are fully compliant.
  String get complianceFocusAreaLabel =>
      _analysisResult.complianceFocusAreaLabel;

  /// Number of detected issues for [complianceFocusAreaKey].
  ///
  /// Returns `0` when focus area is `none`.
  int get complianceFocusAreaIssueCount =>
      _analysisResult.complianceFocusAreaIssueCount;

  /// Suggested investment area to improve score in the next iteration.
  ///
  /// Message text is deterministic and mapped by focus-area key.
  String get complianceNextInvestment =>
      _analysisResult.complianceNextInvestment;

  /// Per-analyzer scoring breakdown from the project metrics analyzer.
  List<AnalyzerScoreBreakdown> get analyzerScores =>
      _analysisResult.analyzerScores;

  /// Dead code issues classified as dead files.
  List<DeadCodeIssue> get deadFileIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadFile)
      .toList();

  /// Dead code issues classified as dead classes.
  List<DeadCodeIssue> get deadClassIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadClass)
      .toList();

  /// Dead code issues classified as dead functions.
  List<DeadCodeIssue> get deadFunctionIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadFunction)
      .toList();

  /// Dead code issues classified as unused variables.
  List<DeadCodeIssue> get unusedVariableIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.unusedVariable)
      .toList();
}
