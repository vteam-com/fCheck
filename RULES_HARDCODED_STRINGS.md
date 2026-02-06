# Rule for Hardcoded Strings Analysis

## Overview

There are two hardcoded-string checks in this repo:

- A general AST analyzer used by the CLI (`HardcodedStringAnalyzer`).
- A widget-focused `custom_lint` rule (`HardcodedStringLintRule`).

This document covers both, so a new contributor understands when each applies and how they differ.

## Project-Type Focus

- Flutter app projects: prioritize widget output strings and ignore `print()` / `logger()` / debug output.
- Pure Dart projects: prioritize `print()` output strings and ignore logger/debug output.

### How Focus Is Determined

- The CLI detects Flutter projects by checking for a `flutter` dependency in `pubspec.yaml` **once** in `AnalyzeFolder`.
- The hardcoded-strings analyzer receives the precomputed focus mode from the top-level entry point (see `RULES.md` for the project metadata contract).
- Flutter projects use a widget-output-only filter (heuristic, see below).
- Non-Flutter projects use a print-only filter.

## CLI Analyzer (General Purpose)

### What It Flags (CLI)

- Any `SimpleStringLiteral` that matches the focus mode and is not excluded by the skip rules.

### Skips (CLI)

- Empty strings.
- Strings in import/export/part/library directives.
- Strings in annotations.
- Map keys (but not map values).
- Strings in const declarations or const fields.
- Strings in `AppLocalizations` calls.
- Strings used to build `RegExp`.
- Strings in `Key`, `ValueKey`, or `ObjectKey` constructors.
- Strings used as index expressions.
- Nodes with `// ignore: fcheck_hardcoded_strings`.
- Files in `lib/l10n/` and generated `.g.dart` files.
- Files with a top-of-file `// ignore: fcheck_hardcoded_strings` directive.
- Parse errors do not prevent scanning; the AST may be partial.
- Flutter focus only: strings with length <= 2.
- Flutter focus only: strings on lines with `avoid_hardcoded_strings_in_widgets`, `hardcoded.string`, or `hardcoded.ok` ignore comments.
- Flutter focus only: strings passed to acceptable widget properties (e.g., `key`, `asset`, `fontFamily`, `semanticsLabel`).
- Flutter focus only: strings that look technical/config-like (URLs, emails, hex colors, file paths, identifiers).
- Flutter focus only: interpolation-only strings with no literal text (e.g., `"$secondsRemaining"` or `"${date.day}"`).

### How It Works

- `HardcodedStringAnalyzer` parses a file and runs `HardcodedStringVisitor`.
- The visitor walks the AST and emits `HardcodedStringIssue` for any literal that survives the skip rules.
- Focus mode details:
  - Flutter: only string literals used as constructor arguments inside widget/build contexts, and not inside print/logger calls.
  - Dart: only string literals passed to `print()`.
- In Flutter focus, a fallback scan looks for `Text("...")` literals in the raw source to catch parse-error or AST edge cases.

### Ignore and Exclusions

- File-level ignore uses `IgnoreConfig.hasIgnoreDirective` with `// ignore: fcheck_hardcoded_strings`.
- Node-level ignore uses `IgnoreConfig.isNodeIgnored` on the literal line.
- CLI `--exclude` patterns and `FileUtils` default exclusions apply in the unified runner.

### CLI Output

- `HardcodedStringIssue` contains `filePath`, `lineNumber`, `value`.

## Custom Lint Rule (Widget-Focused)

### What It Flags (Custom Lint)

- `StringLiteral` nodes passed directly to Flutter widget constructors.

### Core Eligibility Checks

- The string must be inside an `ArgumentList` for a widget constructor (`InstanceCreationExpression`).
- The constructed type must be a Flutter `Widget` (walks the class hierarchy for a widget base class).
- If the string is inside a function body between the literal and the argument list, it is ignored (e.g., callback bodies).

### Skips (Custom Lint)

- Empty strings.
- Strings with length <= 2.
- Map keys and index expressions.
- Strings passed to specific widget properties that are considered acceptable:
  - `semanticsLabel`, `excludeSemantics`, `restorationId`, `heroTag`, `key`, `debugLabel`,
  - `fontFamily`, `package`, `name`, `asset`,
  - `locale`, `materialType`, `clipBehavior`.
- Strings that look technical/config-like (matches any of the following patterns):
  - URLs: `^\w+://`
  - Email addresses: `^[\w\-\.]+@[\w\-\.]+\.\w+`
  - Hex colors: `^#[0-9A-Fa-f]{3,8}`
  - Numbers with optional units: `^\d+(\.\d+)?[a-zA-Z]*`
  - CONSTANT_CASE identifiers: `^[A-Z][A-Z0-9]*_[A-Z0-9_]*`
  - snake_case identifiers: `^[a-z]+_[a-z_]+`
  - File paths: `^/[\w/\-\.]*`
  - Dotted notation: `^\w+\.\w+`
  - File names with extensions: `^[\w\-]+\.[\w]+`
  - Identifiers with numbers/underscores/hyphens: `^[a-zA-Z0-9]*[_\-0-9]+[a-zA-Z0-9_\-]*`

### Lint Output

- Emits `LintCode` with name `avoid_hardcoded_strings_in_widgets` at WARNING severity.

## Related Files

- `lib/src/analyzers/hardcoded_strings/hardcoded_string_analyzer.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart`
- `lib/src/models/ignore_config.dart`

## Notes

- The CLI analyzer is general-purpose and not widget-specific unless focus mode is set to Flutter.
- The `custom_lint` rule is opt-in and focuses on widget constructor usage.
- Widget-only filtering in the CLI is heuristic (no type resolution). It relies on widget class inheritance (`StatelessWidget`, `StatefulWidget`, `State<...>`) and `build`-method/return-type hints.
