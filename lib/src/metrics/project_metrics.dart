import 'package:fcheck/src/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/layers/layers_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/sort/sort.dart';

/// Represents the overall quality metrics for a Flutter/Dart project.
///
/// This class aggregates metrics from all analyzed files in a project,
/// providing insights into code quality, size, and compliance with
/// coding standards.
class ProjectMetrics {
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

  /// Creates a new [ProjectMetrics] instance.
  ///
  /// All parameters are required and represent the aggregated metrics
  /// from analyzing all Dart files in a project.
  ProjectMetrics({
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.fileMetrics,
    required this.hardcodedStringIssues,
    required this.magicNumberIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
    required this.projectName,
    required this.version,
    this.usesLocalization = false,
    this.excludedFilesCount = 0,
  });

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'project': {'name': projectName, 'version': version},
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
  static const int _decimalPlaces = 2;

  /// Prints a comprehensive stats report to the console.
  ///
  /// The report includes:
  /// - Project statistics (folders, files, lines of code)
  /// - Comment ratio analysis
  /// - Compliance status for the "one class per file" rule
  /// - Hardcoded string issues
  /// - Source sorting issues
  /// - Layers architecture stats
  ///
  /// [silent] If true, suppresses console output (useful for testing)
  /// [toolVersion] Optional fCheck CLI version to show in the banner.
  void printReport({bool silent = false, String? toolVersion}) {
    if (silent) return;

    final bannerVersion =
        (toolVersion != null && toolVersion.isNotEmpty) ? ' v$toolVersion' : '';
    print('↓ -------- fCheck$bannerVersion -------- ↓');
    print('Project          : $projectName (version: $version)');
    print('Folders          : $totalFolders');
    print('Files            : $totalFiles');
    print('Dart Files       : $totalDartFiles');
    if (excludedFilesCount > 0) {
      print('Excluded Files   : $excludedFilesCount');
    }
    print('Lines of Code    : $totalLinesOfCode');
    print('Comment Lines    : $totalCommentLines');
    print(
        'Comment Ratio    : ${(commentRatio * _percentageMultiplier).toStringAsFixed(_decimalPlaces)}%');
    print('Hardcoded Strings: ${hardcodedStringIssues.length}');
    print('Magic Numbers    : ${magicNumberIssues.length}');
    print('Layers           : $layersCount');
    print('Dependencies     : $layersEdgeCount');

    final nonCompliant =
        fileMetrics.where((m) => !m.isOneClassPerFileCompliant).toList();
    if (nonCompliant.isEmpty) {
      print('✅ All files comply with the "one class per file" rule.');
    } else {
      print(
          '❌ ${nonCompliant.length} files violate the "one class per file" rule:');
      for (var m in nonCompliant) {
        print('  - ${m.path} (${m.classCount} classes found)');
      }
    }

    print('');

    if (hardcodedStringIssues.isEmpty) {
      print('✅ No hardcoded strings found.');
    } else if (usesLocalization) {
      print(
          '❌ ${hardcodedStringIssues.length} hardcoded strings detected (localization enabled):');
      for (var issue in hardcodedStringIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (hardcodedStringIssues.length > _maxIssuesToShow) {
        print(
            '  ... and ${hardcodedStringIssues.length - _maxIssuesToShow} more');
      }
    } else {
      final firstFile = hardcodedStringIssues.first.filePath.split('/').last;
      print(
          '⚠️ ${hardcodedStringIssues.length} potential hardcoded strings detected (project not localized; showing count only). Example file: $firstFile');
    }

    print('');

    if (magicNumberIssues.isEmpty) {
      print('✅ No magic numbers detected.');
    } else {
      print('⚠️ ${magicNumberIssues.length} magic numbers detected:');
      for (var issue in magicNumberIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (magicNumberIssues.length > _maxIssuesToShow) {
        print('  ... and ${magicNumberIssues.length - _maxIssuesToShow} more');
      }
    }

    print('');

    if (sourceSortIssues.isEmpty) {
      print('✅ All Flutter classes have properly sorted members.');
    } else {
      print(
          '🔧 ${sourceSortIssues.length} Flutter classes have unsorted members:');
      for (var issue in sourceSortIssues.take(_maxIssuesToShow)) {
        print('  - ${issue.filePath}:${issue.lineNumber} (${issue.className})');
      }
      if (sourceSortIssues.length > _maxIssuesToShow) {
        print('  ... and ${sourceSortIssues.length - _maxIssuesToShow} more');
      }
    }

    print('');

    if (layersIssues.isEmpty) {
      print('✅ All layers architecture complies with standards.');
    } else {
      print(
          '🏗️ ${layersIssues.length} layers architecture violations detected:');
      for (var issue in layersIssues.take(_maxIssuesToShow)) {
        print('  - $issue');
      }
      if (layersIssues.length > _maxIssuesToShow) {
        print('  ... and ${layersIssues.length - _maxIssuesToShow} more');
      }
    }
    print('↑ ----------------------- ↑');
  }
}
