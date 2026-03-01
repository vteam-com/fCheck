import 'package:fcheck/src/models/file_metrics.dart';

/// Aggregated metrics component from a project analysis pass.
class MetricsAggregationResult {
  /// Metrics for each individual Dart file.
  final List<FileMetrics> fileMetrics;

  /// Total lines of code across all Dart files.
  final int totalLinesOfCode;

  /// Total comment lines across all Dart files.
  final int totalCommentLines;

  /// Total number of functions and methods found.
  final int totalFunctionCount;

  /// Total number of string literals found.
  final int totalStringLiteralCount;

  /// Total number of numeric literals found.
  final int totalNumberLiteralCount;

  /// Number of string literal occurrences that belong to duplicated values.
  final int duplicatedStringLiteralCount;

  /// Number of numeric literal occurrences that belong to duplicated values.
  final int duplicatedNumberLiteralCount;

  /// Frequency map of string literal values across the project.
  final Map<String, int> stringLiteralFrequencies;

  /// Frequency map of numeric literal lexemes across the project.
  final Map<String, int> numberLiteralFrequencies;

  /// Count of // ignore: fcheck_* directives found.
  final int ignoreDirectivesCount;

  /// Per-file count of // ignore: fcheck_* directives.
  final Map<String, int> ignoreDirectiveCountsByFile;

  /// Total number of widget implementations derived from StatelessWidget.
  final int totalStatelessWidgetCount;

  /// Total number of widget implementations derived from StatefulWidget.
  final int totalStatefulWidgetCount;

  /// Creates a metrics aggregation result.
  const MetricsAggregationResult({
    required this.fileMetrics,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.totalFunctionCount,
    required this.totalStringLiteralCount,
    required this.totalNumberLiteralCount,
    required this.duplicatedStringLiteralCount,
    required this.duplicatedNumberLiteralCount,
    required this.stringLiteralFrequencies,
    required this.numberLiteralFrequencies,
    required this.ignoreDirectivesCount,
    required this.ignoreDirectiveCountsByFile,
    required this.totalStatelessWidgetCount,
    required this.totalStatefulWidgetCount,
  });
}
