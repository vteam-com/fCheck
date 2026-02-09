# RULES.md

This file provides guidance on the expectation for contributing to the `fcheck` project and the this repository.

## Project Overview

`fcheck` is a Dart CLI tool for analyzing Flutter and Dart project quality. It provides metrics and domain-specific checks including:

- Hardcoded string detection
- Magic number detection
- Dead code detection
- Secret/PII scanning
- Flutter widget member sorting
- Layer dependency analysis and visualization
- Project metrics (files, folders, LOC, comment ratios)

## Domain Rules (Start Here)

- `RULES_HARDCODED_STRINGS.md` for string literal detection rules.
- `RULES_MAGIC_NUMBERS.md` for numeric literal detection rules.
- `RULES_SECRETS.md` for secret/PII detection rules.
- `RULES_SORTING.md` for Flutter widget member ordering rules.
- `RULES_LAYERS.md` for dependency graph and layer analysis rules.

## Analyzer Architecture

- `AnalyzeFolder` in `lib/fcheck.dart` wires the CLI analysis pipeline.
- `AnalyzerRunner` in `lib/src/analyzer_runner/analyzer_runner.dart` parses each Dart file once and runs delegates.
- Per-domain delegates live in `lib/src/analyzer_runner/analyzer_delegates.dart`.
- File discovery and default exclusions are centralized in `lib/src/input_output/file_utils.dart`.
- Ignore directives are implemented in `lib/src/models/ignore_config.dart`.
- **Project metadata contract:** `AnalyzeFolder` is the single entry point for analysis and is the only component that reads `pubspec.yaml`.
- `AnalyzeFolder` reads `pubspec.yaml` once, derives `projectType`, `projectName`, `version`, and `packageName`, and passes these values into delegates/analyzers.
- Domain analyzers must **not** read `pubspec.yaml` or rescan for project roots; they should rely on values provided by `AnalyzeFolder`.

## Repository Structure

- `lib/` main source code
- `lib/src/analyzers/` domain analyzers
- `lib/src/analyzer_runner/` unified analysis runner and delegates
- `lib/src/input_output/` file system scanning and output helpers
- `lib/src/models/` shared data models and ignore configuration
- `lib/src/metrics/` project and file metrics
- `lib/src/graphs/` graph exporters (SVG, Mermaid, PlantUML)
- `test/` unit tests
- `example/` example project for testing
- `tool/` development scripts

## Development Commands

- `dart pub get` install dependencies
- `dart run ./bin/fcheck.dart` run the tool
- `dart format .` format all Dart files
- `dart fix --apply` apply automated fixes
- `flutter analyze lib test` run static analysis
- `flutter test` run all tests
- `./tool/check.sh` run format, analyze, tests, and fcheck on the example

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
- `lib/src/analyzers/sorted/sort_members.dart`
- `lib/src/analyzers/sorted/sort_issue.dart`
- `lib/src/analyzers/layers/layers_analyzer.dart`

## Test Structure

- `test/hardcoded_string_analyzer_test.dart`
- `test/magic_number_analyzer_test.dart`
- `test/layers_analyzer_test.dart`
- `test/project_metrics_test.dart`
- `test/cli_test.dart`

## Test Coverage Rules

- Maintain overall project code coverage at `>= 80%`.
- Do not merge changes that reduce overall coverage.
- Add or update tests for every behavior change (new feature, bug fix, or rule change).
- For new/modified files in `lib/src/analyzers/` and `lib/src/analyzer_runner/`, add direct unit tests that cover:
  - happy path behavior
  - guard/skip paths
  - serialization/formatting paths (`toJson()`, `toString()`) for issue models
- Prefer focused unit tests for small models/utilities and integration tests for CLI/report behavior.
- Run the full test suite before merging: `dart test` (or `flutter test` if required by the task).
- When validating coverage locally, generate coverage data with:
  - `dart test --coverage=coverage`

## Usage Patterns

- `fcheck` analyze current directory
- `fcheck /path/to/project` analyze specific project
- `fcheck --fix` auto-fix sorting issues
- `fcheck --exclude "**/generated/**"` exclude glob patterns
- `fcheck --excluded` list excluded files and directories
- `fcheck --svg` generate SVG dependency graph
- `fcheck --mermaid` generate Mermaid graph
- `fcheck --plantuml` generate PlantUML graph
- `fcheck --json` output results as JSON

## Output Formatting

- When displaying counts or other numbers `>= 1,000` in CLI output or documentation examples, use comma separators (e.g., `1,234`, `12,345`, `1,234,567`).

## Configuration

- Project-level config is defined in `.fcheck` and parsed by `lib/src/models/fcheck_config.dart`.
- `.fcheck` is loaded from the CLI input directory (`--input`, or current directory by default).
- `input.root` (if set) is resolved relative to the `.fcheck` directory and becomes the effective analysis root.
- `input.exclude` contributes glob exclusions, and CLI `--exclude` adds additional patterns on top.
- Analyzer toggles support:
  - `analyzers.default`: `on`/`off` (`true`/`false` also accepted)
  - `analyzers.enabled`: explicit opt-in list
  - `analyzers.disabled`: explicit opt-out list
- Supported analyzer keys: `one_class_per_file`, `hardcoded_strings`, `magic_numbers`, `source_sorting`, `layers`, `secrets`, `dead_code`.
- Legacy `ignores.<analyzer>: true` remains supported as a compatibility alias for disabling analyzers.
- Precedence: built-in defaults < `.fcheck` < CLI flags.
- File-level ignore: `// ignore: fcheck_<domain>` at the top of a Dart file.
- Node-level ignore: `// ignore: fcheck_<domain>` on the same line as a literal for AST-based rules.
- Default excluded directories and hidden folders are defined in `FileUtils.defaultExcludedDirs`.
