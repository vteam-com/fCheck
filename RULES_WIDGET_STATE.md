# Rule: Widget State

## Overview

Checks that each Flutter stateful widget keeps its `State` the way Flutter's convention does.

A stateful widget is two classes: the widget, and the `State` its `createState()` makes. The `State` is part of its widget, not a class of its own:

- it lives beside its widget, in the widget's file, not in a part file or a file of its own;
- it is private (`_FooState`), as only its widget makes it; it stays public only when another library of the app names it, such as through a `GlobalKey<FooState>`, as Flutter's `FormState` is;
- no test reaches into it (`tester.state<FooState>(…)`): a test checks what the widget does (what it shows, the callbacks it calls) rather than how it works.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Flags

- **`apart`**: a `State` declared in another file than its widget, such as a part file or a library of its own.
- **`public`**: a public `State` no other library of the app or its tests names. A `State` only tests name is flagged at those tests instead.
- **`reachedByTest`**: each test line reaching into a `State`: naming its type (a private one too, which can't compile), or calling its widget's `createState()`, on a widget built in place or held by a local. One issue per line.

A `State` is a class extending `State<W>` or `ConsumerState<W>` (directly or through the project's own classes) where `W` extends `StatefulWidget`, `ConsumerStatefulWidget`, `StatefulHookWidget` or `StatefulHookConsumerWidget`. The code is read without resolving it, so names are matched as written.

## Scope

- `State`s and widgets: the analyzed Dart files (as other analyzers, `test/` and `integration_test/` excluded).
- Reaches: the Dart files under `test/` and `integration_test/`.
- Libraries: a part file belongs to the library naming it in a `part` directive.

## Skips

- Files with top-of-file `// ignore: fcheck_widget_state`
- A `State` whose declaration line (after its doc comment and annotations) ends with `// ignore: fcheck_widget_state`
- A test line ending with `// ignore: fcheck_widget_state`
- Generated and localization Dart files (`.g.dart`, `app_localizations*.dart`)

## Score

The domain counts only when the analyzed code declares at least one widget `State`:

```text
budget = max(2.0, widgetStates * 0.5)
score = 1 - (widgetStateIssues / budget)
```

Without a widget `State`, the report shows `[-] Widget states` with no detail line, among the analyzers left out of the score.

## Output

- `WidgetStateIssue` fields: `type`, `filePath`, `lineNumber`, `state`, `widget`, `widgetFilePath`, `isInWidgetLibrary` (whether moving the `State` beside its widget changes no import)
- JSON: `widgetStateIssues` entries with `type`, `filePath`, `lineNumber`, `state`, `isInWidgetLibrary` and `widget` (`name`, `filePath`); `stats.widgetStates` and `stats.widgetStateIssues`
- `ProjectMetrics.widgetStateCount`: widget `State`s declared

## Related Files

- `lib/src/analyzers/widget_state/widget_state_delegate.dart`
- `lib/src/analyzers/widget_state/widget_state_visitor.dart`
- `lib/src/analyzers/widget_state/widget_state_file_data.dart`
- `lib/src/analyzers/widget_state/widget_state_analyzer.dart`
- `lib/src/analyzers/widget_state/widget_state_issue.dart`
- `lib/src/models/ignore_config.dart`
