# Rule: Code Size

## Overview

Collects non-empty LOC (lines of code) across files, classes, functions, and
methods, then highlights outlier concentration in reports and scoring.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Measures

- **File artifacts**: per-file non-empty LOC.
- **Class artifacts**: non-empty LOC for each class declaration.
- **Function artifacts**: non-empty LOC for top-level functions.
- **Method artifacts**: non-empty LOC for methods and constructors.

## How It Works

- `CodeSizeDelegate` visits parsed AST nodes and records class/function/method
  artifacts with:
  - `filePath`
  - `startLine` / `endLine`
  - non-empty `linesOfCode`
- File-level artifacts are added from `FileMetrics` so the report and SVG can
  show file totals.
- Duplicate artifacts are de-duplicated by `stableId`.

## Outlier Selection

Code-size outlier views use a stable top slice count:

- ratio: `10%` of group size
- min: `3`
- max: `10`
- a function or method with 200 or more lines will be be flagged


This is implemented by `codeSizeOutlierCount(...)`.

## Scoring Integration

Code size is a scored compliance domain with key `code_size`.

- It evaluates concentration for three groups:
  - files
  - classes
  - callables (functions + methods)
- For each group:
  - `concentration = topOutlierLoc / totalGroupLoc`
  - healthy threshold: `0.45`
  - penalties apply only above threshold
- Final `code_size` score is the normalized inverse of average group penalty.
- Issue count is the number of groups currently above the healthy threshold.

## Skips / Limits

- Files with parse errors do not contribute class/function/method artifacts.
- Artifacts with `linesOfCode <= 0` are ignored.
- There is currently no dedicated `// ignore: fcheck_code_size` directive.
- Functions or Methods with less than 50 lines will be spaired (we may change this min value in the future)

## Output

- Included in `ProjectMetrics.toJson()` under:
  - `codeSize.artifacts`
  - `codeSize.files`
  - `codeSize.classes`
  - `codeSize.callables`
- Included in analyzer breakdown as `code_size`.
- CLI analyzer section shows grouped outlier lists:
  - `Files`
  - `Classes`
  - `Functions/Methods`
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
