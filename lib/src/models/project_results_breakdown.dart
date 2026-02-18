const int _scorePercentMultiplier = 100;
const int _scorePercentScaleDivisor = 1;
const double _minimumScorePercent = 0.0;
const double _maximumScorePercent =
    _scorePercentMultiplier / _scorePercentScaleDivisor;

/// Per-analyzer score and issue summary for one metrics run.
class AnalyzerScoreBreakdown {
  /// Creates a score snapshot for a single analyzer domain.
  const AnalyzerScoreBreakdown({
    required this.key,
    required this.label,
    required this.enabled,
    required this.issueCount,
    required this.score,
  });

  /// Machine-readable analyzer key (for example `magic_numbers`).
  final String key;

  /// Human-readable analyzer label (for example `Magic numbers`).
  final String label;

  /// Whether the analyzer was enabled for this run.
  final bool enabled;

  /// Number of issues produced by the analyzer.
  final int issueCount;

  /// Analyzer score normalized to the [0.0, 1.0] range.
  final double score;

  /// Rounded score percentage in the [0, 100] range.
  int get scorePercent => (score * _scorePercentMultiplier)
      .clamp(_minimumScorePercent, _maximumScorePercent)
      .round();
}
