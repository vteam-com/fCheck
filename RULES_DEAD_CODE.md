# Rule: Dead Code

## Overview

Detects unused or unreachable Dart code by combining a dependency graph with
symbol usage tracking.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Flags

- **Dead files**: files not reachable from any entry point.
- **Dead classes**: top-level classes never referenced.
- **Dead functions**: top-level functions never referenced.
- **Dead methods**: class/mixin/enum/extension methods never referenced.
- **Unused variables**: local variables or parameters never referenced.

## Skips

- Files with a top-of-file `// ignore: fcheck_dead_code` directive do not emit
  dead-code declarations/issues, but still contribute dependencies and symbol
  usages to project-wide reachability/usage analysis.
- Generated Dart files ending with `*.g.dart` follow the same behavior as file-level dead-code ignore:
  declarations/issues are suppressed, while dependencies/usages are still collected.
- Nodes with `// ignore: fcheck_dead_code` on the same line as the node or an
  ancestor declaration line.
- Files with parse errors or missing compilation units.
- Files excluded by the default directory exclusions or custom `--exclude` patterns.

## How It Works

- `DeadCodeDelegate` runs `DeadCodeVisitor` per file to collect:
  - dependencies (imports/exports/parts resolved to paths)
  - top-level classes and functions
  - methods in classes/mixins/enums/extensions (except `@override` and abstract signatures)
  - identifiers used in the file (including type identifiers, getter/setter property names, and operator tokens inferred from expressions)
  - unused local variables/parameters (per-scope)
- `DeadCodeAnalyzer` builds a dependency graph, resolves entry points, and
  determines reachability and unused symbols.

## Reporting Contract

- Dead code must be reported unless an explicit dead-code ignore directive applies:
  - file-level: top-of-file `// ignore: fcheck_dead_code`
  - node-level: `// ignore: fcheck_dead_code` on the declaration line (or ignored ancestor declaration line)

## Entry Points

- If any file defines `main()`, those files are entry points.
- If no `main()` exists:
  - For **Dart** projects, `lib/<package>.dart` and top-level files in `lib/`
    are treated as entry points.
  - For **Flutter** projects, no implicit entry points are assumed.

## Public API Handling

- For **Dart** projects with no `main()`, public files in `lib/` are treated as
  used (to avoid flagging public API as dead).
- For **Flutter** projects, public API is not auto-assumed.

## Output

- `DeadCodeIssue` fields: `type`, `filePath`, `lineNumber`, `name`, `owner`.
- Display labels:
  - `dead file`, `dead class`, `dead function`, `unused variable`

## Related Files

- `lib/src/analyzers/dead_code/dead_code_analyzer.dart`
- `lib/src/analyzers/dead_code/dead_code_visitor.dart`
- `lib/src/analyzers/dead_code/dead_code_file_data.dart`
- `lib/src/analyzers/dead_code/dead_code_issue.dart`
- `lib/src/analyzer_runner/analyzer_delegates.dart`
- `lib/src/models/ignore_config.dart`
