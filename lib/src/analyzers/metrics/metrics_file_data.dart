import 'package:fcheck/src/models/file_metrics.dart';

/// Represents metrics data collected for a single file during unified analysis.
class MetricsFileData {
  /// The quality metrics for the file.
  final FileMetrics metrics;

  /// The number of fcheck ignore directives found in the file.
  final int fcheckIgnoreDirectiveCount;

  /// Creates a new metrics file data instance.
  const MetricsFileData({
    required this.metrics,
    required this.fcheckIgnoreDirectiveCount,
  });
}
