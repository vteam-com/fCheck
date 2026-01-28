/// Represents a magic number occurrence detected in source code.
///
/// This class captures the file path, line number, and literal value of a
/// suspicious numeric literal that should probably be expressed via a named
/// constant instead of being sprinkled throughout the codebase.
class MagicNumberIssue {
  /// The file path containing the magic number.
  final String filePath;

  /// The 1-based line number where the literal occurs.
  final int lineNumber;

  /// The literal value as written in source code (e.g. `42`, `3.14`).
  final String value;

  /// Creates a new [MagicNumberIssue].
  MagicNumberIssue({
    required this.filePath,
    required this.lineNumber,
    required this.value,
  });

  @override
  String toString() => '$filePath:$lineNumber: $value';

  /// Converts this issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'lineNumber': lineNumber,
        'value': value,
      };
}
