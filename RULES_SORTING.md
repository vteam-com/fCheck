# Rule: Sorting

## Overview

This rule checks ordering of members inside Flutter widget classes and can optionally auto-fix the ordering.

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
- A blank line is inserted between groups.

## How It Works

- `SourceSortDelegate` runs inside `AnalyzerRunner`, uses `ClassVisitor` to find target classes, then `MemberSorter` builds a sorted class body.
- It compares the sorted body to the original body with whitespace normalization.
- If different and `fix` is false, it emits `SourceSortIssue`.
- If `fix` is true (CLI `--fix`), it rewrites the class body in place.

## Ignores and Exclusions

- There is no per-file ignore directive for sorting.
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
