# Rule: Code Size

## Overview

Collects non-empty LOC (lines of code) across files, classes, functions, and
methods, then evaluates oversized source code entries against configured LOC
thresholds.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Measures

- **File entries**: per-file non-empty LOC.
- **Class entries**: non-empty LOC for each class declaration.
- **Function entries**: non-empty LOC for top-level functions.
- **Method entries**: non-empty LOC for methods and constructors.

## How It Works

- `CodeSizeDelegate` visits parsed AST nodes and records class/function/method
  entries with:
  - `filePath`
  - `startLine` / `endLine`
  - non-empty `linesOfCode`
- File-level entries are added from `FileMetrics` so the report and SVG can
  show file totals.
- Duplicate entries are de-duplicated by `stableId`.

## Threshold Configuration

Thresholds are configurable in `.fcheck`:

```yaml
analyzers:
  options:
    code_size:
      max_file_loc: 900
      max_class_loc: 800
      max_function_loc: 700
      max_method_loc: 500
```

- Defaults are shown above.
- All option values must be positive integers.
- Missing values fall back to defaults.

## Scoring Integration

Code size is a scored compliance domain with key `code_size`.

- Each entry is compared to its corresponding threshold by kind:
  - file -> `max_file_loc`
  - class -> `max_class_loc`
  - function -> `max_function_loc`
  - method -> `max_method_loc`
- An entry contributes to code-size issues when `linesOfCode > threshold`.
- Per-entry overage ratio: `(linesOfCode - threshold) / threshold`.
- Final score model:
  - `score = clamp(1 - (sum(overageRatio for violating entries) / totalEntries), 0, 1)`
- Issue count is total violating entries across all kinds.

## Skips / Limits

- Files with parse errors do not contribute class/function/method entries.
- Entries with `linesOfCode <= 0` are ignored.
- There is currently no dedicated `// ignore: fcheck_code_size` directive.

## Output

- Included in `ProjectMetrics.toJson()` under:
  - `codeSize.thresholds`
  - `codeSize.artifacts`
  - `codeSize.files`
  - `codeSize.classes`
  - `codeSize.callables`
- Included in analyzer breakdown as `code_size`.
- CLI analyzer section groups violations by kind:
  - `Files`
  - `Classes`
  - `Functions`
  - `Methods`
- Used by `--svgsize` to generate `fcheck_code_size.svg`.

## Related Files

- `lib/src/analyzers/code_size/code_size_delegate.dart`
- `lib/src/analyzers/code_size/code_size_artifact.dart`
- `lib/src/analyzers/code_size/code_size_file_data.dart`
- `lib/src/analyzers/code_size/code_size_outlier_utils.dart`
- `lib/fcheck.dart`
- `lib/src/analyzers/metrics/metrics_analyzer.dart`
- `bin/console_output.dart`
- `lib/src/graphs/export_svg_code_size.dart`
