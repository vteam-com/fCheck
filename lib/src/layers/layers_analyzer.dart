import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'layers_issue.dart';
import 'layers_visitor.dart';
import '../utils.dart';

/// Analyzer for detecting layers architecture violations.
///
/// This class provides methods to analyze Dart files for dependency
/// issues, such as cyclic dependencies and incorrect layering.
/// It builds a dependency graph and uses topological sorting to
/// assign layers to components.
class LayersAnalyzer {
  /// Creates a new LayersAnalyzer instance.
  ///
  /// This constructor creates an analyzer that can be used to detect
  /// layers architecture violations in Dart projects.
  LayersAnalyzer();

  /// Analyzes all Dart files in a directory for layers violations.
  ///
  /// This method recursively scans the directory tree starting from [directory]
  /// and analyzes all `.dart` files found, excluding example/, test/, tool/,
  /// and build directories. It builds a dependency graph and detects
  /// cyclic dependencies and layering violations.
  ///
  /// [directory] The root directory to scan.
  ///
  /// Returns a [LayersAnalysisResult] containing issues and layer assignments.
  LayersAnalysisResult analyzeDirectory(Directory directory) {
    final List<File> dartFiles = FileUtils.listDartFiles(directory);

    // Build dependency graph: Map<filePath, List<dependencies>>
    final Map<String, List<String>> dependencyGraph = <String, List<String>>{};

    // Collect dependencies for each file
    for (final File file in dartFiles) {
      final dependencies = _analyzeFile(file);
      dependencyGraph[file.path] = dependencies;
    }

    // Analyze the graph for issues
    return _analyzeGraph(dependencyGraph);
  }

  /// Analyzes a single Dart file for its dependencies.
  ///
  /// This method parses the file using the Dart analyzer and collects
  /// all import and export dependencies.
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a list of file paths that this file depends on.
  List<String> _analyzeFile(File file) {
    final String filePath = file.path;
    final String content = file.readAsStringSync();

    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return [];
    }

    final CompilationUnit compilationUnit = result.unit;
    final LayersVisitor visitor = LayersVisitor(filePath);
    compilationUnit.accept(visitor);

    return visitor.dependencies;
  }

  /// Analyzes the dependency graph for layers violations.
  ///
  /// This method performs topological sorting to detect cycles and
  /// assign layers to components. It generates issues for cyclic
  /// dependencies.
  ///
  /// [dependencyGraph] A map from file paths to their dependencies.
  ///
  /// Returns a [LayersAnalysisResult] with issues and layer assignments.
  LayersAnalysisResult _analyzeGraph(
      Map<String, List<String>> dependencyGraph) {
    final List<LayersIssue> issues = <LayersIssue>[];

    // Detect cycles using DFS
    final Set<String> visited = <String>{};
    final Set<String> recursionStack = <String>{};

    for (final String file in dependencyGraph.keys) {
      if (!visited.contains(file)) {
        _detectCycles(file, dependencyGraph, visited, recursionStack, issues);
      }
    }

    // If there are cycles, we can't reliably assign layers
    if (issues.isNotEmpty) {
      return LayersAnalysisResult(
        issues: issues,
        layers: <String, int>{},
        dependencyGraph: dependencyGraph,
      );
    }

    // Perform topological sort to assign layers
    final Map<String, int> layers = _assignLayers(dependencyGraph);

    // Validate layer assignments (for future use - currently no wrong layer issues)
    // In a more complete implementation, we could define layer boundaries
    // and check if components are in the correct layers

    return LayersAnalysisResult(
      issues: issues,
      layers: layers,
      dependencyGraph: dependencyGraph,
    );
  }

  /// Detects cycles in the dependency graph using DFS.
  ///
  /// This method traverses the graph and detects back edges that indicate
  /// cyclic dependencies. When a cycle is found, it creates a LayersIssue.
  ///
  /// [file] The current file being visited.
  /// [dependencyGraph] The dependency graph.
  /// [visited] Set of files that have been fully processed.
  /// [recursionStack] Set of files currently in the recursion stack.
  /// [issues] List to add detected issues to.
  void _detectCycles(
    String file,
    Map<String, List<String>> dependencyGraph,
    Set<String> visited,
    Set<String> recursionStack,
    List<LayersIssue> issues,
  ) {
    visited.add(file);
    recursionStack.add(file);

    final List<String> dependencies = dependencyGraph[file] ?? <String>[];

    for (final String dependency in dependencies) {
      if (!visited.contains(dependency)) {
        _detectCycles(
            dependency, dependencyGraph, visited, recursionStack, issues);
      } else if (recursionStack.contains(dependency)) {
        // Found a cycle
        issues.add(LayersIssue(
          type: LayersIssueType.cyclicDependency,
          filePath: file,
          message: 'Cyclic dependency detected involving $dependency',
        ));
      }
    }

    recursionStack.remove(file);
  }

  /// Assigns layers to components using topological sorting.
  ///
  /// This method performs a topological sort of the dependency graph
  /// where components with no dependencies get the lowest layer numbers
  /// (bottom layers), and components that nothing depends on get the
  /// highest layer numbers (top layers).
  ///
  /// [dependencyGraph] The dependency graph.
  ///
  /// Returns a map from file paths to their assigned layer numbers.
  Map<String, int> _assignLayers(Map<String, List<String>> dependencyGraph) {
    final Map<String, int> layers = <String, int>{};
    final Set<String> visited = <String>{};

    // Start topological sort from files with no dependencies (bottom layer)
    for (final String file in dependencyGraph.keys) {
      if (!visited.contains(file)) {
        _topologicalSort(file, dependencyGraph, visited, layers);
      }
    }

    return layers;
  }

  /// Performs topological sorting to assign layer numbers.
  ///
  /// This recursive method assigns layer numbers where:
  /// - Bottom layer (layer 0): components with no dependencies
  /// - Higher layers: components that depend on lower layers
  /// - Top layer: components that nothing depends on
  ///
  /// [file] The current file being processed.
  /// [dependencyGraph] The dependency graph.
  /// [visited] Set of files that have been processed.
  /// [layers] Map to store assigned layer numbers.
  void _topologicalSort(
    String file,
    Map<String, List<String>> dependencyGraph,
    Set<String> visited,
    Map<String, int> layers,
  ) {
    visited.add(file);

    final List<String> dependencies = dependencyGraph[file] ?? <String>[];
    int maxDependencyLayer = -1;

    // Process all dependencies first
    for (final String dependency in dependencies) {
      if (!visited.contains(dependency)) {
        _topologicalSort(dependency, dependencyGraph, visited, layers);
      }
      final dependencyLayer = layers[dependency] ?? 0;
      if (dependencyLayer > maxDependencyLayer) {
        maxDependencyLayer = dependencyLayer;
      }
    }

    // Assign layer: one higher than the highest dependency
    layers[file] = maxDependencyLayer + 1;
  }
}
