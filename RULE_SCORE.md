# RULE_SCORE.md

This file defines how the overall compliance score is calculated and displayed.

## Goals

- Provide a single quality score from `0%` to `100%`.
- Keep the score size-aware so larger projects are not over-penalized for a few issues.
- Make `100%` strictly mean "no detected compliance penalties".
- Highlight where to invest next for the fastest score improvement.
- Cap each analyzer impact so one analyzer can never consume more than its own score slice.
- Discourage score gaming via excessive `ignore`, custom excludes, or disabled analyzers.

## Score Inputs

Only enabled analyzers contribute to the score.

- `one_class_per_file`
- `hardcoded_strings`
- `magic_numbers`
- `source_sorting`
- `layers`
- `secrets`
- `dead_code`
- `duplicate_code`
- `documentation`

Additional suppression inputs are tracked and can deduct points:

- `// ignore: fcheck_*` directives in analyzed Dart files
- Custom-excluded Dart files (from `.fcheck`/CLI exclude glob patterns)
- Disabled analyzers

## Analyzer Share

The total `100%` is split equally across enabled analyzers.

```text
N = number of enabled analyzers
sharePerAnalyzer = 100 / N
```

Examples:

- 9 enabled analyzers -> each analyzer owns `11.11%`.
- 10 enabled analyzers -> each analyzer owns `10%`.

This means even if one analyzer has extreme failures, the maximum loss from that
single analyzer is its own share.

## Per-Domain Score (0.0 to 1.0)

All domain scores are clamped to `[0.0, 1.0]`.

### 1) One class per file

```text
score = 1 - (violations / max(1, dartFiles))
```

### 2) Hardcoded strings

```text
budget = max(
  3.0,
  dartFiles * (usesLocalization ? 0.8 : 2.0),
)
score = 1 - (hardcodedStringIssues / budget)
```

### 3) Magic numbers

```text
budget = max(
  4.0,
  (dartFiles * 2.5) + (linesOfCode / 450),
)
score = 1 - (magicNumberIssues / budget)
```

### 4) Source sorting

```text
budget = max(2.0, dartFiles * 0.75)
score = 1 - (sourceSortIssues / budget)
```

### 5) Layers architecture

```text
budget = max(2.0, max(1, layersEdgeCount) * 0.20)
score = 1 - (layersIssues / budget)
```

### 6) Secrets

```text
budget = 1.5
score = 1 - (secretIssues / budget)
```

### 7) Dead code

```text
budget = max(3.0, dartFiles * 0.8)
score = 1 - (deadCodeIssues / budget)
```

### 8) Duplicate code

```text
duplicateImpactLines = sum(issue.lineCount * issue.similarity)
duplicateRatio = duplicateImpactLines / max(1, linesOfCode)
score = 1 - (duplicateRatio * 2.5)
```

### 9) Documentation

```text
budget = max(2.0, dartFiles * 0.6)
score = 1 - (documentationIssues / budget)
```

## Suppression Penalty

The score includes a budget-based suppression penalty so occasional suppressions
are tolerated, but sustained overuse is penalized.

```text
ignoreBudget = max(3.0, dartFiles * 0.12 + linesOfCode / 2500)
customExcludeBudget = max(2.0, (dartFiles + customExcludedFiles) * 0.08)
disabledBudget = 1.0

over(used, budget) = max(0, (used - budget) / budget)

weightedOveruse =
  over(ignoreDirectives, ignoreBudget) * 0.45 +
  over(customExcludedFiles, customExcludeBudget) * 0.35 +
  over(disabledAnalyzers, disabledBudget) * 0.20

suppressionPenaltyPoints = round(clamp(weightedOveruse * 25, 0, 25))
```

## Overall Score

```text
averageDomainScore = sum(domainScore) / N
basePercent = averageDomainScore * 100
score = round(clamp(basePercent - suppressionPenaltyPoints, 0, 100))
```

Special rule:

- If rounded score is `100` but any enabled domain score is `< 1.0`, final score is forced to `99`.
- If suppression penalty is greater than `0`, final score cannot remain `100` (it is forced to `99` when rounded to `100`).
- This guarantees `100%` is only shown when all enabled domains are fully compliant.

## Focus Area Selection

The "Focus Area" is the highest-impact enabled domain, plus suppression hygiene
when suppression penalty is active:

```text
penaltyImpact = (1 - domainScore)
```

Tie-breaker: higher `issueCount` wins.

If there are no open penalties, focus area is `None`.

## Dashboard Color Legend

Dashboard domain values use ANSI colors (when terminal supports them):

- Compliance score:
  - `green`: `>= 95`
  - `yellow`: `>= 85`
  - `orange`: `>= 70`
  - `red`: `< 70`
- `green`: perfect (`0` issues)
- `yellow`: good (`1` issue)
- `orange`: needs attention (`2-3` issues)
- `red`: bad (`>= 4` issues)
- `red` (always) for `secrets` when `> 0` issues
- `disabled` analyzers are shown as plain `disabled`

## Invest Next Message

The CLI prints a domain-specific recommendation for the selected focus area.
This text is deterministic and mapped by domain key.

## Source of Truth

- Implementation: `lib/src/analyzers/metrics/project_metrics_analyzer.dart`
- Output model: `lib/src/metrics/project_metrics.dart`
- Console rendering: `bin/console_output.dart`
