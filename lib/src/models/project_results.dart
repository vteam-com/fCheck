/// Results of the project-level compliance analysis.
class ProjectMetricsAnalysisResult {
  /// Creates a scoring result.
  const ProjectMetricsAnalysisResult({
    required this.complianceScore,
    required this.suppressionPenaltyPoints,
    required this.complianceFocusAreaKey,
    required this.complianceFocusAreaLabel,
    required this.complianceFocusAreaIssueCount,
    required this.complianceNextInvestment,
    required this.analyzerScores,
  });

  /// Final compliance score from 0..100.
  final int complianceScore;

  /// Budget-based penalty points from suppression overuse.
  final int suppressionPenaltyPoints;

  /// Machine-readable focus area key.
  final String complianceFocusAreaKey;

  /// Human-readable focus area label.
  final String complianceFocusAreaLabel;

  /// Number of issues in selected focus area.
  final int complianceFocusAreaIssueCount;

  /// Suggested next investment area for score improvement.
  final String complianceNextInvestment;

  /// Per-analyzer score breakdown used by console and JSON reporting.
  final List<AnalyzerScoreBreakdown> analyzerScores;
}

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
  int get scorePercent => (score * 100).clamp(0.0, 100.0).round();
}
