# Rule: Documentation

## Overview

Validates documentation quality as a first-class analyzer domain.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Flags

- **Missing README**: project root does not contain `README.md`.
- **Undocumented public classes**: public `class` declarations without doc comments.
- **Undocumented public functions**: public top-level functions or class methods without doc comments.
- **Undocumented complex private functions**: private functions/methods that are non-trivial and have no leading comment.

## Complexity Rule for Private Functions

Private functions (name starts with `_`) are treated as complex when:

- body has at least 10 non-empty lines, and
- at least one of these is true:
  - function body has control-flow constructs (`if`, loops, `switch`, `try`, ternary)
  - body has more than a short statement threshold
  - body spans more than a short non-empty line threshold

Short, self-explanatory private functions are allowed without comments.

## Skips

- Files with top-of-file `// ignore: fcheck_documentation`
- Nodes with `// ignore: fcheck_documentation` on the same line
- Files with parse errors or missing compilation units
- Generated and localization Dart files (`.g.dart`, `lib/l10n/`)

## Output

- `DocumentationIssue` fields: `type`, `filePath`, `lineNumber`, `subject`
- Issue types:
  - `missingReadme`
  - `undocumentedPublicClass`
  - `undocumentedPublicFunction`
  - `undocumentedComplexPrivateFunction`

## Related Files

- `lib/src/analyzers/documentation/documentation_delegate.dart`
- `lib/src/analyzers/documentation/documentation_visitor.dart`
- `lib/src/analyzers/documentation/documentation_analyzer.dart`
- `lib/src/analyzers/documentation/documentation_issue.dart`
- `lib/src/models/ignore_config.dart`
