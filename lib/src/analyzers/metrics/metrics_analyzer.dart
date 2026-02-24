import 'dart:math' as math;

import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_file_data.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_input.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_results.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/project_results.dart';
import 'package:fcheck/src/models/project_results_breakdown.dart';

/// Analyzer for computing project-level compliance scoring and focus guidance.
class MetricsAnalyzer {
  static const double _minHardcodedBudget = 3.0;
  static const double _localizedHardcodedBudgetPerFile = 0.8;
  static const double _minMagicNumberBudget = 4.0;
  static const double _magicNumberBudgetPerFile = 2.5;
  static const double _magicNumberBudgetPerLoc = 1 / 450;
  static const double _minSourceSortBudget = 2.0;
  static const double _sourceSortBudgetPerFile = 0.75;
  static const double _minLayersBudget = 2.0;
  static const double _layersBudgetPerEdge = 0.20;
  static const double _secretsBudget = 1.5;
  static const double _minDeadCodeBudget = 3.0;
  static const double _deadCodeBudgetPerFile = 0.8;
  static const double _minDocumentationBudget = 2.0;
  static const double _documentationBudgetPerFile = 0.6;
  static const double _duplicateRatioPenaltyMultiplier = 2.5;
  static const double _minIgnoreDirectiveBudget = 3.0;
  static const double _ignoreDirectiveBudgetPerFile = 0.12;
  static const double _ignoreDirectiveBudgetPerLoc = 1 / 2500;
  static const double _minCustomExcludedFileBudget = 2.0;
  static const double _customExcludedFileBudgetRatio = 0.08;
  static const double _disabledAnalyzerBudget = 1.0;
  static const double _ignorePenaltyWeight = 0.45;
  static const double _customExcludedPenaltyWeight = 0.35;
  static const double _disabledAnalyzerPenaltyWeight = 0.20;
  static const int _maxSuppressionPenaltyPoints = 25;
  static const int _maxPercent = 100;

  /// Creates a metrics analyzer.
  const MetricsAnalyzer();

  /// Computes compliance score, focus area, and investment guidance.
  ProjectMetricsAnalysisResult analyze(ProjectMetricsAnalysisInput input) {
    final complianceAreas = _buildComplianceAreas(input);
    final analyzerScores = complianceAreas
        .map(
          (area) => AnalyzerScoreBreakdown(
            key: area.key,
            label: area.label,
            enabled: area.enabled,
            issueCount: area.issueCount,
            score: area.score,
          ),
        )
        .toList(growable: false);
    final enabledAreas = complianceAreas
        .where((area) => area.enabled)
        .toList(growable: false);

    final suppressionPenaltyPoints = _computeSuppressionPenaltyPoints(input);
    final averageAreaScore = enabledAreas.isEmpty
        ? 1.0
        : enabledAreas.fold<double>(0, (sum, area) => sum + area.score) /
              enabledAreas.length;
    final baseScore = averageAreaScore * _maxPercent;
    final scoreAfterSuppression = baseScore - suppressionPenaltyPoints;
    var complianceScore = scoreAfterSuppression
        .clamp(0, _maxPercent.toDouble())
        .round();

    if (complianceScore == _maxPercent &&
        (enabledAreas.any((area) => area.score < 1) ||
            suppressionPenaltyPoints > 0)) {
      complianceScore = _maxPercent - 1;
    }

    final primaryFocusArea = _resolvePrimaryFocusArea(
      input: input,
      enabledAreas: enabledAreas,
      suppressionPenaltyPoints: suppressionPenaltyPoints,
    );

    return ProjectMetricsAnalysisResult(
      complianceScore: complianceScore,
      suppressionPenaltyPoints: suppressionPenaltyPoints,
      complianceFocusAreaKey: primaryFocusArea?.key ?? 'none',
      complianceFocusAreaLabel: primaryFocusArea?.label ?? 'None',
      complianceFocusAreaIssueCount: primaryFocusArea?.issueCount ?? 0,
      complianceNextInvestment: _buildNextInvestment(
        primaryFocusArea,
        usesLocalization: input.usesLocalization,
      ),
      analyzerScores: analyzerScores,
    );
  }

