# Rule for Layers Analysis

## Overview

Builds a dependency graph between Dart files in the project, reports cycles, and computes layer numbers for visualization.

## What It Collects

- Dependencies from `import` and `export` directives.
- Entry points are files with a top-level `main()` function.

## How It Works (Project Analysis via `AnalyzeFolder.analyze()`)

- `LayersDelegate` runs inside the unified `AnalyzerRunner` pass and emits per-file dependency metadata (`filePath`, `dependencies`, `isEntryPoint`).
- `LayersAnalyzer.analyzeFromFileData` builds and validates the graph from that metadata.
- This avoids a second parse/traversal pass for layers during full-project analysis.
- `AnalyzeFolder.analyzeLayers()` also uses the same unified pass + `LayersDelegate` flow.

## How It Works (Directory Analysis)

- Uses `FileUtils.listDartFiles` with CLI `--exclude` patterns and default exclusions.
- Skips files with `// ignore: fcheck_layers`.
- Parses each file and uses `LayersVisitor` to collect dependencies and entry point status.
- `LayersAnalyzer` receives `projectRoot` and `packageName` from `AnalyzeFolder` (see `RULES.md` for the project metadata contract).
- Filters the dependency graph to only include analyzed files.
- Detects cycles using DFS and emits `LayersIssueType.cyclicDependency`.
- If no cycles, assigns layers using SCC-based topological layering.
- Layer numbers are 1-based and increase as dependencies go deeper.

## How It Works (Single File)

- `LayersAnalyzer.analyzeFile` is a simplified check.
- If a file has any `import` or `export` and is not an entry point, it emits `LayersIssueType.wrongLayer`.

## Output

- `LayersAnalysisResult` contains `issues`, `layers`, and `dependencyGraph`.
- `LayersIssue` contains `type`, `filePath`, `message`.

## Related Files

- `lib/src/analyzers/layers/layers_analyzer.dart`
- `lib/src/analyzers/layers/layers_visitor.dart`
- `lib/src/analyzers/layers/layers_issue.dart`
- `lib/src/analyzers/layers/layers_results.dart`
- `lib/src/models/ignore_config.dart`

## Notes

- Only project-local Dart imports are considered. `dart:` and external `package:` imports are ignored.
- The current layer assignment algorithm does not explicitly use entry points beyond dependency flow.
- When used outside `AnalyzeFolder`, callers must supply `projectRoot` and `packageName` explicitly to avoid any metadata lookup.
