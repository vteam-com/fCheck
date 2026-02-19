# Rule: Duplicate Code

## Overview

Detects duplicated executable code blocks by comparing normalized token streams
for functions, methods, and constructors.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Flags

- **Duplicate blocks**: pairs of executable snippets with matching parameter
  signatures and similarity >= the configured threshold.

## Skips

- Files with a top-of-file `// ignore: fcheck_duplicate_code` directive.
- Generated/localization files (`.g.dart`, `lib/l10n/**`).
- Files with parse errors or missing compilation units.
- Snippets shorter than 20 normalized tokens.
- Snippets with fewer than 10 non-empty body lines.

## How It Works

- `DuplicateCodeDelegate` runs `DuplicateCodeVisitor` per file.
- `DuplicateCodeVisitor` extracts executable bodies and normalizes tokens:
  - compares snippets only when parameter signatures match
  - identifiers -> `<id>`
  - numbers -> `<num>`
  - string literals -> `<str>`
- `DuplicateCodeAnalyzer` compares snippet pairs with a bounded Levenshtein
  distance and reports matches at or above the configured threshold.

## Configuration

`analyzers.options.duplicate_code` supports:

- `similarity_threshold` (double, `0.0..1.0`, default `0.90`)
- `min_tokens` (positive int, default `20`)
- `min_non_empty_lines` (positive int, default `10`)

To change the default thresholds (`90%` similarity, `20` minimum tokens, `10`
minimum non-empty lines), add this to `.fcheck`:

```yaml
analyzers:
  options:
    duplicate_code:
      similarity_threshold: 0.85
      min_tokens: 30
      min_non_empty_lines: 20
```

If a field is omitted, fCheck falls back to the default for that field.

For direct API usage, `DuplicateCodeAnalyzer()` defaults to `0.90` similarity
unless a threshold is passed explicitly.

## Output

- `DuplicateCodeIssue` fields:
  - `firstFilePath`, `firstLineNumber`, `firstSymbol`
  - `secondFilePath`, `secondLineNumber`, `secondSymbol`
  - `similarity`, `lineCount`

## Related Files

- `lib/src/analyzers/duplicate_code/duplicate_code_analyzer.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_visitor.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_file_data.dart`
- `lib/src/analyzers/duplicate_code/duplicate_code_issue.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`
- `lib/src/models/ignore_config.dart`
