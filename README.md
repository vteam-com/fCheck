# fCheck

fCheck provides fast local quality analysis for Flutter and Dart projects with 0-100% compliance scoring. Single analysis pass covering architecture, maintainability, and safety issues beyond standard linting, with deterministic CLI/JSON reports for CI/CD pipelines and fully private execution: it does not require any AI service, no network calls are needed, and no source code is sent to external services.

## Why fCheck

- Single local run for multiple quality domains
- Deterministic output for CI and code review
- 100% private local execution (no AI service, no code sent externally)
- Console, JSON, and diagram outputs
- Includes test discovery metrics (`hasTests`, `testDirectories`, `testFiles`, `testDartFiles`, `testCases`)
- Works as a CLI tool
- Works as a Dart package in your own app/tooling

## Checks Included

- `code_size`
- `dead_code`
- `documentation`
- `duplicate_code`
- `hardcoded_strings`
- `layers`
- `localization`
- `magic_numbers`
- `one_class_per_file`
- `secrets`
- `source_sorting`

Detailed behavior and edge cases are documented in `RULES*.md`.

### Hardcoded strings: how it works

- Flutter projects use opt-out hardcoded-string detection: most string literals are analyzed by default, then technical, diagnostic, declaration, and framework-specific cases are excluded.
- If project localization is `OFF`, hardcoded-strings runs in passive mode (`[-]`), reports only the total count, and does not affect compliance score/focus area.
- If project localization is `OFF`, hardcoded-string findings are also excluded from SVG warning tint/counters (`fcheck_files.svg`, `fcheck_folders.svg`, `fcheck_loc.svg`).
- If localization is `ON`, hardcoded-strings is active and reports detailed issue entries.

- Flutter projects: fcheck scans most string literals, then skips known non-user-facing categories such as imports, annotations, const declarations, explicit typed `String` declarations used as reusable identifiers/constants, localization calls, generated files, logger/debug output, `throw` diagnostics, `toString()` bodies, technical strings, paths, URLs, query strings, lookup keys, and similar infrastructure values.
- Dart projects: fcheck keeps a narrower focus and primarily reports strings passed to `print()`.
- Localization-aware behavior still applies:
  - localization `OFF`: summary count only, passive mode
  - localization `ON`: detailed issue list

### Hardcoded strings: what to do with findings

- Move repeated UI copy into named constants when the text is internal to the codebase and not part of a localization workflow.
- Move user-facing product text into your localization system (`.arb`, `AppLocalizations`, or equivalent) when the app already supports localization or is expected to.
- Keep technical strings technical: paths, route fragments, query strings, identifiers, analytics keys, backend field names, logger text, exception diagnostics, and reusable typed declarations should remain non-user-facing and are increasingly auto-excluded by fcheck.
- Prefer a named constant even when localization is not needed. A constant gives one source of truth, reduces typo drift, simplifies refactors, and makes intent obvious during review.

### Hardcoded strings: industry best practice

- Avoid scattering raw literals through business logic, widgets, services, and backend adapters.
- Use `const` where possible for stable reusable values.
- Use typed named declarations for reusable non-localized identifiers.
- Use localization for customer-facing copy instead of embedding text inline.
- Treat every new hardcoded-string finding as a clean-code prompt: either extract it, localize it, or explicitly justify and suppress it.

### Hardcoded strings: opt out and suppression

- Disable the analyzer globally in `.fcheck`:

```yaml
analyzers:
  disabled:
    - hardcoded_strings
```

- Use opt-in mode and omit `hardcoded_strings`:

```yaml
analyzers:
  default: off
  enabled:
    - magic_numbers
    - secrets
```

- Suppress a specific source line or file only when the literal is intentionally technical/non-user-facing:

```dart
// ignore: fcheck_hardcoded_strings
final debugLabel = 'ContactsNotifier';
```

Use suppression sparingly. The preferred path is to extract or localize the string rather than silence the rule.

### Localization: how it works

