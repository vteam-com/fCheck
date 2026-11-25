import 'package:fcheck/src/input_output/issue_location_utils.dart';

/// How a stateful widget's `State` strays from Flutter's convention.
enum WidgetStateIssueType {
  /// The `State` is declared in another file than its widget, such as a
  /// part file or a library of its own.
  apart,

  /// The `State` is public though no other library names it.
  public,

  /// A test reaches into the `State`: it is private to its widget, so the
  /// test checks how the widget works rather than what it does. The issue
  /// points at the test's line.
  reachedByTest,
}

/// A widget `State` out of place, or a test line reaching into one.
///
/// A stateful widget is two classes: the widget, and the `State` its
/// `createState()` makes, which is part of the widget. So the `State`
/// lives in the widget's file, is private (`_FooState`) unless another
/// library of the app names it (`GlobalKey<FooState>`), and no test
/// reaches into it.
class WidgetStateIssue {
  static const Map<WidgetStateIssueType, String> _typeLabelsByIssueType = {
    WidgetStateIssueType.apart: 'State apart from its widget',
    WidgetStateIssueType.public: 'State public though no other file uses it',
    WidgetStateIssueType.reachedByTest: 'test reaching into a widget State',
  };

  /// How the `State` strays.
  final WidgetStateIssueType type;

  /// File declaring the `State`, or, for [WidgetStateIssueType.reachedByTest],
  /// the test reaching into it.
  final String filePath;

  /// 1-based line of the `State`'s declaration, or of the test's reach.
  final int lineNumber;

  /// Name of the `State` class.
  final String state;

  /// Name of the widget the `State` belongs to.
  final String widget;

  /// File declaring [widget].
  final String widgetFilePath;

  /// Whether the `State` is in its widget's library (the widget's file or
  /// one of its part files), so moving it beside the widget changes no
  /// import.
  final bool isInWidgetLibrary;

  /// Creates a widget `State` issue.
  const WidgetStateIssue({
    required this.type,
    required this.filePath,
    required this.lineNumber,
    required this.state,
    required this.widget,
    required this.widgetFilePath,
    required this.isInWidgetLibrary,
  });

  /// Human-readable label for the issue type.
  String get typeLabel => _typeLabelsByIssueType[type]!;

  /// Returns a copy of this issue with [filePath] and [widgetFilePath]
  /// mapped through [mapPath], such as to make them relative.
  WidgetStateIssue withPaths(String Function(String path) mapPath) =>
      WidgetStateIssue(
        type: type,
        filePath: mapPath(filePath),
        lineNumber: lineNumber,
        state: state,
        widget: widget,
        widgetFilePath: mapPath(widgetFilePath),
        isInWidgetLibrary: isInWidgetLibrary,
      );

  /// Formats this issue as a report line.
  String format({int? lineNumberWidth}) {
    assertValidLineNumberWidth(lineNumberWidth);
    final location = resolveIssueLocation(
      rawPath: filePath,
      lineNumber: lineNumber,
      strictPositiveLineNumber: true,
    );
    final stateName = colorizeIssueArtifact('"$state"');
    final widgetName = colorizeIssueArtifact('"$widget"');
    return '$location: $typeLabel $stateName of $widgetName';
  }

  @override
  String toString() => format();

  /// Converts this issue to JSON, the widget the `State` belongs to
  /// grouped with its file.
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'filePath': filePath,
    'lineNumber': lineNumber,
    'state': state,
    'isInWidgetLibrary': isInWidgetLibrary,
    'widget': {'name': widget, 'filePath': widgetFilePath},
  };
}
