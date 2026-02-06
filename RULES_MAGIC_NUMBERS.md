# Rule for Magic Numbers Analysis

## Overview

Detects numeric literals that should likely be expressed as named constants.

## Entry-Point Contract

See `RULES.md` for the project metadata contract.

## What It Flags

- Integer and double literals other than 0, 1, or -1.
- Any literal not covered by the skip rules below.

## Skips

- Literals inside annotations.
- Literals in const declarations or static const fields with descriptive names (name length > 3).
- Literals in final int/double/num declarations with descriptive names (name length > 3).
- Literals inside const expressions (const constructors, const lists, const sets/maps).
- Nodes with `// ignore: fcheck_magic_numbers` on the same line or an ancestor line.
- Files in `lib/l10n/` and generated files ending in `.g.dart`.
- Files with a top-of-file `// ignore: fcheck_magic_numbers` directive.

## How It Works

- `MagicNumberAnalyzer` parses a file and runs `MagicNumberVisitor`.
- `MagicNumberVisitor` inspects `IntegerLiteral` and `DoubleLiteral` AST nodes and emits `MagicNumberIssue`.

## Output

- `MagicNumberIssue` contains `filePath`, `lineNumber`, `value`.

## Related Files

- `lib/src/analyzers/magic_numbers/magic_number_analyzer.dart`
- `lib/src/analyzers/magic_numbers/magic_number_visitor.dart`
- `lib/src/analyzers/magic_numbers/magic_number_issue.dart`
- `lib/src/models/ignore_config.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`

## Notes

- The "descriptive name" check is currently only `name.length > 3`.
