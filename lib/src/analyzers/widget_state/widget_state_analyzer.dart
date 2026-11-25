import 'package:fcheck/src/analyzers/widget_state/widget_state_file_data.dart';
import 'package:fcheck/src/analyzers/widget_state/widget_state_issue.dart';

/// A class of the project: its declaration, in its file.
typedef _Class = ({WidgetStateFileData file, WidgetStateClass declaration});

/// Where a `State` a test may name is declared: its widget, the widget's
/// file, and whether the `State` is in the widget's library.
typedef _StateHome = ({
  String widget,
  String widgetFilePath,
  bool isInWidgetLibrary,
});

/// Finds the `State` classes of a Flutter project's stateful widgets that
/// stray from Flutter's convention, and the tests reaching into one, from
/// the files' [WidgetStateFileData], read without resolving the code.
///
/// A stateful widget is two classes: the widget, and the `State` its
/// `createState` makes, which is part of the widget, not a class of its
/// own. So the `State` lives beside its widget, in the widget's file, not
/// in a part file or a file of its own, and is private (`_FooState`),
/// unless another library of the app names it, through a
/// `GlobalKey<FooState>`. No test reaches into it,
/// `tester.state<FooState>(…)`: a test checks the widget itself, through
/// what it shows and the callbacks it calls, so each test line reaching
/// into a `State` is an issue of its own, one naming a private `State`,
/// which can't compile, too.
///
/// A `State` whose line, or whose file's leading comments, say
/// `// ignore: fcheck_widget_state` is left alone; so is a test line
/// saying it.
class WidgetStateAnalyzer {
  /// The classes a widget with a `State` extends: Flutter's, Riverpod's
  /// and flutter_hooks'.
  static const Set<String> statefulWidgetTypes = {
    'StatefulWidget',
    'ConsumerStatefulWidget',
    'StatefulHookWidget',
    'StatefulHookConsumerWidget',
  };

  /// The classes a widget's `State` extends, with the widget as type
  /// argument: Flutter's and Riverpod's.
  static const Set<String> stateTypes = {'State', 'ConsumerState'};

  /// Creates a stateless analyzer.
  const WidgetStateAnalyzer();

