import 'package:fcheck/src/models/project_results_breakdown.dart';

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
