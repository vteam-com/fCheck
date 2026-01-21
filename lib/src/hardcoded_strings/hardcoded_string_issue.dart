/// Represents a hardcoded string finding.
///
/// This class encapsulates information about a potentially hardcoded string
/// that was detected during analysis, including its location and value.
class HardcodedStringIssue {
  /// The file path where the hardcoded string was found.
  final String filePath;

  /// The line number where the hardcoded string appears.
  final int lineNumber;

  /// The hardcoded string value.
  final String value;

  /// Creates a new hardcoded string issue.
  ///
  /// [filePath] should be the relative or absolute path to the source file.
  /// [lineNumber] should be the 1-based line number where the string appears.
  /// [value] should be the actual string content without quotes.
  HardcodedStringIssue({
    required this.filePath,
    required this.lineNumber,
    required this.value,
  });

  /// Returns a string representation of this hardcoded string issue.
  ///
  /// The format is "filePath:lineNumber: "value"" which provides a
  /// human-readable summary of the issue location and content.
  ///
  /// Returns a formatted string describing the issue.
  @override
  String toString() => '$filePath:$lineNumber: "$value"';
}
