# RULES.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart CLI tool called `fcheck` designed for analyzing Flutter and Dart project quality. It provides comprehensive metrics and quality checks for codebases, including:

- Project overview (files, folders, lines of code, comment ratios)
- Code quality checks (one class per file compliance, member sorting)
- Issue detection (hardcoded strings, magic numbers, layer violations)
- Visualizations (SVG, Mermaid, and PlantUML dependency graphs)

## Key Technologies

- Dart SDK >= 3.0.0
- Uses the `analyzer` package for code analysis
- Uses `args` for command-line argument parsing
- Uses `glob` for file pattern matching
- Uses `path` for path operations
- Uses `yaml` for YAML parsing

## Repository Structure

- `lib/` - Main source code
- `lib/src/` - Source code organized by functionality:
  - `metrics/` - Project and file metrics calculation
  - `hardcoded_strings/` - Hardcoded string detection
  - `layers/` - Layer architecture analysis
  - `magic_numbers/` - Magic number detection
  - `sort/` - Member sorting analysis
  - `config/` - Configuration handling
  - `models/` - Data models
- `test/` - Unit tests
- `example/` - Example project for testing
- `tool/` - Development scripts

## Development Commands

- `dart pub get` - Install dependencies
- `dart pub global activate fcheck` - Install globally for use
- `dart run ./bin/fcheck.dart` - Run the tool
- `flutter test` - Run all tests
- `flutter test --reporter=compact` - Run tests with compact reporter
- `dart format .` - Format all Dart files
- `dart fix --apply` - Apply automated fixes
- `flutter analyze lib test` - Run static analysis
- `./tool/check.sh` - Run full check (format, analyze, test, and fcheck on example)

## Key Files

- `bin/fcheck.dart` - Entry point for the CLI tool
- `lib/fcheck.dart` - Main library file
- `lib/src/metrics/project_metrics.dart` - Project metrics calculation
- `lib/src/layers/layers_analyzer.dart` - Layer architecture analyzer
- `lib/src/hardcoded_strings/hardcoded_string_analyzer.dart` - Hardcoded string analyzer
- `lib/src/magic_numbers/magic_number_analyzer.dart` - Magic number analyzer
- `lib/src/sort/sort_analyzer.dart` - Member sorting analyzer

## Test Structure

Tests are organized by feature:

- `test/layers_analyzer_test.dart` - Tests for layer analysis
- `test/magic_number_analyzer_test.dart` - Tests for magic number detection
- `test/hardcoded_string_analyzer_test.dart` - Tests for hardcoded string detection
- `test/sort_analyzer_test.dart` - Tests for member sorting
- `test/project_metrics_test.dart` - Tests for project metrics
- `test/file_metrics_test.dart` - Tests for file metrics

## Usage Patterns

The tool supports various command-line options:

- `fcheck` - Analyze current directory
- `fcheck /path/to/project` - Analyze specific project
- `fcheck --svg` - Generate SVG dependency graph
- `fcheck --svgfolder` - Generate folder-based visualization
- `fcheck --json` - Output as JSON
- `fcheck --fix` - Auto-fix sorting issues
- `fcheck --help` - Show help
- `fcheck --version` - Show version

## Configuration

- `.fcheck` file in project root for global ignore settings
- Per-file ignore comments using `// ignore: fcheck_*` at the top of Dart files
