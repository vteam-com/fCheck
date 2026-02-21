import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/models/code_size_thresholds.dart';
import 'package:fcheck/src/models/file_metrics.dart';

/// Input contract for project-level metrics scoring.
class ProjectMetricsAnalysisInput {
  /// Creates analyzer input for project-level compliance scoring.
  const ProjectMetricsAnalysisInput({
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.fileMetrics,
    required this.codeSizeArtifacts,
    required this.codeSizeThresholds,
    required this.hardcodedStringIssues,
    required this.magicNumberIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.secretIssues,
    required this.deadCodeIssues,
    required this.duplicateCodeIssues,
    required this.documentationIssues,
    required this.layersEdgeCount,
    required this.usesLocalization,
    required this.ignoreDirectivesCount,
    required this.customExcludedFilesCount,
    required this.disabledAnalyzersCount,
    required this.codeSizeAnalyzerEnabled,
    required this.oneClassPerFileAnalyzerEnabled,
    required this.hardcodedStringsAnalyzerEnabled,
    required this.magicNumbersAnalyzerEnabled,
    required this.sourceSortingAnalyzerEnabled,
    required this.layersAnalyzerEnabled,
    required this.secretsAnalyzerEnabled,
    required this.deadCodeAnalyzerEnabled,
    required this.duplicateCodeAnalyzerEnabled,
    required this.documentationAnalyzerEnabled,
  });

  /// Total number of analyzed Dart files.
  final int totalDartFiles;

  /// Total lines of code across analyzed Dart files.
  final int totalLinesOfCode;

  /// Per-file project metrics.
  final List<FileMetrics> fileMetrics;

  /// Code size artifacts across files, classes, and callables.
  final List<CodeSizeArtifact> codeSizeArtifacts;

  /// LOC thresholds for code-size analyzer.
  final CodeSizeThresholds codeSizeThresholds;

  /// Hardcoded string issues.
  final List<HardcodedStringIssue> hardcodedStringIssues;

  /// Magic number issues.
  final List<MagicNumberIssue> magicNumberIssues;

  /// Source sorting issues.
  final List<SourceSortIssue> sourceSortIssues;

  /// Layers issues.
  final List<LayersIssue> layersIssues;

  /// Secret issues.
  final List<SecretIssue> secretIssues;

  /// Dead code issues.
  final List<DeadCodeIssue> deadCodeIssues;

  /// Duplicate code issues.
  final List<DuplicateCodeIssue> duplicateCodeIssues;

  /// Documentation issues.
  final List<DocumentationIssue> documentationIssues;

  /// Total dependency edges discovered by layers analysis.
  final int layersEdgeCount;

  /// Whether localization support is detected in project.
  final bool usesLocalization;

  /// Number of `// ignore: fcheck_*` directives in analyzed files.
  final int ignoreDirectivesCount;

  /// Number of custom-excluded Dart files.
  final int customExcludedFilesCount;

  /// Number of disabled analyzers.
  final int disabledAnalyzersCount;

  /// Whether code-size analyzer is enabled.
  final bool codeSizeAnalyzerEnabled;

  /// Whether one-class-per-file analyzer is enabled.
  final bool oneClassPerFileAnalyzerEnabled;

  /// Whether hardcoded-strings analyzer is enabled.
  final bool hardcodedStringsAnalyzerEnabled;

  /// Whether magic-numbers analyzer is enabled.
  final bool magicNumbersAnalyzerEnabled;

  /// Whether source-sorting analyzer is enabled.
  final bool sourceSortingAnalyzerEnabled;

  /// Whether layers analyzer is enabled.
  final bool layersAnalyzerEnabled;

  /// Whether secrets analyzer is enabled.
  final bool secretsAnalyzerEnabled;

  /// Whether dead-code analyzer is enabled.
  final bool deadCodeAnalyzerEnabled;

  /// Whether duplicate-code analyzer is enabled.
  final bool duplicateCodeAnalyzerEnabled;

  /// Whether documentation analyzer is enabled.
  final bool documentationAnalyzerEnabled;
}
