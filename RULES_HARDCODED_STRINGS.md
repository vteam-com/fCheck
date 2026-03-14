# Rule: Hardcoded Strings

## Overview

This repo includes the CLI hardcoded-strings analysis, implemented by
`HardcodedStringDelegate` and `HardcodedStringVisitor`.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## Release Communication

- This analyzer is intentionally broader in the current patch release.
- Flutter projects moved from an almost opt-in model to an opt-out model.
- Upgrading can reveal a large backlog of existing hardcoded strings that older versions did not report.
- This is intentional and is meant to improve project-local clean code quality by pushing teams toward reusable constants and proper localization.

## Project-Type Focus

- Flutter app projects: use opt-out detection for string literals and ignore `print()` / `logger()` / debug output plus the standard skip rules below.
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
- **Analyzer Mode**: Hardcoded strings is treated as **passive** (`[-]` in analyzer status).
- **Scoring**: The hardcoded-strings domain is excluded from compliance-score and focus-area selection.
- **CLI Output**: Only the total count is shown (summary line). Individual hardcoded string entries are not listed.

#### Localization is ON (Localized Project)

- **Stricter Checks**: Centralized string files are no longer automatically skipped.
- **Refactoring Encouraged**: User-facing strings that remain inline should be moved to the formal localization framework (`.arb` files) or extracted to a named constant when localization is not appropriate.
- **CLI Output**: A detailed list of all hardcoded string issues is shown in the "Lists" section.

### How Focus Is Determined

- The CLI detects Flutter projects by checking for a `flutter` dependency in `pubspec.yaml` **once** in `AnalyzeFolder`.
- The hardcoded-strings analyzer receives the precomputed focus mode from the top-level entry point (see `RULES.md` for the project metadata contract).
- Flutter projects use broad opt-out detection with heuristic skips for technical and diagnostic cases.
- Non-Flutter projects use a print-only filter.

## CLI Analyzer (General Purpose)

### What It Flags (CLI)

- Any string literal (`SimpleStringLiteral` or `StringInterpolation`) that matches
  the focus mode and is not excluded by the skip rules.
- In Flutter projects, this now means most string literals are included by
  default, not just direct widget constructor text.

### Why It Is Broad

- Inline literals spread product copy across widgets, services, adapters, and state code.
- That makes refactors harder, translation harder, review harder, and consistency weaker.
- The analyzer therefore prefers surfacing too much first, then carving out well-defined technical exceptions.

### Skips (CLI)

- Empty strings (`""` or `''`).
- Strings that do not contain any meaningful alphanumeric characters (e.g., `"---"` or `"***"`).
- Strings in import/export/part/library directives.
- Strings in annotations.
- Map keys (but not map values).
- Strings in const declarations or const fields.
- Strings in explicit typed `String` declarations (for example reusable fields or top-level variables).
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
- Flutter focus only: widget output strings with length <= 2.
- Flutter focus only: widget output strings on lines with any of these comment forms: `// ignore: avoid_hardcoded_strings_in_widgets`, `// ignore_for_file: avoid_hardcoded_strings_in_widgets`, `// ignore: hardcoded.string`, or `// hardcoded.ok`.
- Flutter focus only: widget output strings passed to acceptable widget properties (e.g., `key`, `asset`, `fontFamily`, `semanticsLabel`).
- Flutter focus only: strings that look technical/config-like (URLs, emails, hex colors, file paths, query strings, identifiers).
- Flutter focus only: interpolation-only strings with no literal text (e.g., `"$secondsRemaining"` or `"${date.day}"`).
- Flutter focus only: strings inside `print()` / `debugPrint()` / logger-style calls.
- Flutter focus only: strings inside thrown exceptions/errors.
- Flutter focus only: strings inside `toString()` implementations.
- Flutter focus only: strings used in equality comparisons such as status or sentinel checks.

### How It Works

- `HardcodedStringDelegate` uses the pre-parsed AST and runs `HardcodedStringVisitor`.
- The visitor walks the AST and emits `HardcodedStringIssue` for any literal that survives the skip rules.
- Focus mode details:
  - Flutter: opt-out detection for string literals, excluding print/logger/debug output and the documented skip cases.
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

## Recommended Cleanup

- If the string is customer-facing copy, localize it.
- If the string is reused internal copy or configuration, extract it to a named constant or typed declaration.
- If the string is technical and intentionally inline, prefer a narrowly scoped suppression only when the auto-skip rules do not already cover it.
- Avoid keeping literals inline just because they are short or currently used once. Reuse and intent are more important than size.

## Best Practices

- Prefer `const` for reusable stable values.
- Prefer named typed declarations over repeating literal values in multiple files.
- Prefer localization for visible UI text, error text shown to users, prompts, labels, and marketing/product copy.
- Avoid embedding literals in business logic because it weakens maintainability and makes later localization expensive.

## Related Files

- `lib/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart`
- `lib/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`
- `lib/src/analyzer_runner/analysis_file_context.dart`
- `lib/src/models/ignore_config.dart`

## Notes

- The CLI analyzer is general-purpose and not widget-specific unless focus mode is set to Dart `print()`.
- Flutter mode still applies extra heuristics for widget-specific false-positive reduction, but no longer requires widget constructor context before a string can be reported.
