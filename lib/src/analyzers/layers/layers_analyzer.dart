import 'dart:io';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';

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
  /// Project metadata must be supplied by the entry point (AnalyzeFolder).
  LayersAnalyzer(
    Directory rootDirectory, {
    required Directory projectRoot,
    required String packageName,
  });

  /// Analyzes pre-collected per-file dependency data for layers violations.
  ///
  /// [fileData] should contain maps:
  /// [analyzedFilePaths] can be provided to drop dependency edges to files
  /// not in the analyzed set.
  LayersAnalysisResult analyzeFromFileData(
    List<Map<String, dynamic>> fileData, {
    Set<String>? analyzedFilePaths,
  }) {
    // Build dependency graph: Map<filePath, List<dependencies>>
    final Map<String, List<String>> dependencyGraph = <String, List<String>>{};

    for (final data in fileData) {
      final filePath = data['filePath'];
      final dependencies = data['dependencies'];
      if (filePath is! String || dependencies is! List<String>) {
        continue;
      }
      dependencyGraph[filePath] = dependencies;
    }

    final Set<String> allowedPaths =
        analyzedFilePaths ?? dependencyGraph.keys.toSet();
    final Map<String, List<String>> filteredGraph = <String, List<String>>{};

    for (final entry in dependencyGraph.entries) {
      final filteredDeps =
          entry.value.where((dep) => allowedPaths.contains(dep)).toList();
      filteredGraph[entry.key] = filteredDeps;
    }

    return _analyzeGraph(filteredGraph);
  }

  /// Analyzes the dependency graph for layers violations.
  ///
  /// This method performs topological sorting to detect cycles and
  /// assign layers to components. It generates issues for cyclic
  /// dependencies at both file and folder levels.
  ///
  /// [dependencyGraph] A map from file paths to their dependencies.
  ///
  /// Returns a [LayersAnalysisResult] with issues and layer assignments.
  LayersAnalysisResult _analyzeGraph(
    Map<String, List<String>> dependencyGraph,
  ) {
    final List<LayersIssue> issues = <LayersIssue>[];

    // Detect cycles using DFS at file level
    final Set<String> visited = <String>{};
    final Set<String> recursionStack = <String>{};

    for (final String file in dependencyGraph.keys) {
      if (!visited.contains(file)) {
        _detectCycles(file, dependencyGraph, visited, recursionStack, issues);
      }
    }

    // Build folder-to-folder dependency graph
    final Map<String, List<String>> folderGraph =
        _buildFolderGraph(dependencyGraph);

    // Detect folder-level cycles
    final Set<String> folderVisited = <String>{};
    final Set<String> folderRecursionStack = <String>{};

    for (final String folder in folderGraph.keys) {
      if (!folderVisited.contains(folder)) {
        _detectFolderCycles(
            folder, folderGraph, folderVisited, folderRecursionStack, issues);
      }
    }

    // If there are cycles, we can't reliably assign layers
    if (issues.any((i) =>
        i.type == LayersIssueType.cyclicDependency ||
        i.type == LayersIssueType.folderCycle)) {
      return LayersAnalysisResult(
        issues: issues,
        layers: <String, int>{},
        dependencyGraph: dependencyGraph,
      );
    }

    // Perform topological sort to assign layers
    final Map<String, int> layers = _assignLayers(dependencyGraph);

    // Detect folder layer violations
    _detectFolderLayerViolations(folderGraph, layers, issues);

    return LayersAnalysisResult(
      issues: issues,
      layers: layers,
      dependencyGraph: dependencyGraph,
    );
  }

  /// Builds a folder-to-folder dependency graph from file dependencies.
  ///
  /// [fileGraph] A map from file paths to their dependencies.
  ///
  /// Returns a map from folder paths to their folder dependencies.
  Map<String, List<String>> _buildFolderGraph(
    Map<String, List<String>> fileGraph,
  ) {
    final Map<String, Set<String>> folderDeps = <String, Set<String>>{};

    for (final entry in fileGraph.entries) {
      final String sourceFile = entry.key;
      final List<String> dependencies = entry.value;

      final String sourceFolder = _getFolder(sourceFile);
      if (sourceFolder.isEmpty) continue;

      folderDeps.putIfAbsent(sourceFolder, () => <String>{});

      for (final dep in dependencies) {
        final String targetFolder = _getFolder(dep);
        if (targetFolder.isEmpty || targetFolder == sourceFolder) continue;

        folderDeps[sourceFolder]!.add(targetFolder);
      }
    }

    // Convert Sets to Lists
    final Map<String, List<String>> result = <String, List<String>>{};
    for (final entry in folderDeps.entries) {
      result[entry.key] = entry.value.toList();
    }

    return result;
  }

  /// Extracts the folder path from a file path.
  ///
  /// Returns the parent directory path, or empty string if file is at root.
  String _getFolder(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash <= 0) return '';
    return filePath.substring(0, lastSlash);
  }

  /// Detects cycles in a graph using DFS.
  ///
  /// This is a generic method that can detect cycles in any directed graph.
  /// [node] - current node being visited
  /// [graph] - the dependency graph
  /// [visited] - set of nodes that have been fully processed
  /// [recursionStack] - set of nodes currently in the recursion stack
  /// [issues] - list to add detected issues to
  /// [issueType] - the type of issue to create (file or folder cycle)
  /// [getMessage] - function to generate the error message
  void _detectCyclesGeneric<T>(
    T node,
    Map<T, List<T>> graph,
    Set<T> visited,
    Set<T> recursionStack,
    List<LayersIssue> issues,
    LayersIssueType issueType,
    String Function(T node) getMessage,
  ) {
    visited.add(node);
    recursionStack.add(node);

    final List<T> dependencies = graph[node] ?? <T>[];

    for (final T dependency in dependencies) {
      if (!visited.contains(dependency)) {
        _detectCyclesGeneric(dependency, graph, visited, recursionStack, issues,
            issueType, getMessage);
      } else if (recursionStack.contains(dependency)) {
        // Found a cycle
        issues.add(
          LayersIssue(
            type: issueType,
            filePath: node.toString(),
            message: getMessage(node),
          ),
        );
      }
    }

    recursionStack.remove(node);
  }

  /// Detects cycles in the folder dependency graph.
  void _detectFolderCycles(
    String folder,
    Map<String, List<String>> folderGraph,
    Set<String> visited,
    Set<String> recursionStack,
    List<LayersIssue> issues,
  ) {
    _detectCyclesGeneric<String>(
      folder,
      folderGraph,
      visited,
      recursionStack,
      issues,
      LayersIssueType.folderCycle,
      (node) => 'Cyclic folder dependency detected involving $node',
    );
  }

  /// Detects folder layer ordering violations.
  ///
  /// A folder is in the wrong layer if it depends on a folder that should
  /// be in a layer above (closer to entry points).
  void _detectFolderLayerViolations(
    Map<String, List<String>> folderGraph,
    Map<String, int> fileLayers,
    List<LayersIssue> issues,
  ) {
    // Folder-level layer violations are intentionally suppressed.
    // Folder placement can vary by project structure and frequently creates
    // false positives. Layers issues should focus on file-level dependency
    // direction instead of directory naming/layout conventions.
    if (folderGraph.isEmpty || fileLayers.isEmpty || issues.isEmpty) {
      return;
    }
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
          dependency,
          dependencyGraph,
          visited,
          recursionStack,
          issues,
        );
      } else if (recursionStack.contains(dependency)) {
        // Found a cycle
        issues.add(
          LayersIssue(
            type: LayersIssueType.cyclicDependency,
            filePath: file,
            message: 'Cyclic dependency detected involving $dependency',
          ),
        );
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
  Map<String, int> _assignLayers(
    Map<String, List<String>> dependencyGraph,
  ) {
    final Set<String> allFilesSet = <String>{}..addAll(dependencyGraph.keys);
    for (final deps in dependencyGraph.values) {
      allFilesSet.addAll(deps);
    }
    final List<String> allFiles = allFilesSet.toList();

    // Step 1: Find Strongly Connected Components (SCCs) to handle cycles
    final List<List<String>> connectedGraph = _findSCCs(
      allFiles,
      dependencyGraph,
    );

    // Map each file to its SCC index
    final Map<String, int> fileToSccIndex = <String, int>{};
    for (var i = 0; i < connectedGraph.length; i++) {
      for (final file in connectedGraph[i]) {
        fileToSccIndex[file] = i;
      }
    }

    // Step 2: Build SCC-level dependency graph (SCC Index -> Target SCC Indexes)
    final Map<int, Set<int>> sccDependentsMap = <int, Set<int>>{};
    for (var i = 0; i < connectedGraph.length; i++) {
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
    for (var i = 0; i < connectedGraph.length; i++) {
      sccLayers[i] = 1;
    }

    // Iteratively push dependencies to deeper layers
    var changed = true;
    var iterations = 0;
    const maxIterations = 1000;
    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;

      for (var sourceScc = 0; sourceScc < connectedGraph.length; sourceScc++) {
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
    for (var i = 0; i < connectedGraph.length; i++) {
      for (final file in connectedGraph[i]) {
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
    List<String> nodes,
    Map<String, List<String>> graph,
  ) {
    var index = 0;
    final List<String> stack = <String>[];
    final Map<String, int> indices = <String, int>{};
    final Map<String, int> lowlink = <String, int>{};
    final Set<String> onStack = <String>{};
    final List<List<String>> connectedGraph = <List<String>>[];

    void strongConnect(String v) {
      indices[v] = index;
      lowlink[v] = index;
      index++;
      stack.add(v);
      onStack.add(v);

      final successors = graph[v] ?? <String>[];
      for (final w in successors) {
        if (!indices.containsKey(w)) {
          strongConnect(w);
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
        connectedGraph.add(scc);
      }
    }

    for (final node in nodes) {
      if (!indices.containsKey(node)) {
        strongConnect(node);
      }
    }

    return connectedGraph;
  }
}