- fCheck automatically detects when a project uses Flutter localization and analyzes translation completeness.
- Scans for ARB files (`.arb`) in `lib/l10n/` directory and analyzes translation coverage across all supported languages.
- Falls back to any project ARB files when `lib/l10n/` has none, and prefers English as the base language when available.
- Identifies missing translations by comparing each language file against the base language.
- Reports coverage percentage and missing translation count for each incomplete language.
- Supports common ARB file naming patterns: `app_en.arb`, `messages_es.arb`, `l10n_fr.arb`, etc.
- Supports locale variants such as `app_pt_BR.arb` and `app_zh_Hans.arb`.
- Handles metadata keys (starting with `@` or `@@`) appropriately by excluding them from translation analysis.
- Respects `@key.description` hints such as `DO NOT TRANSLATE`, `ignore`, or `reviewed` in either the base ARB or translated ARB and excludes those keys from coverage checks.
- Treats empty strings, untranslated copies, and placeholder mismatches as incomplete translations.
- Warns on duplicate top-level ARB keys so overwritten entries do not go unnoticed.
- Warns when an English base-locale key exists in ARB but is never referenced from app Dart source under `lib/`, helping catch orphan/dead strings.

### Localization: what it reports

For each language with incomplete translations:

- Language code (e.g., 'es', 'fr', 'de')
- Language display name (e.g., 'Spanish', 'French', 'German')
- Number of missing translations
- Total number of strings in base language
- Coverage percentage (0.0% to 100.0%)

### Localization: best practices

- Ensure all user-facing strings are translated before releasing new features.
- Use descriptive keys in ARB files to maintain translation context.
- Regularly review translation completeness, especially when adding new features.
- Consider using translation management tools for large-scale projects.
- Test your app with different locales to ensure proper fallback behavior.

### Localization false positives

Use the localization guidance from `fcheck --help-ignore` to handle findings that are intentional or project-specific:

- Intentional identical text or brand names: add ARB metadata such as `@key.description: "reviewed"` or `DO NOT TRANSLATE`
- Expected non-translations: use `ignore` in the key description when you want fCheck to skip the entry
- Duplicate keys: fix the ARB file so each top-level key appears only once; the analyzer warns because later entries overwrite earlier ones
- Placeholder drift or empty strings: correct the translation, do not suppress unless the value is intentionally exempted
- Unused English keys: remove orphan ARB entries that are no longer referenced from app code, or wire the key back into the UI if it is still needed

Example:

```arb
"anapayTitle": "anapay",
"@anapayTitle": {
  "description": "reviewed"
}
```

Code-size LOC note:

- Localization Dart files are excluded from LOC code-size evaluation (`lib/l10n/**`, `app_localization.dart`, `app_localizations.dart`, and generated locale variants such as `app_localizations_<locale>.dart`).

## Install

### Option 1: Global CLI

```bash
dart pub global activate fcheck
fcheck .
```

### Option 2: Project Dev Dependency

```bash
dart pub add fcheck -d
dart run fcheck .
```

### Option 3: Use as a Dart package in your app/tool

```bash
dart pub add fcheck
```

```dart
import 'dart:io';
import 'package:fcheck/fcheck.dart';

void main() {
  final metrics = AnalyzeFolder(Directory('.')).analyze();
  print('Score: ${metrics.complianceScore}%');
}
```

## Quick Start (CLI)

```bash
# Analyze current folder
fcheck .

# Analyze another folder
fcheck ../my_app
fcheck --input ../my_app

# JSON output
fcheck --json

# Full list output
fcheck --list full

# Generate diagrams
fcheck --svg --mermaid --plantuml

# Auto-fix source sorting issues (class members + import directives)
fcheck --fix
```

### What `--fix` does

- Rewrites Dart source files in place.
- Applies only `source_sorting` auto-fixes:
  - Reorders Flutter widget class members to match fCheck sorting rules.
  - Reorders `import` directives with these groups:
    - `dart:*`
    - all `package:*` imports (including `flutter` and your own package), alphabetical
    - other absolute URIs (for example `http:`)
    - relative imports
  - Inserts one blank line between import groups.
  - Rewrites relative imports that resolve under `lib/` to `package:<this-package>/...`.
- Does not auto-fix other analyzers; it only reports their issues.

## Sample Bash Output

