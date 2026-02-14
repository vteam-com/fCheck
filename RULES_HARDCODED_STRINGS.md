# Rule: Hardcoded Strings

## Overview

This repo includes the CLI hardcoded-strings analysis, implemented by
`HardcodedStringDelegate` and `HardcodedStringVisitor`.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## Project-Type Focus

- Flutter app projects: prioritize widget output strings and ignore `print()` / `logger()` / debug output.
- Pure Dart projects: prioritize `print()` output strings and ignore logger/debug output.

## Localization Support

The analyzer intelligently adapts its rules based on whether the project uses a formal localization framework (e.g., Flutter `gen_l10n`).

### How Localization Is Detected

A project is considered to "use localization" if any of the following are true:

1. `l10n.yaml` exists in the project root.
2. Any `.arb` files exist within the project (commonly under `lib/l10n/`).
3. Any Dart file imports `package:flutter_gen/gen_l10n/app_localizations.dart`.

### Effect of Localization Settings

#### Localization is OFF (Non-Localized Project)

In non-localized projects, it is common to centralize user-facing strings in dedicated Dart files instead of using `.arb` keys.

- **Dedicated String Files**: Files ending in `strings.dart`, `constants.dart`, or `keys.dart` are recognized as "dedicated string repositories".
- **Skips**: All strings within dedicated string files are **skipped** and not flagged as hardcoded issues.
- **Static Final Permitted**: In these dedicated files, `static final String` fields are treated the same as `const` and are not flagged.
- **CLI Output**: Detected hardcoded strings are listed in the "Lists" section.

#### Localization is ON (Localized Project)

- **Stricter Checks**: Centralized string files are no longer automatically skipped.
- **Refactoring Encouraged**: Strings in `strings.dart` or `constants.dart` that are not `const` (e.g., `final` or direct literals) will be flagged to encourage moving them to the formal localization framework (`.arb` files).
- **CLI Output**: A detailed list of all hardcoded string issues is shown in the "Lists" section.

### How Focus Is Determined

- The CLI detects Flutter projects by checking for a `flutter` dependency in `pubspec.yaml` **once** in `AnalyzeFolder`.
- The hardcoded-strings analyzer receives the precomputed focus mode from the top-level entry point (see `RULES.md` for the project metadata contract).
- Flutter projects use a widget-output-only filter (heuristic, see below).
- Non-Flutter projects use a print-only filter.

## CLI Analyzer (General Purpose)

### What It Flags (CLI)

- Any string literal (`SimpleStringLiteral` or `StringInterpolation`) that matches
  the focus mode and is not excluded by the skip rules.

### Skips (CLI)

- Empty strings (`""` or `''`).
- Strings that do not contain any meaningful alphanumeric characters (e.g., `"---"` or `"***"`).
- Strings in import/export/part/library directives.
- Strings in annotations.
- Map keys (but not map values).
- Strings in const declarations or const fields.
- Strings in `static final` fields within "dedicated string files" (when localization is OFF).
- All strings in "dedicated string files" (when localization is OFF).
- Strings in `AppLocalizations` calls.
- Strings used to build `RegExp`.
- Strings in `Key`, `ValueKey`, or `ObjectKey` constructors.
- Strings used as index expressions.
- Nodes with `// ignore: fcheck_hardcoded_strings`.
- Files in `lib/l10n/` and generated `.g.dart` files.
- Files with a top-of-file `// ignore: fcheck_hardcoded_strings` directive.
- Files with a top-of-file `// ignore_for_file: avoid_hardcoded_strings_in_widgets` directive (third-party custom_lint).
- Parse errors do not prevent scanning; the AST may be partial.
- Flutter focus only: strings with length <= 2.
- Flutter focus only: strings on lines with any of these comment forms: `// ignore: avoid_hardcoded_strings_in_widgets`, `// ignore_for_file: avoid_hardcoded_strings_in_widgets`, `// ignore: hardcoded.string`, or `// hardcoded.ok`.
- Flutter focus only: strings passed to acceptable widget properties (e.g., `key`, `asset`, `fontFamily`, `semanticsLabel`).
- Flutter focus only: strings that look technical/config-like (URLs, emails, hex colors, file paths, identifiers).
- Flutter focus only: interpolation-only strings with no literal text (e.g., `"$secondsRemaining"` or `"${date.day}"`).

### How It Works

- `HardcodedStringDelegate` uses the pre-parsed AST and runs `HardcodedStringVisitor`.
- The visitor walks the AST and emits `HardcodedStringIssue` for any literal that survives the skip rules.
- Focus mode details:
  - Flutter: only string literals used as constructor arguments inside widget/build contexts, and not inside print/logger calls.
  - Dart: only string literals passed to `print()`.
- In Flutter focus, a fallback scan looks for `Text("...")` literals in the raw source to catch parse-error or AST edge cases.

### CLI Output

- `HardcodedStringIssue` contains `filePath`, `lineNumber`, `value`.

## Disable Options

- Global disable in `.fcheck`:
  - `analyzers.disabled: [hardcoded_strings]`
  - or opt-in mode with `analyzers.default: off` and omitting `hardcoded_strings` from `enabled`.
- Source-level suppression:
  - Line-level: `// ignore: fcheck_hardcoded_strings`
  - File-level: `// ignore: fcheck_hardcoded_strings` at the top of the file.

## Related Files

- `lib/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`
- `lib/src/analyzer_runner/analysis_file_context.dart`
- `lib/src/models/ignore_config.dart`

## Notes

- The CLI analyzer is general-purpose and not widget-specific unless focus mode is set to Flutter.
- Widget-only filtering in the CLI is heuristic (no type resolution). It relies on widget class inheritance (`StatelessWidget`, `StatefulWidget`, `State<...>`) and `build`-method/return-type hints.
