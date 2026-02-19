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

# Auto-fix source sorting issues
fcheck --fix
```

If installed as a dev dependency, prefix commands with `dart run`.

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

## Visual Outputs

```bash
fcheck --svg        # layers.svg
fcheck --svgfolder  # layers_folders.svg
fcheck --svgsize    # fcheck_code_size.svg
fcheck --mermaid    # layers.mmd
fcheck --plantuml   # layers.puml
```
###  Layers Files diagram:

![fcheck layers files diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/layers.svg)

### Layers Folder diagram:

![fcheck Layer folders diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/layers_folders.svg)

### Code size diagram:

![fcheck code size diagram](https://raw.githubusercontent.com/vteam-com/fCheck/main/fcheck_code_size.svg)

## Exclusions

```bash
# Add custom excludes
fcheck --exclude "**/generated/**" --exclude "**/*.g.dart"

# Inspect excluded items
fcheck --excluded
fcheck --excluded --json
```

Default exclusion behavior includes hidden folders and common non-analysis directories (`.git`, `.dart_tool`, `build`, `example`, `test`, platform folders, etc.).

## CI Example (GitHub Actions)

```yaml
name: fcheck
on:
  pull_request:
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate fcheck
      - run: dart pub global run fcheck --json > fcheck-report.json
      - uses: actions/upload-artifact@v4
        with:
          name: fcheck-report
          path: fcheck-report.json
```

## Contributing

1. Fork the repo
2. Create a branch
3. Implement changes
4. Run `./tool/check.sh`
5. Open a pull request

## License

MIT
