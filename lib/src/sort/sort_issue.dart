/// Represents an issue found with source code sorting
class SourceSortIssue {
  /// Creates a new SourceSortIssue.
  ///
  /// [filePath] is the path to the file containing the issue.
  /// [className] is the name of the class with sorting issues.
  /// [lineNumber] is the line number where the class is declared.
  /// [description] describes the sorting issue found.
  SourceSortIssue({
    required this.filePath,
    required this.className,
    required this.lineNumber,
    required this.description,
  });

  /// The path to the file containing the sorting issue.
  final String filePath;

  /// The name of the class that has sorting issues.
  final String className;

  /// The line number where the class declaration starts.
  final int lineNumber;

  /// A description of the sorting issue.
  final String description;
}
