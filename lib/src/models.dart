/// Represents the overall quality metrics for a Flutter/Dart project.
///
/// This class aggregates metrics from all analyzed files in a project,
/// providing insights into code quality, size, and compliance with
/// coding standards.
import 'hardcoded_strings.dart';

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
  });

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

  /// Prints a comprehensive quality report to the console.
  ///
  /// The report includes:
  /// - Project statistics (folders, files, lines of code)
  /// - Comment ratio analysis
  /// - Compliance status for the "one class per file" rule
  /// - Hardcoded string issues
  void printReport() {
    print('--- Quality Report ---');
    print('Total Folders: $totalFolders');
    print('Total Files: $totalFiles');
    print('Total Dart Files: $totalDartFiles');
    print('Total Lines of Code: $totalLinesOfCode');
    print('Total Comment Lines: $totalCommentLines');
    print('Comment Ratio: ${(commentRatio * 100).toStringAsFixed(2)}%');
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
  }
}

/// Represents quality metrics for a single Dart file.
///
/// This class contains analysis results for an individual file including
/// size metrics, comment counts, and compliance with coding standards.
class FileMetrics {
  /// The file system path to this file.
  final String path;

  /// Total number of lines in the file.
  final int linesOfCode;

  /// Number of lines that contain comments.
  final int commentLines;

  /// Number of class declarations in the file.
  final int classCount;

  /// Whether this file contains a StatefulWidget class.
  ///
  /// StatefulWidget classes are allowed to have 2 classes (widget + state)
  /// while still being compliant with the "one class per file" rule.
  final bool isStatefulWidget;

  /// Creates a new [FileMetrics] instance.
  ///
  /// All parameters are required and represent the analysis results
  /// for a single Dart file.
  FileMetrics({
    required this.path,
    required this.linesOfCode,
    required this.commentLines,
    required this.classCount,
    required this.isStatefulWidget,
  });

  /// Whether this file complies with the "one class per file" rule.
  ///
  /// - Regular classes: Maximum 1 class per file
  /// - StatefulWidget files: Maximum 2 classes per file (widget + state)
  /// - Returns `true` if compliant, `false` if violates the rule
  bool get isOneClassPerFileCompliant {
    if (isStatefulWidget) {
      // StatefulWidget usually has 2 classes: the widget and the state.
      return classCount <= 2;
    }
    return classCount <= 1;
  }
}
