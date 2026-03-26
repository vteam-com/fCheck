# RULES.md

This file defines baseline contributor expectations for the fCheck project and this repository.

## Project Overview

fCheck is a Dart CLI tool for analyzing Flutter and Dart project quality. It provides metrics and domain-specific checks including:

- Hardcoded string detection
- Magic number detection
- Dead code detection
- Duplicate code detection
- Secret/PII scanning
- Flutter widget member sorting
- Code size threshold analysis
- Layer dependency analysis and visualization
- Localization coverage and translation completeness analysis
- Project metrics (files, folders, LOC, comment ratios, widget implementation counts, literal inventory with duplicate ratios, and test discovery counts including test case totals)

## Domain Rules (Start Here)

- `RULES_HARDCODED_STRINGS.md` for string literal detection rules.
- `RULES_MAGIC_NUMBERS.md` for numeric literal detection rules.
- `RULES_DEAD_CODE.md` for dead code detection rules.
- `RULES_SECRETS.md` for secret/PII detection rules.
- `RULES_DUPLICATE_CODE.md` for duplicate code detection rules.
- `RULES_DOCUMENTATION.md` for README/API documentation quality rules.
- `RULES_LOCALIZATION.md` for localization coverage and translation completeness rules.
- Localization rules also include orphan English ARB key detection based on actual app-source usage under `lib/`.
- `RULES_SORTING.md` for Flutter widget member ordering rules.
- `RULES_LAYERS.md` for dependency graph and layer analysis rules.

## Analyzer Naming and Sorting Conventions

All analyzers must follow these strict naming and sorting conventions:

### Display Naming Rules

- **First Letter Uppercase**: All analyzer display names must start with an uppercase letter
- **Title Case**: Use title case for multi-word analyzer names (e.g., "One class per file", "Source sorting")
- **Consistent Capitalization**: Maintain consistent capitalization patterns across all analyzers

### Sorting Rules

- **Alphabetical Order**: Analyzers must be displayed in strict alphabetical order by their display names
- **Sort Key Consistency**: Sort keys must match the analyzer title mapping in `console_output_report_helpers.dart`
- **Underscore Format**: Sort keys use underscores (e.g., 'hardcoded_strings') while display names use spaces

### Analyzer Display Order

Display order is not a fixed hardcoded list across all runs:

1. Clean analyzers (`[✓]`) sorted by analyzer title ascending
2. Disabled analyzers (`[-]`) sorted by analyzer title ascending
3. Warning/failing analyzers (`[!]`, `[x]`) sorted by score descending, then analyzer title ascending

When titles are compared alphabetically, the current analyzer names are:

1. Checks bypassed
2. Code size
3. Dead code
4. Documentation
5. Duplicate code
6. Hardcoded strings
7. Layers architecture
8. Localization
9. Magic numbers
10. One class per file
11. Secrets
12. Source sorting

- `RULES_LOC.md` for code-size thresholds, scoring, and reporting.
- `RULE_METRICS.md` for project metrics analyzer architecture.
- `RULE_SCORE.md` for overall compliance scoring rules.

These `RULES_*.md` files are the source of truth for rule behavior. Keep
`README.md` high-level and avoid duplicating detailed rule internals there.

## Analyzer Architecture

- `AnalyzeFolder` in `lib/fcheck.dart` wires the CLI analysis pipeline.
- `AnalyzerRunner` in `lib/src/analyzer_runner/analyzer_runner.dart` parses each Dart file once and runs delegates.
- Per-domain delegates live under `lib/src/analyzers/**/**_delegate.dart`.
- Project-level compliance scoring is computed by `ProjectMetricsAnalyzer` after unified analysis aggregation.
- File discovery and default exclusions are centralized in `lib/src/input_output/file_utils.dart`.
- Ignore directives are implemented in `lib/src/models/ignore_config.dart`.
- **Project metadata contract:** `AnalyzeFolder` is the single entry point for analysis and is the only component that reads `pubspec.yaml`.
- `AnalyzeFolder` reads `pubspec.yaml` once, derives `projectType`, `projectName`, `version`, and `packageName`, and passes these values into delegates/analyzers.
- Domain analyzers must **not** read `pubspec.yaml` or rescan for project roots; they should rely on values provided by `AnalyzeFolder`.

## Shared Rule Conventions