```bash
$ fcheck .
↓------------------------------ fCheck 1.1.0 -------------------------------↓
Input              : /path/to/project
Dart Project       : my-cool-app (version: 9.0.0)
Platforms          : [✓Android] [✓iOS]  [✓MacOS] [✓Windows] [✓Linux]   [✓Web]
--------------------------------- Dashboard ---------------------------------
Dependencies       :               5  |  DevDependencies    :               2
Folders            :              21  |  Classes            :              66
Files              :             120  |  Widgets: Stateful  :              26
Excluded Files     :              39  |  Widgets: Stateless :              40
Dart Files         :              91  |  Methods            :             357
Lines of Code      :       15.0 KLoC  |  Functions          :             179
Comments           :     2,145 (14%)  |
----------------------------------- Tests -----------------------------------
Test Dart Files    :              35  |  Touched Dart Files :         41 (45%)
Test Cases         :             392  |  Touched Classes    :         31 (47%)
                                      |  Touched Methods    :        144 (40%)
                                      |  Touched Functions  :         73 (41%)
--------------------------------- Literals ----------------------------------
Strings            : 1,203 (64% dupe)
Numbers            :   842 (74 hardcoded)
--------------------------------- Analyzers ---------------------------------
[✓] Checks bypassed
[✓] Code size
[✓] Dead code
[✓] Documentation
[✓] Duplicate code
[✓] Hardcoded strings
[✓] Layers architecture
[✓] Localization  : OFF
[✓] Magic numbers
[✓] One class per file
[✓] Secrets
[✓] Source sorting
--------------------------------- Scorecard ---------------------------------
Total Score        : 100%
Invest Next        : Maintain this level by enforcing fcheck in CI on every pull request.
↑------------------------ fCheck completed (1.73s) -------------------------↑
```

The `Touched ...` rows are a static inventory derived from test-file imports plus transitive project-local Dart dependencies. They indicate source reached by test dependency graphs, not code coverage.

## Configuration (`.fcheck`)

Create `.fcheck` in the input directory (`--input`) or current directory.

```yaml
input:
  root: app
  exclude:
    - "**/generated/**"
    - "**/*.g.dart"

analyzers:
  default: on
  disabled:
    - hardcoded_strings
    - source_sorting
  options:
    duplicate_code:
      similarity_threshold: 0.85 # 0.0..1.0
      min_tokens: 20
      min_non_empty_lines: 10
    code_size:
      max_file_loc: 900
      max_class_loc: 800
      max_function_loc: 700
      max_method_loc: 500
```

Notes:

- `analyzers.default` accepts `on|off` and `true|false`
- Opt-in mode:

```yaml
analyzers:
  default: off
  enabled:
    - magic_numbers
    - secrets
```

- Config precedence: built-in defaults < `.fcheck` < CLI flags
- `input.root` is resolved relative to the `.fcheck` file location
- `--exclude` adds patterns on top of `.fcheck` `input.exclude`

## Ignore Directives

Use top-of-file or line-level ignore directives:

```dart
// ignore: fcheck_dead_code
// ignore: fcheck_documentation
// ignore: fcheck_duplicate_code
// ignore: fcheck_hardcoded_strings
// ignore_for_file: avoid_hardcoded_strings_in_widgets
// ignore: fcheck_layers
// ignore: fcheck_magic_numbers
// ignore: fcheck_one_class_per_file
// ignore: fcheck_secrets
```

CLI help to guide you on how to exclude some of checks

```bash
fcheck --help-ignore
```

Dead-code note:

- `// ignore: fcheck_dead_code` suppresses dead-code findings for that file's declarations, while keeping its dependencies/usages in global dead-code analysis.
- Dead-code usage tracking includes property-style getter/setter access and operator usage (`+`, `-`, `[]`, etc.) inferred from expression syntax.
- Functions/methods annotated with `@Preview` (including prefixed forms such as `@ui.Preview`) are treated as externally used and are not reported as dead functions.

## Visual Outputs

Adjacent file-level SVG routing rule for nodes on the same row in adjacent columns:

