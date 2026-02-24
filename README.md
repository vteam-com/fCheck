# fCheck

Fast local quality checks for Flutter and Dart projects.

fCheck runs one deterministic analysis pass and reports architecture, maintainability, and safety issues that default lints usually do not cover.

## Why fCheck

- Single local run for multiple quality domains
- Deterministic output for CI and code review
- No network calls required
- Console, JSON, and diagram outputs
- Works as both:
  - CLI tool
  - Dart package in your own app/tooling

## Checks Included

- `code_size`
- `dead_code`
- `documentation`
- `duplicate_code`
- `hardcoded_strings`
- `layers`
- `magic_numbers`
- `one_class_per_file`
- `secrets`
- `source_sorting`

Detailed behavior and edge cases are documented in `RULES*.md`.

Hardcoded-strings note:
- If project localization is `OFF`, hardcoded-strings runs in passive mode (`[-]`), reports only the total count, and does not affect compliance score/focus area.
- If localization is `ON`, hardcoded-strings is active and reports detailed issue entries.

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
fcheck --svg --svgfolder --svgsize --mermaid --plantuml

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

If installed as a dev dependency, prefix commands with `dart run`.

## Sample Bash Output

```bash
$ fcheck .
↓------------------------------ fCheck 0.9.17 ------------------------------↓
Input              : /path/to/project
Dart Project       : fcheck (version: 0.9.17)
--------------------------------- Dashboard ---------------------------------
Folders            :              21  |  Dependency         :               5
Files              :             120  |  DevDependency      :               2
Excluded Files     :              39  |  Classes            :              66
Dart Files         :              91  |  Methods            :             357
Lines of Code      :          15,022  |  Functions          :             179
Comments           :     (14%) 2,145  |  Localization       :             OFF
--------------------------------- Analyzers ---------------------------------
[✓] Checks bypassed
[✓] Code size
[✓] Dead code
[✓] Documentation
[✓] Duplicate code
[✓] Layers architecture
[✓] Magic numbers
[✓] One class per file
[✓] Secrets
[✓] Source sorting
[-] Hardcoded strings
0 hardcoded strings detected (localization OFF).
--------------------------------- Scorecard ---------------------------------
Total Score        : 100%
Invest Next        : Maintain this level by enforcing fcheck in CI on every pull request.
↑------------------------ fCheck completed (1.73s) -------------------------↑
```

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

Legacy compatibility is supported:

```yaml
ignores:
  hardcoded_strings: true
  layers: true
  magic_numbers: true
```

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

For generated guidance:

```bash
fcheck --help-ignore
```

Dead-code note:
- `// ignore: fcheck_dead_code` suppresses dead-code findings for that file's declarations, while keeping its dependencies/usages in global dead-code analysis.
- Dead-code usage tracking includes property-style getter/setter access and operator usage (`+`, `-`, `[]`, etc.) inferred from expression syntax.

## Visual Outputs

```bash
fcheck --svg        # fcheck_files.svg
fcheck --svgfolder  # fcheck_folders.svg
fcheck --svgsize    # fcheck_loc.svg
fcheck --mermaid    # fcheck.mmd
fcheck --plantuml   # fcheck.puml
```
###  Layers Files diagram:

![fcheck layers files diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_files.svg)

### Layers Folder diagram:

![fcheck Layer folders diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_folders.svg)

Orange upward folder dependencies in `fcheck_folders.svg` are also emitted in CLI report output as layers warnings (`wrongFolderLayer`) with the source Dart file path.

### Code size diagram:

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
```

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
      - run: flutter test --reporter=compact --no-pub
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

## Contributing

1. Fork the repo
2. Create a branch
3. Implement changes
4. Run `./tool/check.sh`
5. Open a pull request

## License

MIT
