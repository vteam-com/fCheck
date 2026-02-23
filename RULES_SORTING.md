# Rule: Sorting

## Overview

This rule checks ordering of members inside Flutter widget classes and can optionally auto-fix the ordering. In fix mode, it also sorts import directives.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## Scope

- Only classes that extend `StatelessWidget`, `StatefulWidget`, `State`, or `State<...>`.
- Only Dart files discovered by `FileUtils.listDartFiles`, so hidden folders and default excluded directories are skipped.

## Ordering Rules

- Non-method members (constructors, fields, etc.) first, preserving their original order.
- Fields are grouped with their getters/setters and sorted alphabetically by field name.
- Lifecycle methods in this fixed order: `initState`, `dispose`, `didChangeDependencies`, `didUpdateWidget`, `build`.
- Public methods alphabetically.
- Private methods alphabetically.
- Member spacing is compacted to single-line separation (no extra blank lines between sorted members).
- In `--fix` mode, import directives are sorted by domain and ascending order:
  - `dart:*`
  - all `package:*` imports (including `flutter` and current package), alphabetical
  - other absolute URIs (for example `http:`)
  - relative imports
- In `--fix` mode, relative imports that resolve under `lib/` are rewritten to
  `package:<this-package>/...` before sorting.
- A single blank line is inserted between distinct import groups.

## How It Works

- `SourceSortDelegate` runs inside `AnalyzerRunner`, uses `ClassVisitor` to find target classes, then `MemberSorter` builds a sorted class body.
- It compares the sorted body to the original body with whitespace normalization.
- If different and `fix` is false, it emits `SourceSortIssue`.
- If `fix` is true (CLI `--fix`), it rewrites unsorted class bodies and reorders import directives.

## Ignores and Exclusions

- There is no per-file ignore directive for sorting.
- Generated Dart files ending with `*.g.dart` are skipped.
- CLI/project excludes and default directory excludes follow `RULES.md`.

## Output

- `SourceSortIssue` contains `filePath`, `className`, `lineNumber`, `description`.

## Related Files

- `lib/src/analyzers/sorted/sort_members.dart`
- `lib/src/models/class_visitor.dart`
- `lib/src/analyzers/sorted/sort_issue.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`

## Notes

- Sorting rewrites the class body and normalizes spacing between groups.
- Non-widget classes are ignored.
