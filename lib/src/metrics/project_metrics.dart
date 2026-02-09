// ignore: fcheck_secrets
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';

/// Represents the overall quality metrics for a Flutter/Dart project.
///
/// This class aggregates metrics from all analyzed files in a project,
/// providing insights into code quality, size, and compliance with
/// coding standards.
class ProjectMetrics {
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

  /// Total number of dependency edges in the layers graph.
  final int layersEdgeCount;

  /// Number of layers in the project.
  final int layersCount;

  /// The dependency graph used for analysis (filePath -> list of dependencies).
  final Map<String, List<String>> dependencyGraph;

  /// Number of files successfully skipped based on exclusion glob patterns.
  final int excludedFilesCount;

  /// Whether the project appears to be using Flutter localization (l10n).
  ///
  /// Detection is based on the presence of `l10n.yaml`, `.arb` files,
  /// or imports of generated localization files.
  final bool usesLocalization;

  /// The version of the analyzed project as defined in its pubspec.yaml.
  final String version;

  /// The name of the analyzed project as defined in its pubspec.yaml.
  final String projectName;

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

  /// Creates a new ProjectMetrics instance.
  ///
  /// [totalFolders] Total number of folders in the project.
  /// [totalFiles] Total number of files in the project.
  /// [totalDartFiles] Total number of Dart files in the project.
  /// [totalLinesOfCode] Total lines of code across all Dart files.
  /// [totalCommentLines] Total comment lines across all Dart files.
  /// [fileMetrics] Metrics for each individual Dart file.
  /// [secretIssues] List of secret issues found in the project.
  /// [hardcodedStringIssues] List of hardcoded string issues found in the project.
  /// [magicNumberIssues] List of detected magic number literals across the project.
  /// [sourceSortIssues] List of source sorting issues found in the project.
  /// [layersIssues] List of layers architecture issues found in the project.
  /// [deadCodeIssues] List of dead code issues found in the project.
  /// [layersEdgeCount] Total number of dependency edges in the layers graph.
  /// [layersCount] Number of layers in the project.
  /// [dependencyGraph] The dependency graph used for analysis.
  /// [projectName] The name of the analyzed project.
  /// [version] The version of the analyzed project.
  /// [projectType] The detected project type (Flutter, Dart, or Unknown).
  /// [usesLocalization] Whether the project appears to be using Flutter localization.
  /// [excludedFilesCount] Number of files successfully skipped based on exclusion glob patterns.
  ProjectMetrics({
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.fileMetrics,
    required this.secretIssues,
    required this.hardcodedStringIssues,
    required this.magicNumberIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.deadCodeIssues,
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
    required this.projectName,
    required this.version,
    required this.projectType,
    this.usesLocalization = false,
    this.excludedFilesCount = 0,
    this.oneClassPerFileAnalyzerEnabled = true,
    this.hardcodedStringsAnalyzerEnabled = true,
    this.magicNumbersAnalyzerEnabled = true,
    this.sourceSortingAnalyzerEnabled = true,
    this.layersAnalyzerEnabled = true,
    this.secretsAnalyzerEnabled = true,
    this.deadCodeAnalyzerEnabled = true,
  });

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
          'linesOfCode': totalLinesOfCode,
          'commentLines': totalCommentLines,
          'commentRatio': commentRatio,
          'hardcodedStrings': hardcodedStringIssues.length,
          'magicNumbers': magicNumberIssues.length,
          'secretIssues': secretIssues.length,
          'deadCodeIssues': deadCodeIssues.length,
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
        'localization': {'usesLocalization': usesLocalization},
      };

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

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

  /// Converts all secret issues to a JSON-compatible map.
  List<Map<String, dynamic>> get secretIssuesJson => secretIssues
      .map((issue) => {
            'filePath': issue.filePath,
            'lineNumber': issue.lineNumber,
            'secretType': issue.secretType,
            'value': issue.value,
          })
      .toList();
}