- File discovery comes from `FileUtils.listDartFiles` (including default excludes and CLI/project excludes).
- Full-project analysis should run in the unified `AnalyzerRunner` pass.
- File-level ignore directives are read from leading comments via `IgnoreConfig.hasIgnoreForFileDirective`.
- Node-level ignores use `// ignore: fcheck_<domain>` on the relevant line for AST-based analyzers.
- Node-level ignore parsing is whitespace tolerant around `ignore` and `:` (for example `//ignore:fcheck_<domain>`).
- Generated Dart files (`*.g.dart`) are treated as dependency/usage contributors, while non-actionable analyzer findings are suppressed by domain-specific delegates.
- Dead-code specific behavior: files with top-of-file `// ignore: fcheck_dead_code`
  suppress dead-code findings for declarations in that file, but still contribute
  dependencies/usages used by project-wide dead-code reachability.
- Dead-code specific behavior: functions/methods annotated with `@Preview`
  (including prefixed forms like `@ui.Preview`) are treated as externally used
  and are not reported as dead functions.
- Dead-code usage collection includes identifier usage plus operator/property
  syntax signals to reduce false positives for overloaded operators and
  getter/setter access patterns.

## Repository Structure

- `lib/` main source code
- `lib/src/analyzers/` domain analyzers
- `lib/src/analyzer_runner/` unified analysis runner and delegates
- `lib/src/input_output/` file system scanning and output helpers
- `lib/src/models/` shared data models and ignore configuration
- `lib/src/metrics/` project and file metrics
- `lib/src/graphs/` graph exporters (SVG, Mermaid, PlantUML)
- `test/` unit tests
- `integration_test/` integration tests
- `example/` example project for testing
- `tool/` development scripts

## Development Commands

- `dart pub get` install dependencies
- `dart run ./bin/fcheck.dart` run the tool
- `dart format .` format all Dart files
- `dart fix --apply` apply automated fixes
- `flutter analyze lib test` run static analysis
- `dart test` run all tests
- `./tool/check.sh` run format, analyze, tests, and fCheck on the example

## Key Files

