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

  /// Number of class declarations in the file.
  final int classCount;

  /// Whether this file contains a StatefulWidget class.
  ///
  /// StatefulWidget classes are allowed to have 2 classes (widget + state)
  /// while still being compliant with the "one class per file" rule.
  final bool isStatefulWidget;

  /// Creates a new [FileMetrics] instance.
  ///
  /// All parameters are required and represent the analysis results
  /// for a single Dart file.
  FileMetrics({
    required this.path,
    required this.linesOfCode,
    required this.commentLines,
    required this.classCount,
    required this.isStatefulWidget,
  });

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
    if (isStatefulWidget) {
      // StatefulWidget usually has 2 classes: the widget and the state.
      return classCount <= 2;
    }
    return classCount <= 1;
  }

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'path': path,
        'linesOfCode': linesOfCode,
        'commentLines': commentLines,
        'classCount': classCount,
        'isStatefulWidget': isStatefulWidget,
        'isOneClassPerFileCompliant': isOneClassPerFileCompliant,
      };
}
