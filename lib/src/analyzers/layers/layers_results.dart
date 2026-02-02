import 'package:fcheck/src/analyzers/layers/layers_issue.dart';

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

  /// Converts this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'issues': issues.map((i) => i.toJson()).toList(),
        'layers': layers,
        'dependencyGraph': dependencyGraph,
        'layerCount': layerCount,
        'edgeCount': edgeCount,
      };
}