- `bin/fcheck.dart` CLI entry point
- `lib/fcheck.dart` analysis engine and report formatting
- `lib/src/analyzer_runner/analyzer_runner.dart` unified analysis traversal
- `lib/src/analyzer_runner/analyzer_delegates.dart` per-domain adapters
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart`
- `lib/src/analyzers/magic_numbers/magic_number_visitor.dart`
- `lib/src/analyzers/magic_numbers/magic_number_issue.dart`
- `lib/src/analyzers/secrets/secret_scanner.dart`
- `lib/src/analyzers/secrets/secret_issue.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_analyzer.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_visitor.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_issue.dart`
- `lib/src/analyzers/documentation/documentation_analyzer.dart`
- `lib/src/analyzers/documentation/documentation_visitor.dart`
- `lib/src/analyzers/documentation/documentation_issue.dart`
- `lib/src/analyzers/sorted/sort_members.dart`
- `lib/src/analyzers/sorted/sort_issue.dart`
- `lib/src/analyzers/layers/layers_analyzer.dart`
- `lib/src/analyzers/metrics/project_metrics_analyzer.dart`
- `lib/src/metrics/project_metrics.dart`

## Test Structure

- `test/hardcoded_string_analyzer_test.dart`
- `test/magic_number_analyzer_test.dart`
- `test/layers_analyzer_test.dart`
- `test/project_metrics_test.dart`
- `test/cli_test.dart`

## Test Coverage Rules

- Maintain overall project code coverage at `>= 85%`.
- Do not merge changes that reduce overall coverage.
- Add or update tests for every behavior change (new feature, bug fix, or rule change).
- For new/modified files in `lib/src/analyzers/` and `lib/src/analyzer_runner/`, add direct unit tests that cover:
  - happy path behavior
  - guard/skip paths
  - serialization/formatting paths (`toJson()`, `toString()`) for issue models
- Prefer focused unit tests for small models/utilities and integration tests for CLI/report behavior.
- Run the full test suite before merging: `dart test`.
- When validating coverage locally, generate coverage data with:
  - `dart test --coverage=coverage`

## CI Quality Gate

- GitHub Actions workflow is defined in `.github/workflows/ci.yml`.
- CI must run format check, static analysis, tests, and `fcheck` against this repository.
- The self-check compliance score gate is strict: `summary.complianceScore` must equal `100`, otherwise the workflow fails.
- CI should publish `fcheck-report.json` as an artifact for failure investigation.

## CLI Help Sync Rule

- Any user-facing behavior change must update CLI help output in the same PR.
- This includes changes to:
  - CLI flags/options
  - analyzer names or availability
  - ignore directive support
  - `.fcheck` schema or supported config keys
  - default values shown in examples (for example duplicate-code options)
- Required update points:
  - `--help` option descriptions in `bin/console_input.dart`
  - `--help-ignore` guidance in `bin/console_output.dart`
  - related examples in `README.md`
  - CLI expectations in `test/cli_test.dart`
- Do not ship new behavior where help text still describes old behavior.

## Usage Patterns

- `fcheck` analyze current directory
- `fcheck /path/to/project` analyze specific project
- `fcheck --fix` auto-fix sorting issues (Flutter class members + import directive order)
- `fcheck --exclude "**/generated/**"` exclude glob patterns
- `fcheck --excluded` list excluded files and directories
- `fcheck --ignores` list project ignore/suppression entries (`.fcheck` + Dart directives)
- `fcheck --svg` generate SVG dependency graph
- `fcheck --mermaid` generate Mermaid graph
- `fcheck --plantuml` generate PlantUML graph
- `fcheck --json` output results as JSON
- `fcheck --literals` always prints full text literal inventories (not affected by `--list`)

## Output Formatting

- In file-level SVG edge rendering, when source/target are in adjacent columns at the same level:
  - render a straight line only when the source has exactly one outgoing edge,
  - otherwise render a single arch line,
  - and do not introduce elbow turns for this case.

- When displaying counts or other numbers `>= 1,000` in CLI output or documentation examples, use comma separators (e.g., `1,234`, `12,345`, `1,234,567`).
- When displaying file paths in CLI output, reports, or examples, always use paths relative to the effective analysis root (the input folder after applying `input.root`).
- When displaying source locations, always format as `relative_file_path:line_number` with no space after `:`.
- In ANSI-capable terminals, colorize the `filename:line_number` segment in blue while keeping directory prefixes uncolored.
- In ANSI-capable terminals, colorize right-side symbol names in orange (for example `"MyClass.myMethod"` or `"myVariable"` in issue details).
- In literals inventory text output, render string literals with Dart-style quote selection (single or double with minimal escaping), color `(1)` counts in gray, and color counts above `1` in yellow.
- Analyzer report output must be grouped by analyzer (not by status), and each analyzer block should include:
  - status icon on the left (`[✓]`, `[!]`, `[x]`, or `[-]` when disabled)
  - score percentage from `0%` to `100%` with threshold-based ANSI coloring on the right
  - header percentage numeric field must be fixed-width (`3` chars) before `%` for vertical alignment
  - one summary line
  - details list (except when `--list none` is active)
- Analyzer report block order must be:
  - first group: no-warning analyzers (`[✓]`) sorted by analyzer title ascending
  - second group: disabled analyzers (`[-]`) sorted by analyzer title ascending
  - third group: warning/failing analyzers (`[!]` and `[x]`) sorted by score descending, then analyzer title ascending

## Configuration

- Project-level config is defined in `.fcheck` and parsed by `lib/src/models/fcheck_config.dart`.
- `.fcheck` is loaded from the CLI input directory (`--input`, or current directory by default).
- `input.root` (if set) is resolved relative to the `.fcheck` directory and becomes the effective analysis root.
- `input.exclude` contributes glob exclusions, and CLI `--exclude` adds additional patterns on top.
- Analyzer toggles support:
  - `analyzers.default`: `on`/`off` (`true`/`false` also accepted)
  - `analyzers.enabled`: explicit opt-in list
  - `analyzers.disabled`: explicit opt-out list
  - `analyzers.options.duplicate_code`: threshold/size tuning for duplicate-code analysis
  - `analyzers.options.code_size`: LOC threshold tuning (`max_file_loc`, `max_class_loc`, `max_function_loc`, `max_method_loc`)
- Supported analyzer keys: `code_size`, `one_class_per_file`, `hardcoded_strings`, `magic_numbers`, `source_sorting`, `layers`, `secrets`, `dead_code`, `duplicate_code`, `documentation`, `localization`.
- Legacy `ignores.<analyzer>: true` remains supported as a compatibility alias for disabling analyzers.
- Precedence: built-in defaults < `.fcheck` < CLI flags.
- File-level ignore: `// ignore: fcheck_<domain>` at the top of a Dart file.
- Node-level ignore: `// ignore: fcheck_<domain>` on the same line as a literal for AST-based rules.
- Default excluded directories and hidden folders are defined in `FileUtils.defaultExcludedDirs`.
