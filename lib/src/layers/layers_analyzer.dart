import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:yaml/yaml.dart';
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
  /// The root directory being analyzed.
  final Directory _rootDirectory;

  /// Creates a new LayersAnalyzer instance.
  ///
  /// This constructor creates an analyzer that can be used to detect
  /// layers architecture violations in Dart projects.
  LayersAnalyzer(this._rootDirectory);

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
    // Track entry points: Map<filePath, isEntryPoint>
    final Map<String, bool> entryPoints = <String, bool>{};

    // Collect dependencies and entry points for each file
    for (final File file in dartFiles) {
      final Map<String, dynamic> result = _analyzeFile(file);
      dependencyGraph[file.path] = result['dependencies'] as List<String>;
      entryPoints[file.path] = result['isEntryPoint'] as bool;
    }

    // Analyze the graph for issues
    return _analyzeGraph(dependencyGraph, entryPoints);
  }

  /// Analyzes a single Dart file for its dependencies and entry point status.
  ///
  /// This method parses the file using the Dart analyzer and collects
  /// all import and export dependencies, and identifies entry points.
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a map containing 'dependencies' (list of file paths) and 'isEntryPoint' (boolean).
  Map<String, dynamic> _analyzeFile(File file) {
    final String filePath = file.path;
    final String content = file.readAsStringSync();

    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return {'dependencies': <String>[], 'isEntryPoint': false};
    }

    final CompilationUnit compilationUnit = result.unit;
    final LayersVisitor visitor =
        LayersVisitor(filePath, _rootDirectory.path, _readPackageName());
    compilationUnit.accept(visitor);

    return {
      'dependencies': visitor.dependencies,
      'isEntryPoint': visitor.hasMainFunction,
    };
  }

  /// Analyzes the dependency graph for layers violations.
  ///
  /// This method performs topological sorting to detect cycles and
  /// assign layers to components. It generates issues for cyclic
  /// dependencies.
  ///
  /// [dependencyGraph] A map from file paths to their dependencies.
  /// [entryPoints] A map from file paths to whether they are entry points.
  ///
  /// Returns a [LayersAnalysisResult] with issues and layer assignments.
  LayersAnalysisResult _analyzeGraph(Map<String, List<String>> dependencyGraph,
      Map<String, bool> entryPoints) {
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
    final Map<String, int> layers = _assignLayers(dependencyGraph, entryPoints);

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

  /// Assigns layers to components using cake layout algorithm.
  ///
  /// This method implements proper topological layering based on LAYOUT.md:
  /// 1. Entry points (files with main() function) get Layer 1 (top)
  /// 2. Dependencies flow downwards to higher layer numbers
  /// 3. Each file is placed one layer below its deepest dependent
  /// 4. Circular dependencies are grouped into Strongly Connected Components (SCCs)
  ///
  /// [dependencyGraph] The dependency graph (source -> targets).
  /// [entryPoints] A map from file paths to whether they are entry points.
  ///
  /// Returns a map from file paths to their assigned layer numbers (1-based, 1 = top).
  Map<String, int> _assignLayers(Map<String, List<String>> dependencyGraph,
      Map<String, bool> entryPoints) {
    final Set<String> allFilesSet = <String>{}..addAll(dependencyGraph.keys);
    for (final deps in dependencyGraph.values) {
      allFilesSet.addAll(deps);
    }
    final List<String> allFiles = allFilesSet.toList();

    // Step 1: Find Strongly Connected Components (SCCs) to handle cycles
    final List<List<String>> sccs = _findSCCs(allFiles, dependencyGraph);

    // Map each file to its SCC index
    final Map<String, int> fileToSccIndex = <String, int>{};
    for (var i = 0; i < sccs.length; i++) {
      for (final file in sccs[i]) {
        fileToSccIndex[file] = i;
      }
    }

    // Step 2: Build SCC-level dependency graph (SCC Index -> Target SCC Indexes)
    final Map<int, Set<int>> sccDependentsMap = <int, Set<int>>{};
    for (var i = 0; i < sccs.length; i++) {
      sccDependentsMap[i] = <int>{};
    }

    // Populate sccDependentsMap: sourceSCC -> targetSCCs (where source imports target)
    for (final sourceFile in allFiles) {
      final sourceSccIndex = fileToSccIndex[sourceFile]!;
      final targets = dependencyGraph[sourceFile] ?? <String>[];
      for (final targetFile in targets) {
        final targetSccIndex = fileToSccIndex[targetFile];
        if (targetSccIndex != null && targetSccIndex != sourceSccIndex) {
          sccDependentsMap[sourceSccIndex]!.add(targetSccIndex);
        }
      }
    }

    // Step 3: Assign layers to SCCs iteratively
    // Initialize: all are Layer 1 (initially)
    final Map<int, int> sccLayers = <int, int>{};
    for (var i = 0; i < sccs.length; i++) {
      sccLayers[i] = 1;
    }

    // Iteratively push dependencies to deeper layers
    var changed = true;
    var iterations = 0;
    const maxIterations = 1000;
    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;

      for (var sourceScc = 0; sourceScc < sccs.length; sourceScc++) {
        final currentLayer = sccLayers[sourceScc]!;
        for (final targetScc in sccDependentsMap[sourceScc]!) {
          // sourceScc imports targetScc.
          // targetScc must be at least Layer(sourceScc) + 1
          if (sccLayers[targetScc]! < currentLayer + 1) {
            sccLayers[targetScc] = currentLayer + 1;
            changed = true;
          }
        }
      }
    }

    // Step 4: Map SCC layers back to files
    final Map<String, int> fileLayers = <String, int>{};
    for (var i = 0; i < sccs.length; i++) {
      for (final file in sccs[i]) {
        fileLayers[file] = sccLayers[i]!;
      }
    }

    // Step 5: Renumber layers to be sequential from 1
    if (fileLayers.isNotEmpty) {
      final uniqueLayers = fileLayers.values.toSet().toList()..sort();
      final layerMapping = <int, int>{};
      for (var i = 0; i < uniqueLayers.length; i++) {
        layerMapping[uniqueLayers[i]] = i + 1;
      }
      for (final file in fileLayers.keys) {
        fileLayers[file] = layerMapping[fileLayers[file]]!;
      }
    }

    return fileLayers;
  }

  /// Finds Strongly Connected Components using Tarjan's algorithm.
  List<List<String>> _findSCCs(
      List<String> nodes, Map<String, List<String>> graph) {
    var index = 0;
    final List<String> stack = <String>[];
    final Map<String, int> indices = <String, int>{};
    final Map<String, int> lowlink = <String, int>{};
    final Set<String> onStack = <String>{};
    final List<List<String>> sccs = <List<String>>[];

    void strongconnect(String v) {
      indices[v] = index;
      lowlink[v] = index;
      index++;
      stack.add(v);
      onStack.add(v);

      final successors = graph[v] ?? <String>[];
      for (final w in successors) {
        if (!indices.containsKey(w)) {
          strongconnect(w);
          lowlink[v] = lowlink[v]! < lowlink[w]! ? lowlink[v]! : lowlink[w]!;
        } else if (onStack.contains(w)) {
          lowlink[v] = lowlink[v]! < indices[w]! ? lowlink[v]! : indices[w]!;
        }
      }

      if (lowlink[v] == indices[v]) {
        final List<String> scc = <String>[];
        String w;
        do {
          w = stack.removeLast();
          onStack.remove(w);
          scc.add(w);
        } while (w != v);
        sccs.add(scc);
      }
    }

    for (final node in nodes) {
      if (!indices.containsKey(node)) {
        strongconnect(node);
      }
    }

    return sccs;
  }

  /// Reads the package name from pubspec.yaml in the directory hierarchy.
  String _readPackageName() {
    var currentDir = _rootDirectory;
    while (true) {
      final pubspecFile = File('${currentDir.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        try {
          final content = pubspecFile.readAsStringSync();
          final yaml = loadYaml(content) as YamlMap;
          return yaml['name'] as String? ?? 'unknown';
        } catch (e) {
          return 'unknown';
        }
      }
      final parent = currentDir.parent;
      if (parent.path == currentDir.path) break; // reached root
      currentDir = parent;
    }
    return 'unknown';
  }
}
