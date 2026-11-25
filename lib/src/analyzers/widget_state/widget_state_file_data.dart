/// A class a Dart file declares, as the widget `State` analysis reads it:
/// its [name], the class it extends and that class's first type argument,
/// such as `State` and `Counter` for `extends State<Counter>`.
typedef WidgetStateClass = ({
  String name,
  String? superclass,
  String? typeArgument,
  int lineNumber,
  bool isIgnored,
});

/// A [name] a Dart file writes at [offset], on [lineNumber]: a type, which
/// may name a widget `State`, or the widget whose `createState()` it calls.
typedef WidgetStateReference = ({
  String name,
  int offset,
  int lineNumber,
  bool isIgnored,
});

/// What one Dart file holds for the widget `State` analysis, read without
/// resolving it.
class WidgetStateFileData {
  /// Path of the file.
  final String filePath;

  /// Whether a top-of-file `// ignore: fcheck_widget_state` skips the
  /// whole file.
  final bool isIgnored;

  /// Normalized paths of the part files the file names in `part`
  /// directives.
  final List<String> partPaths;

  /// The classes the file declares.
  final List<WidgetStateClass> classes;

  /// The types the file writes, in source order.
  final List<WidgetStateReference> typeUses;

  /// The file's calls of a widget's `createState()`, each naming the
  /// widget, in source order.
  final List<WidgetStateReference> stateMakers;

  /// Creates the widget `State` data of one file.
  const WidgetStateFileData({
    required this.filePath,
    required this.isIgnored,
    required this.partPaths,
    required this.classes,
    required this.typeUses,
    required this.stateMakers,
  });
}
