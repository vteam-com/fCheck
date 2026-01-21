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
}

/// Represents the result of layers analysis.
///
/// This class encapsulates the issues found and the layer assignments
/// computed during layers analysis.
class LayersAnalysisResult {
  /// List of layers issues found.
  final List<LayersIssue> issues;

  /// Map from file paths to their assigned layer numbers.
  final Map<String, int> layers;

  /// The dependency graph used for analysis.
  final Map<String, List<String>> dependencyGraph;

  /// Creates a new layers analysis result.
  LayersAnalysisResult({
    required this.issues,
    required this.layers,
    required this.dependencyGraph,
  });

  /// The number of layers (max layer + 1).
  int get layerCount {
    if (layers.isEmpty) return 0;
    return layers.values.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// The total number of dependency edges in the graph.
  int get edgeCount {
    return dependencyGraph.values
        .map((dependencies) => dependencies.length)
        .fold(0, (sum, count) => sum + count);
  }
}

/// Types of layers architecture violations.
enum LayersIssueType {
  /// A cyclic dependency was detected in the dependency graph.
  cyclicDependency,

  /// A component is in the wrong layer based on its dependencies.
  wrongLayer,
}
