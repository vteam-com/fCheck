# RULE_METRICS.md

This file defines project-level metrics architecture and behavior.

## Goals

- Keep `ProjectMetrics` as a stable output contract for CLI, JSON, and tests.
- Compute compliance scoring through a dedicated analyzer module, not inside the data model.
- Reuse the same analyzer-style separation used by other domains.

## Architecture

- `AnalyzeFolder.analyze()` in `lib/fcheck.dart` aggregates raw project stats and issue lists.
- `ProjectMetrics` in `lib/src/metrics/project_metrics.dart` stores those stats as immutable output data.
- `ProjectMetricsAnalyzer` in `lib/src/analyzers/metrics/project_metrics_analyzer.dart` computes:
  - `complianceScore`
  - `suppressionPenaltyPoints`
  - `complianceFocusAreaKey`
  - `complianceFocusAreaLabel`
  - `complianceFocusAreaIssueCount`
  - `complianceNextInvestment`

## Input Contract

`ProjectMetricsAnalyzer` consumes `ProjectMetricsAnalysisInput`, which includes:

- project size signals (`totalDartFiles`, `totalLinesOfCode`)
- per-file metrics (`fileMetrics`)
- per-domain issue lists (hardcoded, magic numbers, sorting, layers, secrets, dead code, duplicate code, documentation)
- suppression signals (`ignoreDirectivesCount`, `customExcludedFilesCount`, `disabledAnalyzersCount`)
- analyzer enable flags
- context values (`layersEdgeCount`, `usesLocalization`)

## Derived Metrics

`ProjectMetrics` exposes:

- `commentRatio = totalCommentLines / totalLinesOfCode` (0 when LOC is 0)
- widget implementation totals split by `StatelessWidget` and `StatefulWidget`, including derived classes when inheritance can be resolved unambiguously
- `disabledAnalyzersCount` from analyzer enabled flags
- analyzer-driven compliance and focus getters via cached `ProjectMetricsAnalyzer` output

## Scoring Rules

Scoring and suppression formulas are defined in:

- `RULE_SCORE.md` (human-readable spec)
- `lib/src/analyzers/metrics/project_metrics_analyzer.dart` (implementation)

Keep these in sync when budgets, weights, or focus logic changes.

## Source of Truth

- Data model: `lib/src/metrics/project_metrics.dart`
- Analyzer: `lib/src/analyzers/metrics/project_metrics_analyzer.dart`
- Score formulas: `RULE_SCORE.md`