- If the source node has exactly one outgoing edge, the edge is rendered as a straight line.
- If the source node has multiple outgoing edges, the same-row adjacent edge is rendered as a single arch (no elbows).

```bash
fcheck --svg          # shortcut: fcheck_files.svg + fcheck_folders.svg + fcheck_loc.svg
fcheck --svg-files    # fcheck_files.svg
fcheck --svg-folders  # fcheck_folders.svg
fcheck --svg-loc      # fcheck_loc.svg
fcheck --mermaid      # fcheck.mmd
fcheck --plantuml     # fcheck.puml

# Custom output base directory
fcheck --svg --mermaid --plantuml --output ./reports/fcheck

# Per-artifact file overrides
fcheck --svg --output-svg-files ./artifacts/graph/files.svg
fcheck --svg-folders --output-svg-folders ./artifacts/graph/folders.svg
fcheck --svg-loc --output-svg-loc ./artifacts/graph/loc.svg
fcheck --mermaid --output-mermaid ./artifacts/graph/fcheck.mmd
fcheck --plantuml --output-plantuml ./artifacts/graph/fcheck.puml
```

### Layers Files diagram

![fcheck layers files diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_files.svg)

### Layers Folder diagram

![fcheck Layer folders diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_folders.svg)

Orange upward dependencies in `fcheck_folders.svg` are rendered from the final visual direction. Folder-level upward edges are also emitted in CLI report output as layers warnings (`wrongFolderLayer`) with the source Dart file path. File-level upward edges on the right lane stay orange even inside folder cycles so the culprit consuming files remain easy to spot.

Warning/error-highlighted file and folder nodes in layers SVGs now use a softer transparent gradient tint (instead of opaque flat fills) to preserve node text/details readability.

### Code size diagram

![fcheck code size diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_loc.svg)

`fcheck_loc.svg` uses a unified treemap hierarchy:
`Folders > Files > Classes > Functions`.

Warning highlighting in `fcheck_loc.svg`:

- Artifacts with analyzer findings are tinted on a red transparency spectrum
  (low warnings => light pink, high warnings => stronger red).
- Dead artifacts are treated as maximum severity tint.
- SVG tooltips include warning counts and sampled issue details for each
  affected file/class/function tile.

## Exclusions

```bash
# Add custom excludes
fcheck --exclude "**/generated/**" --exclude "**/*.g.dart"

# Inspect excluded items
fcheck --excluded
fcheck --excluded --json

# Inspect ignore/suppression inventory (.fcheck + Dart directives)
fcheck --ignores
fcheck --ignores --json

# Inspect literals inventory only
fcheck --literals
fcheck --literals --json
```

`--ignores` groups results by suppression type (`exclude`, analyzer skips, and Dart comment directive type) so cleanup work can be prioritized.
`--literals` full list text output od all the literals in your project.

Default exclusion behavior includes hidden folders and common non-analysis directories (`.git`, `.dart_tool`, `build`, `example`, `test`, `integration_test`, platform folders, etc.).

Generated Dart files ending with `*.g.dart` are analyzed for dependency/usage flow, but non-actionable checks are suppressed (for example code size, one-class-per-file, dead-code declarations, hardcoded strings, magic numbers, sorting, duplicate code, and documentation).

## CI Example (GitHub Actions)

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  quality:
    name: Build, test, and self-check (100%)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: ./tool/generate_version.sh
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze lib test --no-pub
      - run: dart test --reporter=compact
      - run: dart run ./bin/fcheck.dart --json --exclude "**/example" . > fcheck-report.json
      - run: |
          score="$(grep -oE '"complianceScore"[[:space:]]*:[[:space:]]*[0-9]+([.][0-9]+)?' fcheck-report.json | head -n1 | sed -E 's/.*:[[:space:]]*//')"
          score_int="$(awk "BEGIN { printf \"%d\", ${score} }")"
          test "$score_int" -eq 100
      - uses: actions/upload-artifact@v4
        with:
          name: fcheck-report
          path: fcheck-report.json
```

This repository already includes this workflow at `.github/workflows/ci.yml`.
The CI gate fails unless fcheck's self-analysis score is exactly `100%`.

## License

MIT