  /// Builds per-domain scores before equal-share averaging.
  List<_ComplianceAreaScore> _buildComplianceAreas(
    ProjectMetricsAnalysisInput input,
  ) {
    final safeDartFileCount = math.max(1, input.totalDartFiles);
    final safeLoc = math.max(1, input.totalLinesOfCode);

    final oneClassPerFileViolations = input.fileMetrics
        .where((metric) => !metric.isOneClassPerFileCompliant)
        .length;
    final hardcodedStringsPassive = !input.usesLocalization;
    final hardcodedStringsEnabled =
        input.hardcodedStringsAnalyzerEnabled && !hardcodedStringsPassive;

    final hardcodedBudget = math.max(
      _minHardcodedBudget,
      safeDartFileCount * _localizedHardcodedBudgetPerFile,
    );
    final magicNumbersBudget = math.max(
      _minMagicNumberBudget,
      safeDartFileCount * _magicNumberBudgetPerFile +
          safeLoc * _magicNumberBudgetPerLoc,
    );
    final sourceSortingBudget = math.max(
      _minSourceSortBudget,
      safeDartFileCount * _sourceSortBudgetPerFile,
    );
    final layersBaseline = math.max(1, input.layersEdgeCount);
    final layersBudget = math.max(
      _minLayersBudget,
      layersBaseline * _layersBudgetPerEdge,
    );
    final deadCodeBudget = math.max(
      _minDeadCodeBudget,
      safeDartFileCount * _deadCodeBudgetPerFile,
    );
    final documentationBudget = math.max(
      _minDocumentationBudget,
      safeDartFileCount * _documentationBudgetPerFile,
    );
    final duplicateImpactLines = input.duplicateCodeIssues.fold<double>(
      0,
      (sum, issue) => sum + (issue.lineCount * issue.similarity),
    );
    final duplicateRatio = duplicateImpactLines / safeLoc;
    final codeSizeScore = _computeCodeSizeScore(input.codeSizeArtifacts, input);

    return [
      _ComplianceAreaScore(
        key: 'code_size',
        label: 'Code size',
        enabled: input.codeSizeAnalyzerEnabled,
        issueCount: codeSizeScore.issueCount,
        score: codeSizeScore.score,
      ),
      _ComplianceAreaScore(
        key: 'one_class_per_file',
        label: 'One class per file',
        enabled: input.oneClassPerFileAnalyzerEnabled,
        issueCount: oneClassPerFileViolations,
        score: _fractionScore(
          issues: oneClassPerFileViolations,
          total: safeDartFileCount,
        ),
      ),
      _ComplianceAreaScore(
        key: 'hardcoded_strings',
        label: 'Hardcoded strings',
        enabled: hardcodedStringsEnabled,
        issueCount: input.hardcodedStringIssues.length,
        score: hardcodedStringsEnabled
            ? _budgetScore(
                issues: input.hardcodedStringIssues.length,
                budget: hardcodedBudget,
              )
            : 1.0,
      ),
      _ComplianceAreaScore(
        key: 'magic_numbers',
        label: 'Magic numbers',
        enabled: input.magicNumbersAnalyzerEnabled,
        issueCount: input.magicNumberIssues.length,
        score: _budgetScore(
          issues: input.magicNumberIssues.length,
          budget: magicNumbersBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'source_sorting',
        label: 'Source sorting',
        enabled: input.sourceSortingAnalyzerEnabled,
        issueCount: input.sourceSortIssues.length,
        score: _budgetScore(
          issues: input.sourceSortIssues.length,
          budget: sourceSortingBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'layers',
        label: 'Layers architecture',
        enabled: input.layersAnalyzerEnabled,
        issueCount: input.layersIssues.length,
        score: _budgetScore(
          issues: input.layersIssues.length,
          budget: layersBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'secrets',
        label: 'Secrets',
        enabled: input.secretsAnalyzerEnabled,
        issueCount: input.secretIssues.length,
        score: _budgetScore(
          issues: input.secretIssues.length,
          budget: _secretsBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'dead_code',
        label: 'Dead code',
        enabled: input.deadCodeAnalyzerEnabled,
        issueCount: input.deadCodeIssues.length,
        score: _budgetScore(
          issues: input.deadCodeIssues.length,
          budget: deadCodeBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'duplicate_code',
        label: 'Duplicate code',
        enabled: input.duplicateCodeAnalyzerEnabled,
        issueCount: input.duplicateCodeIssues.length,
        score: _clampToUnitRange(
          1 - (duplicateRatio * _duplicateRatioPenaltyMultiplier),
        ),
      ),
      _ComplianceAreaScore(
        key: 'documentation',
        label: 'Documentation',
        enabled: input.documentationAnalyzerEnabled,
        issueCount: input.documentationIssues.length,
        score: _budgetScore(
          issues: input.documentationIssues.length,
          budget: documentationBudget,
        ),
      ),
    ];
  }

  /// Computes penalty from over-budget suppression usage.
  int _computeSuppressionPenaltyPoints(ProjectMetricsAnalysisInput input) {
    final ignoreOverBudgetRatio = _overBudgetRatio(
      used: input.ignoreDirectivesCount.toDouble(),
      budget: _ignoreDirectiveBudget(input),
    );
    final customExcludedOverBudgetRatio = _overBudgetRatio(
      used: input.customExcludedFilesCount.toDouble(),
      budget: _customExcludedFilesBudget(input),
    );
    final disabledAnalyzersOverBudgetRatio = _overBudgetRatio(
      used: input.disabledAnalyzersCount.toDouble(),
      budget: _disabledAnalyzerBudget,
    );

    final weightedOveruse =
        ignoreOverBudgetRatio * _ignorePenaltyWeight +
        customExcludedOverBudgetRatio * _customExcludedPenaltyWeight +
        disabledAnalyzersOverBudgetRatio * _disabledAnalyzerPenaltyWeight;

    final penalty = weightedOveruse * _maxSuppressionPenaltyPoints;
    return penalty.clamp(0, _maxSuppressionPenaltyPoints.toDouble()).round();
  }

  /// Chooses the highest-impact focus area (including checks bypassed).
  _ComplianceAreaScore? _resolvePrimaryFocusArea({
    required ProjectMetricsAnalysisInput input,
    required List<_ComplianceAreaScore> enabledAreas,
    required int suppressionPenaltyPoints,
  }) {
    final candidates = enabledAreas
        .where((area) => area.score < 1 || area.issueCount > 0)
        .toList();
    final suppressionFocusArea = _buildSuppressionFocusArea(
      input,
      suppressionPenaltyPoints,
    );
    if (suppressionFocusArea != null) {
      candidates.add(suppressionFocusArea);
    }
    if (candidates.isEmpty) {
      return null;
    }

    var best = candidates.first;
    var bestImpact = best.penaltyImpact;
    for (final candidate in candidates.skip(1)) {
      final candidateImpact = candidate.penaltyImpact;
      if (candidateImpact > bestImpact) {
        best = candidate;
        bestImpact = candidateImpact;
        continue;
      }
      if (candidateImpact == bestImpact &&
          candidate.issueCount > best.issueCount) {
        best = candidate;
      }
    }
    return best;
  }

  /// Builds a synthetic focus area when suppression penalties are active.
  _ComplianceAreaScore? _buildSuppressionFocusArea(
    ProjectMetricsAnalysisInput input,
    int suppressionPenaltyPoints,
  ) {
    if (suppressionPenaltyPoints <= 0) {
      return null;
    }
    final suppressionEntries =
        input.ignoreDirectivesCount +
        input.customExcludedFilesCount +
        input.disabledAnalyzersCount;
    return _ComplianceAreaScore(
      key: 'suppression_hygiene',
      label: 'Checks bypassed',
      enabled: true,
      issueCount: suppressionEntries,
      score: _clampToUnitRange(
        1 - (suppressionPenaltyPoints / _maxSuppressionPenaltyPoints),
      ),
    );
  }

  /// Computes budget for ignore-directive usage.
  double _ignoreDirectiveBudget(ProjectMetricsAnalysisInput input) {
    final safeDartFileCount = math.max(1, input.totalDartFiles);
    final safeLoc = math.max(1, input.totalLinesOfCode);
    return math.max(
      _minIgnoreDirectiveBudget,
      safeDartFileCount * _ignoreDirectiveBudgetPerFile +
          safeLoc * _ignoreDirectiveBudgetPerLoc,
    );
  }

  /// Computes budget for custom excluded Dart files.
  double _customExcludedFilesBudget(ProjectMetricsAnalysisInput input) {
    final scopeDartFiles = math.max(
      1,
      input.totalDartFiles + input.customExcludedFilesCount,
    );
    return math.max(
      _minCustomExcludedFileBudget,
      scopeDartFiles * _customExcludedFileBudgetRatio,
    );
  }

  /// Returns deterministic invest-next guidance for the focus area.
  String _buildNextInvestment(
    _ComplianceAreaScore? focusArea, {
    required bool usesLocalization,
  }) {
    if (focusArea == null) {
      return 'Maintain this level by enforcing fcheck in CI on every pull request.';
    }

    switch (focusArea.key) {
      case 'one_class_per_file':
        return 'Split files with multiple classes into focused files.';
      case 'code_size':
        return 'Break up files/classes/functions/methods that exceed your configured LOC thresholds.';
      case 'hardcoded_strings':
        return usesLocalization
            ? 'Move user-facing literals into localization resources (.arb).'
            : 'Adopt localization and replace user-facing literals with keys.';
      case 'magic_numbers':
        return 'Replace magic numbers with named constants near domain logic.';
      case 'source_sorting':
        return 'Run with --fix to auto-sort Flutter members, then review remaining classes.';
      case 'layers':
        return 'Remove cross-layer imports and enforce dependency direction in core modules.';
      case 'secrets':
        return 'Remove secrets from source and load them from secure config or environment.';
      case 'dead_code':
        return 'Delete unused files, classes, and functions to reduce maintenance cost.';
      case 'duplicate_code':
        return 'Extract repeated code paths into shared helpers or reusable widgets.';
      case 'documentation':
        return 'Document public APIs and add context comments to complex private logic.';
      case 'suppression_hygiene':
        return 'Reduce custom excludes, restore disabled analyzers, and remove stale fcheck ignore directives.';
    }

    return 'Invest in the lowest-scoring quality area to raise overall compliance.';
  }

  /// Computes code-size score from absolute LOC threshold overages.
  ({int issueCount, double score}) _computeCodeSizeScore(
    List<CodeSizeArtifact> codeSizeArtifacts,
    ProjectMetricsAnalysisInput input,
  ) {
    if (codeSizeArtifacts.isEmpty) {
      return (issueCount: 0, score: 1.0);
    }

    var issueCount = 0;
    var penaltySum = 0.0;
    for (final artifact in codeSizeArtifacts) {
      final threshold = switch (artifact.kind) {
        CodeSizeArtifactKind.file => input.codeSizeThresholds.maxFileLoc,
        CodeSizeArtifactKind.classDeclaration =>
          input.codeSizeThresholds.maxClassLoc,
        CodeSizeArtifactKind.function =>
          input.codeSizeThresholds.maxFunctionLoc,
        CodeSizeArtifactKind.method => input.codeSizeThresholds.maxMethodLoc,
      };
      final overflow = artifact.linesOfCode - threshold;
      if (overflow <= 0) {
        continue;
      }
      issueCount++;
      penaltySum += overflow / threshold;
    }

    if (issueCount == 0) {
      return (issueCount: 0, score: 1.0);
    }

    final normalizedPenalty = penaltySum / codeSizeArtifacts.length;
    final score = 1 - normalizedPenalty;
    return (issueCount: issueCount, score: _clampToUnitRange(score));
  }

  /// Aggregates file metrics from collected per-file metrics data.
  ///
  /// This method iterates through the collected [MetricsFileData], aggregates
  /// total lines of code and comment lines, counts ignore directives,
  /// and builds the final list of per-file metrics.
  MetricsAggregationResult aggregate(List<MetricsFileData> fileData) {
    final fileMetricsList = <FileMetrics>[];
    int totalLoc = 0;
    int totalComments = 0;
    int totalFunctions = 0;
    int totalStrings = 0;
    int totalNumbers = 0;
    int ignoreDirectivesCount = 0;
    final ignoreDirectiveCountsByFile = <String, int>{};

    for (final data in fileData) {
      final metrics = data.metrics;
      fileMetricsList.add(metrics);
      totalLoc += metrics.linesOfCode;
      totalComments += metrics.commentLines;
      totalFunctions += metrics.functionCount;
      totalStrings += metrics.stringLiteralCount;
      totalNumbers += metrics.numberLiteralCount;
      ignoreDirectivesCount += data.fcheckIgnoreDirectiveCount;
      if (data.fcheckIgnoreDirectiveCount > 0) {
        ignoreDirectiveCountsByFile[metrics.path] =
            data.fcheckIgnoreDirectiveCount;
      }
    }

    final sortedIgnoreDirectiveFiles = ignoreDirectiveCountsByFile.keys.toList()
      ..sort();
    final sortedIgnoreDirectiveCountsByFile = <String, int>{
      for (final path in sortedIgnoreDirectiveFiles)
        path: ignoreDirectiveCountsByFile[path]!,
    };

    return MetricsAggregationResult(
      fileMetrics: fileMetricsList,
      totalLinesOfCode: totalLoc,
      totalCommentLines: totalComments,
      totalFunctionCount: totalFunctions,
      totalStringLiteralCount: totalStrings,
      totalNumberLiteralCount: totalNumbers,
      ignoreDirectivesCount: ignoreDirectivesCount,
      ignoreDirectiveCountsByFile: sortedIgnoreDirectiveCountsByFile,
    );
  }
}

/// Converts raw issue count against total scope into a [0, 1] score.
double _fractionScore({required int issues, required int total}) {
  if (total <= 0) {
    return 1;
  }
  return _clampToUnitRange(1 - (issues / total));
}

/// Converts raw issue count against a budget into a [0, 1] score.
double _budgetScore({required int issues, required double budget}) {
  if (budget <= 0) {
    return 1;
  }
  return _clampToUnitRange(1 - (issues / budget));
}

/// Returns ratio of usage above budget, or `0` when within budget.
double _overBudgetRatio({required double used, required double budget}) {
  if (budget <= 0) {
    return 0;
  }
  final overBudget = used - budget;
  if (overBudget <= 0) {
    return 0;
  }
  return overBudget / budget;
}

/// Clamps [value] into the inclusive unit interval `[0, 1]`.
double _clampToUnitRange(double value) {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

class _ComplianceAreaScore {
  final String key;
  final String label;
  final bool enabled;
  final int issueCount;
  final double score;

  const _ComplianceAreaScore({
    required this.key,
    required this.label,
    required this.enabled,
    required this.issueCount,
    required this.score,
  });

  /// Penalty contribution used when choosing the primary focus area.
  double get penaltyImpact => (1 - score);
}
