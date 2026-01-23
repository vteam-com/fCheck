import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/layers/layers_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';

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
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
  });

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'stats': {
          'folders': totalFolders,
          'files': totalFiles,
          'dartFiles': totalDartFiles,
          'linesOfCode': totalLinesOfCode,
          'commentLines': totalCommentLines,
          'commentRatio': commentRatio,
        },
        'layers': {
          'edgeCount': layersEdgeCount,
          'layerCount': layersCount,
          'issues': layersIssues.map((i) => i.toJson()).toList(),
          'graph': dependencyGraph,
        },
        'files': fileMetrics.map((m) => m.toJson()).toList(),
        'hardcodedStrings':
            hardcodedStringIssues.map((i) => i.toJson()).toList(),
        'sourceSorting': sourceSortIssues.map((i) => i.toJson()).toList(),
      };

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

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
  void printReport({bool silent = false}) {
    if (silent) return;

    print('--- Stats ---');
    print('Folders: $totalFolders');
    print('Files: $totalFiles');
    print('Dart Files: $totalDartFiles');
    print('Lines of Code: $totalLinesOfCode');
    print('Comment Lines: $totalCommentLines');
    print('Comment Ratio: ${(commentRatio * 100).toStringAsFixed(2)}%');
    print('Layers Edge Count: $layersEdgeCount');
    print('Layers Count: $layersCount');
    print('----------------------');

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
    } else {
      print(
          '⚠️ ${hardcodedStringIssues.length} potential hardcoded strings detected:');
      for (var issue in hardcodedStringIssues.take(10)) {
        print('  - $issue');
      }
      if (hardcodedStringIssues.length > 10) {
        print('  ... and ${hardcodedStringIssues.length - 10} more');
      }
    }

    print('');

    if (sourceSortIssues.isEmpty) {
      print('✅ All Flutter classes have properly sorted members.');
    } else {
      print(
          '🔧 ${sourceSortIssues.length} Flutter classes have unsorted members:');
      for (var issue in sourceSortIssues.take(10)) {
        print('  - ${issue.filePath}:${issue.lineNumber} (${issue.className})');
      }
      if (sourceSortIssues.length > 10) {
        print('  ... and ${sourceSortIssues.length - 10} more');
      }
    }

    print('');

    if (layersIssues.isEmpty) {
      print('✅ No layers architecture violations found.');
    } else {
      print(
          '🏗️ ${layersIssues.length} layers architecture violations detected:');
      for (var issue in layersIssues.take(10)) {
        print('  - $issue');
      }
      if (layersIssues.length > 10) {
        print('  ... and ${layersIssues.length - 10} more');
      }
    }
  }
}
