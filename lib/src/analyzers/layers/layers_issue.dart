/// Represents a layers architecture violation.
///
/// This class encapsulates information about a dependency violation
/// found during layers analysis, such as cyclic dependencies or
/// incorrect layer ordering.
class LayersIssue {
  /// The type of layers issue.
  final LayersIssueType type;

  /// The file path where the issue was found.
  final String filePath;

  /// Additional message describing the issue.
  final String message;

  /// Creates a new layers issue.
  ///
  /// [type] should be the type of violation detected.
  /// [filePath] should be the relative or absolute path to the source file.
  /// [message] should be a descriptive message about the violation.
  LayersIssue({
    required this.type,
    required this.filePath,
    required this.message,
  });

  /// Returns a string representation of this layers issue.
  ///
  /// The format is "[ISSUE_TYPE] filePath: message" which provides a
  /// human-readable summary of the issue location and description.
  ///
  /// Returns a formatted string describing the issue.
  @override
  String toString() => '[$type] $filePath: $message';

  /// Converts this issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'filePath': filePath,
        'message': message,
      };
}

/// Types of layers architecture violations.
enum LayersIssueType {
  /// A cyclic dependency was detected in the dependency graph.
  cyclicDependency,

  /// A component is in the wrong layer based on its dependencies.
  wrongLayer,

  /// A cyclic dependency was detected at the folder level.
  folderCycle,

  /// A folder is in the wrong layer based on its dependencies.
  wrongFolderLayer,
}
