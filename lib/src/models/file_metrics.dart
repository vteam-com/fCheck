/// Represents quality metrics for a single Dart file.
///
/// This class contains analysis results for an individual file including
/// size metrics, comment counts, and compliance with coding standards.
class FileMetrics {
  /// The file system path to this file.
  final String path;

  /// Total number of lines in the file.
  final int linesOfCode;

  /// Number of lines that contain comments.
  final int commentLines;

  /// Total number of functions and methods in the file.
  final int functionCount;

  /// Total number of top-level functions in the file.
  final int topLevelFunctionCount;

  /// Total number of methods in class/mixin/enum/extension declarations.
  final int methodCount;

  /// Total number of string literals in the file.
  final int stringLiteralCount;

  /// Total number of numeric literals (ints and doubles) in the file.
  final int numberLiteralCount;

  /// Number of class declarations in the file.
  final int classCount;

  /// Whether this file contains a StatefulWidget class.
  ///
  /// StatefulWidget classes are allowed to have 2 classes (widget + state)
  /// while still being compliant with the "one class per file" rule.
  final bool isStatefulWidget;

  /// Whether this file opts out of the "one class per file" rule.
  ///
  /// This is controlled via a top-of-file comment directive.
  final bool ignoreOneClassPerFile;

  /// Creates a new [FileMetrics] instance.
  ///
  /// All parameters are required and represent the analysis results
  /// for a single Dart file.
  FileMetrics({
    required this.path,
    required this.linesOfCode,
    required this.commentLines,
    required this.classCount,
    this.functionCount = 0,
    this.topLevelFunctionCount = 0,
    this.methodCount = 0,
    this.stringLiteralCount = 0,
    this.numberLiteralCount = 0,
    required this.isStatefulWidget,
    this.ignoreOneClassPerFile = false,
  });

  /// Maximum number of public classes allowed in a StatefulWidget file.
  static const int _maxClassesForStatefulWidget = 2;

  /// Whether this file complies with the "one class per file" rule.
  ///
  /// This rule only applies to public classes. Private classes (starting with _)
  /// are considered implementation details and don't count against the limit.
  ///
  /// - Regular files: Maximum 1 public class per file
  /// - StatefulWidget files: Maximum 2 public classes per file (widget + state)
  /// - Private classes: Unlimited (implementation details)
  /// - Returns `true` if compliant, `false` if violates the rule
  bool get isOneClassPerFileCompliant {
    if (ignoreOneClassPerFile) {
      return true;
    }
    if (isStatefulWidget) {
      // StatefulWidget usually has 2 classes: the widget and the state.
      return classCount <= _maxClassesForStatefulWidget;
    }
    return classCount <= 1;
  }

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'path': path,
        'linesOfCode': linesOfCode,
        'commentLines': commentLines,
        'classCount': classCount,
        'functionCount': functionCount,
        'stringLiteralCount': stringLiteralCount,
        'numberLiteralCount': numberLiteralCount,
        'isStatefulWidget': isStatefulWidget,
        'isOneClassPerFileCompliant': isOneClassPerFileCompliant,
        'ignoreOneClassPerFile': ignoreOneClassPerFile,
      };
}