  /// Judges the `State`s [files] declare, and the reaches of [tests] into
  /// them, returning the issues, by file then line, and how many widget
  /// `State`s [files] declare.
  ({List<WidgetStateIssue> issues, int stateCount}) analyze({
    required List<WidgetStateFileData> files,
    required List<WidgetStateFileData> tests,
  }) {
    final code = _byPath(files);
    final testFiles = _byPath(tests);
    final libraryOf = _librariesOf([...code, ...testFiles]);
    final classes = <_Class>[
      for (final file in code)
        for (final declaration in file.classes)
          (file: file, declaration: declaration),
    ];
    final superclassOf = {
      for (final (file: _, :declaration) in classes)
        declaration.name: ?declaration.superclass,
    };
    bool extendsOne(String name, Set<String> bases) {
      final seen = <String>{};
      String? current = name;
      while (current != null && seen.add(current)) {
        if (bases.contains(current)) {
          return true;
        }
        current = superclassOf[current];
      }
      return false;
    }

    final classesNamed = <String, List<_Class>>{};
    for (final entry in classes) {
      (classesNamed[entry.declaration.name] ??= []).add(entry);
    }
    final namesUsed = {
      for (final file in [...code, ...testFiles])
        file.filePath: {for (final type in file.typeUses) type.name},
    };
    final issues = <WidgetStateIssue>[];
    // The States a test may name: a private one too, which no test can
    // reach, so it doesn't compile
    final statesNamed = <String, _StateHome>{};
    var stateCount = 0;
    for (final (:file, :declaration) in classes) {
      final superclass = declaration.superclass;
      final widgetName = declaration.typeArgument;
      if (superclass == null ||
          widgetName == null ||
          !extendsOne(superclass, stateTypes)) {
        continue;
      }
      final library = libraryOf[file.filePath];
      final widgets = extendsOne(widgetName, statefulWidgetTypes)
          ? classesNamed[widgetName] ?? const <_Class>[]
          : const <_Class>[];
      final widget =
          widgets
              .where(
                (candidate) => libraryOf[candidate.file.filePath] == library,
              )
              .firstOrNull ??
          widgets.firstOrNull;
      if (widget == null) {
        continue;
      }
      stateCount++;
      final state = declaration.name;
      final home = (
        widget: widgetName,
        widgetFilePath: widget.file.filePath,
        isInWidgetLibrary: libraryOf[widget.file.filePath] == library,
      );
      statesNamed[state] = home;
      if (file.isIgnored || declaration.isIgnored) {
        continue;
      }

      WidgetStateIssue issue(WidgetStateIssueType type) => _issue(
        type,
        filePath: file.filePath,
        lineNumber: declaration.lineNumber,
        state: state,
        home: home,
      );
      if (widget.file.filePath != file.filePath) {
        issues.add(issue(WidgetStateIssueType.apart));
      }
      if (_isPrivate(state)) {
        continue;
      }
      bool namedIn(List<WidgetStateFileData> files) => files.any(
        (other) =>
            libraryOf[other.filePath] != library &&
            namesUsed[other.filePath]!.contains(state),
      );
      // One only tests name is theirs to stop reaching into: flagged there
      if (!namedIn(code) && !namedIn(testFiles)) {
        issues.add(issue(WidgetStateIssueType.public));
      }
    }
    final stateOfWidget = {
      for (final MapEntry(key: state, :value) in statesNamed.entries)
        value.widget: state,
    };
    for (final test in testFiles) {
      if (test.isIgnored) {
        continue;
      }
      final lines = <int>{};
      // Each type naming a State, and each widget's createState()
      final reaches = [
        ...test.typeUses,
        for (final maker in test.stateMakers)
          if (stateOfWidget[maker.name] case final state?)
            (
              name: state,
              offset: maker.offset,
              lineNumber: maker.lineNumber,
              isIgnored: maker.isIgnored,
            ),
      ]..sort((a, b) => a.offset.compareTo(b.offset));
      for (final reach in reaches) {
        final home = statesNamed[reach.name];
        if (home == null || reach.isIgnored || !lines.add(reach.lineNumber)) {
          continue;
        }
        issues.add(
          _issue(
            WidgetStateIssueType.reachedByTest,
            filePath: test.filePath,
            lineNumber: reach.lineNumber,
            state: reach.name,
            home: home,
          ),
        );
      }
    }
    return (issues: issues, stateCount: stateCount);
  }

  /// [files] sorted by path, so issues come by file.
  static List<WidgetStateFileData> _byPath(List<WidgetStateFileData> files) =>
      [...files]..sort((a, b) => a.filePath.compareTo(b.filePath));

  /// Whether [name] is private to its library.
  static bool _isPrivate(String name) => name.startsWith('_');

  /// The issue of [type] about [state], at [lineNumber] of [filePath].
  static WidgetStateIssue _issue(
    WidgetStateIssueType type, {
    required String filePath,
    required int lineNumber,
    required String state,
    required _StateHome home,
  }) => WidgetStateIssue(
    type: type,
    filePath: filePath,
    lineNumber: lineNumber,
    state: state,
    widget: home.widget,
    widgetFilePath: home.widgetFilePath,
    isInWidgetLibrary: home.isInWidgetLibrary,
  );

  /// The library each of [files] belongs to, by path: its own, or, for a
  /// part file, the file naming it in a `part` directive.
  static Map<String, String> _librariesOf(List<WidgetStateFileData> files) {
    final libraryOf = {for (final file in files) file.filePath: file.filePath};
    for (final file in files) {
      for (final part in file.partPaths) {
        libraryOf[part] = file.filePath;
      }
    }
    return libraryOf;
  }
}
