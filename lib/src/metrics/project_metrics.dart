// ignore: fcheck_secrets
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/input_output/output.dart';

/// The detected type of the analyzed project.
enum ProjectType {
  /// Flutter application or package (depends on `flutter`).
  flutter,

  /// Pure Dart project (no `flutter` dependency found).
  dart,

  /// Unknown project type (pubspec.yaml missing or unreadable).
  unknown,
}

/// Adds presentation helpers for [ProjectType].
extension ProjectTypeLabel on ProjectType {
  /// Human-readable label for the project type.
  String get label {
    switch (this) {
      case ProjectType.flutter:
        return 'Flutter';
      case ProjectType.dart:
        return 'Dart';
      case ProjectType.unknown:
        return 'Unknown';
    }
  }
}

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
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
    required this.projectName,
    required this.version,
    required this.projectType,
    this.usesLocalization = false,
    this.excludedFilesCount = 0,
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
        'localization': {'usesLocalization': usesLocalization},
      };

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

  /// Maximum number of issues to display in the console report for each category.
  static const int _maxIssuesToShow = 10;

  /// Multiplier for percentage calculations.
  static const int _percentageMultiplier = 100;

  /// Number of decimal places for percentage formatting.
  static const int _commentRatioDecimalPlaces = 0;

  /// Prints a comprehensive stats report to the console.
  ///
  /// The report includes:
  /// - Project statistics (folders, files, lines of code)
  /// - Comment ratio analysis
  /// - Compliance status for the "one class per file" rule
  /// - Hardcoded string issues
  /// - Source sorting issues
  /// - Layers architecture stats
  /// - Secret issues
  ///
  /// It does not return anything.
  void printReport([String? toolVersion]) {
    print('Project          : $projectName (version: $version)');
    print('Project Type     : ${projectType.label}');
    print('Folders          : ${formatCount(totalFolders)}');
    print('Files            : ${formatCount(totalFiles)}');
    print('Dart Files       : ${formatCount(totalDartFiles)}');
    print('Excluded Files   : ${formatCount(excludedFilesCount)}');
    print('Lines of Code    : ${formatCount(totalLinesOfCode)}');
    print('Comment Lines    : ${formatCount(totalCommentLines)}');
    print(
        'Comment Ratio    : ${(commentRatio * _percentageMultiplier).toStringAsFixed(_commentRatioDecimalPlaces)}%');
    final hardcodedCount = formatCount(hardcodedStringIssues.length);
    final hardcodedSummary = usesLocalization
        ? hardcodedCount
        : (hardcodedStringIssues.isEmpty
            ? hardcodedCount
            : '$hardcodedCount (warning)');
    print('Localization     : ${usesLocalization ? 'Yes' : 'No'}');
    print('Hardcoded Strings: $hardcodedSummary');
    print('Magic Numbers    : ${formatCount(magicNumberIssues.length)}');
    print('Secrets          : ${formatCount(secretIssues.length)}');
    print('Layers           : ${formatCount(layersCount)}');
    print('Dependencies     : ${formatCount(layersEdgeCount)}');

    printDivider('Lists', dot: true);

    final nonCompliant =
        fileMetrics.where((m) => !m.isOneClassPerFileCompliant).toList();
    if (nonCompliant.isEmpty) {
      print('${okTag()} One class per file check passed.');
    } else {
      print(
          '${failTag()} ${formatCount(nonCompliant.length)} files violate the "one class per file" rule:');
      for (var m in nonCompliant) {
        print('  - ${m.path} (${formatCount(m.classCount)} classes found)');
      }
      print('');
    }

    if (hardcodedStringIssues.isEmpty) {
      print('${okTag()} Hardcoded strings check passed.');
    } else if (usesLocalization) {
      print(
          '${failTag()} ${formatCount(hardcodedStringIssues.length)} hardcoded strings detected (localization enabled):');
      for (var issue in hardcodedStringIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (hardcodedStringIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${formatCount(hardcodedStringIssues.length - _maxIssuesToShow)} more');
      }
      print('');
    } else {
      final firstFile = hardcodedStringIssues.first.filePath.split('/').last;
      print(
          '${warnTag()} Hardcoded strings check: ${formatCount(hardcodedStringIssues.length)} found (localization off). Example: $firstFile');
    }

    if (magicNumberIssues.isEmpty) {
      print('${okTag()} Magic numbers check passed.');
    } else {
      print(
          '${warnTag()} ${formatCount(magicNumberIssues.length)} magic numbers detected:');
      for (var issue in magicNumberIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      print('');
      if (magicNumberIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${formatCount(magicNumberIssues.length - _maxIssuesToShow)} more');
      }
      print('');
    }

    if (sourceSortIssues.isEmpty) {
      print('${okTag()} Flutter class member sorting passed.');
    } else {
      print(
          '${warnTag()} ${formatCount(sourceSortIssues.length)} Flutter classes have unsorted members:');
      for (var issue in sourceSortIssues.take(_maxIssuesToShow)) {
        print(
            '  - ${issue.filePath}:${formatCount(issue.lineNumber)} (${issue.className})');
      }
      if (sourceSortIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${formatCount(sourceSortIssues.length - _maxIssuesToShow)} more');
      }
      print('');
    }

    if (secretIssues.isEmpty) {
      print('${okTag()} Secrets scan passed.');
    } else {
      print(
          '${warnTag()} ${formatCount(secretIssues.length)} potential secrets detected:');
      for (var issue in secretIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (secretIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${formatCount(secretIssues.length - _maxIssuesToShow)} more');
      }
      print('');
    }

    if (layersIssues.isEmpty) {
      print('${okTag()} Layers architecture check passed.');
    } else {
      print(
          '${failTag()} ${formatCount(layersIssues.length)} layers architecture violations detected:');
      for (var issue in layersIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (layersIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${formatCount(layersIssues.length - _maxIssuesToShow)} more');
      }
    }
  }

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
