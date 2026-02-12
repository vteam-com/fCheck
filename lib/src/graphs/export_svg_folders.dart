/// Generates a hierarchical SVG visualization of the dependency graph.
/// This approach preserves the parent-child folder relationships.
library;

import 'dart:math';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/models/rect.dart';
import 'package:fcheck/src/graphs/svg_common.dart';
import 'package:fcheck/src/graphs/svg_styles.dart';
import 'package:fcheck/src/graphs/badge_model.dart';
import 'package:path/path.dart' as p;

/// Represents a folder in the hierarchy.
class FolderNode {
  /// Folder display name.
  final String name;

  /// Full path of the folder relative to the analyzed root.
  final String fullPath;

  /// Child folders.
  final List<FolderNode> children;

  /// Files contained directly in this folder.
  final List<String> files;

  /// Number of incoming folder-level dependencies.
  int incoming = 0;

  /// Number of outgoing folder-level dependencies.
  int outgoing = 0;

  /// Whether this is a virtual folder for loose files.
  final bool isVirtual;

  /// Creates a folder node.
  FolderNode(this.name, this.fullPath, this.children, this.files,
      {this.isVirtual = false});
}

/// Captures file label rendering data so we can draw after edges.
class _FileVisual {
  final String path;
  final String name;
  final double textX;
  final double textY;
  final double badgeX;
  final double badgeY;
  final double panelX;
  final double panelWidth;
  final int incoming;
  final int outgoing;
  final List<String> incomingPeers;
  final List<String> outgoingPeers;

  _FileVisual({
    required this.path,
    required this.name,
    required this.textX,
    required this.textY,
    required this.badgeX,
    required this.badgeY,
    required this.panelX,
    required this.panelWidth,
    required this.incoming,
    required this.outgoing,
    required this.incomingPeers,
    required this.outgoingPeers,
  });
}

/// Captures folder title info to render above edges.
class _TitleVisual {
  final double x;
  final double y;
  final String text;
  final double maxWidth;
  _TitleVisual(this.x, this.y, this.text, this.maxWidth);
}

const double _titleLineHeight = 16.0;

/// Represents a folder-to-folder dependency edge.
class _FolderEdge {
  final String sourceFolder;
  final String targetFolder;
  _FolderEdge(this.sourceFolder, this.targetFolder);
}

/// Collects every file mentioned in the dependency graph (keys and targets).
Set<String> _collectAllFilePaths(Map<String, List<String>> dependencyGraph) {
  final all = <String>{};
  for (final entry in dependencyGraph.entries) {
    all.add(entry.key);
    all.addAll(entry.value);
  }
  return all;
}

/// Finds a common root directory for a set of paths.
String _findCommonRoot(Set<String> paths) {
  if (paths.isEmpty) return '.';

  final splitPaths = paths
      .map((pPath) => p
          .normalize(pPath)
          .split(p.separator)
          .where((p) => p.isNotEmpty)
          .toList())
      .toList();

  if (splitPaths.isEmpty) return '.';

  var minLength = splitPaths
      .map((segments) => segments.length)
      .reduce((a, b) => a < b ? a : b);
  final common = <String>[];

  for (var i = 0; i < minLength; i++) {
    final segment = splitPaths.first[i];
    final allMatch = splitPaths.every((segments) => segments[i] == segment);
    if (allMatch) {
      common.add(segment);
    } else {
      break;
    }
  }

  if (common.isEmpty) {
    // No shared prefix; fall back to the directory of the first path.
    final first = paths.first;
    return p.dirname(first);
  }

  final commonPath = p.joinAll(common);
  // Ensure absolute when originals were absolute (posix needs leading separator)
  if (paths.any((path) => p.isAbsolute(path)) && !p.isAbsolute(commonPath)) {
    return '${p.separator}$commonPath';
  }

  return commonPath;
}

/// Convert every path in the graph to be relative to [root].
Map<String, List<String>> _relativizeGraph(
    Map<String, List<String>> graph, String root) {
  final relative = <String, List<String>>{};

  for (final entry in graph.entries) {
    final source = p.relative(entry.key, from: root);
    final targets =
        entry.value.map((target) => p.relative(target, from: root)).toList();
    relative[source] = targets;
  }

  return relative;
}

/// Returns the shared top-level segment if all paths share one; otherwise null.
String? _commonTopLevelSegment(List<String> paths) {
  if (paths.isEmpty) return null;
  String? firstSegment;

  for (final path in paths) {
    final parts = path.split('/');
    if (parts.isEmpty) return null;
    final segment = parts.first;
    firstSegment ??= segment;
    if (segment != firstSegment) {
      return null;
    }
  }

  return firstSegment;
}

/// Generates a hierarchical SVG visualization of the dependency graph.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
/// [projectName] The name of the project from pubspec.yaml.
/// [projectVersion] The version of the project from pubspec.yaml.
/// [inputFolderName] The name of the input folder being analyzed.
///
/// Returns an SVG string representing the hierarchical folder dependency graph.
String exportGraphSvgFolders(
  LayersAnalysisResult layersResult, {
  String projectName = 'unknown',
  String projectVersion = 'unknown',
  String inputFolderName = '.',
}) {
  final dependencyGraph = layersResult.dependencyGraph;

  if (dependencyGraph.isEmpty) {
    return generateEmptySvg('No hierarchical dependencies found');
  }

  // Normalize paths to a common root and include target-only files
  final allAbsolutePaths = _collectAllFilePaths(dependencyGraph);
  final commonRoot = _findCommonRoot(allAbsolutePaths);
  final relativeGraph = _relativizeGraph(dependencyGraph, commonRoot);

  // Build hierarchical folder structure from relative paths
  final allRelativePaths = _collectAllFilePaths(relativeGraph).toList();
  final rootNode = _buildFolderHierarchy(allRelativePaths);

  // Calculate folder-level dependency counts using relative paths
  final folderMetrics = _calculateFolderMetrics(relativeGraph, rootNode);
  final fileMetrics = _calculateFileMetrics(relativeGraph);
  final folderLevels = _computeFolderLevels(relativeGraph, rootNode);

  final folderDependencies =
      _collectFolderDependencies(relativeGraph, rootNode);
  final folderDepGraph = <String, List<String>>{};
  for (final edge in folderDependencies) {
    folderDepGraph
        .putIfAbsent(edge.sourceFolder, () => [])
        .add(edge.targetFolder);
  }

  // --- Extra canvas width to accommodate left/right-routed edges ---
  const double edgeLanePadding = 40.0;
  const double edgeLaneBaseWidth = 32.0;
  const double edgeLanePerEdgeWidth = 4.0;

  // Extra canvas width to accommodate left/right-routed edges
  final totalFileEdges =
      relativeGraph.values.fold<int>(0, (sum, list) => sum + list.length);
  final fileEdgeExtraWidth = edgeLanePadding +
      (edgeLaneBaseWidth + totalFileEdges * edgeLanePerEdgeWidth);
  final folderEdgeExtraWidth = edgeLanePadding +
      (edgeLaneBaseWidth + folderDependencies.length * edgeLanePerEdgeWidth);

  // --- Layout Constants ---
  const double baseFolderWidth = 260.0;
  const double folderPadding = 24.0;
  const double childIndent = 40.0;
  const double childSpacing = 24.0;
  const double margin = 80.0;
  const double folderHeaderHeight = 32.0;
  const double fileItemHeight = 22.0;
  const double fileItemSpacing = 10.0;
  const double fileTopPadding = 20.0;
  const double filesToChildrenSpacing = 16.0;

  final folderPositions = <String, Point<double>>{};
  final folderDimensions = <String, Rect>{};
  final maxFileNameChars = relativeGraph.keys
      .followedBy(relativeGraph.values.expand((v) => v))
      .map((p) => p.split('/').last.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  const double charToPixelFactor = 6.0;
  const double labelPadding = 12.0;
  final labelWidth = (maxFileNameChars * charToPixelFactor) + labelPadding;

  // Measure folders bottom-up so parents grow to fit their children
  final rootSize = _computeFolderDimensions(
    rootNode,
    folderDimensions,
    labelWidth: labelWidth,
    folderLevels: folderLevels,
    baseWidth: baseFolderWidth,
    padding: folderPadding,
    childIndent: childIndent,
    childSpacing: childSpacing,
    headerHeight: folderHeaderHeight,
    fileItemHeight: fileItemHeight,
    fileItemSpacing: fileItemSpacing,
    fileTopPadding: fileTopPadding,
    filesToChildrenSpacing: filesToChildrenSpacing,
  );

  // Position folders top-down so each child sits inside its parent
  _positionFolders(
    rootNode,
    folderPositions,
    folderDimensions,
    folderLevels: folderLevels,
    startX: margin + folderEdgeExtraWidth,
    startY: margin,
    padding: folderPadding,
    childIndent: childIndent,
    childSpacing: childSpacing,
    headerHeight: folderHeaderHeight,
    fileItemHeight: fileItemHeight,
    fileItemSpacing: fileItemSpacing,
    fileTopPadding: fileTopPadding,
    filesToChildrenSpacing: filesToChildrenSpacing,
  );

  // Depth-first order ensures parents render before their children
  final drawOrder = _collectDepthFirst(rootNode);
  final depthMap = _computeDepths(rootNode);

  // Calculate total width and height based on root container plus edge padding

  // Calculate total width and height based on root container plus edge padding
  // Folders are centered, with dedicated lanes for folder and file connections
  final totalWidth = margin +
      folderEdgeExtraWidth +
      rootSize.width +
      fileEdgeExtraWidth +
      margin;
  final totalHeight = margin + rootSize.height + margin;

  final buffer = StringBuffer();

  // SVG Header
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<svg width="$totalWidth" height="$totalHeight" viewBox="0 0 $totalWidth $totalHeight" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">');

  // Common SVG Definitions
  buffer.writeln(SvgDefinitions.generateUnifiedDefs());

  // CSS Styles
  buffer.writeln(SvgDefinitions.generateUnifiedStyles());

  // Background
  buffer.writeln('<rect width="100%" height="100%" fill="#f8f9fa"/>');

  // Draw hierarchical edges (parent-child relationships)
  _drawEdgeHorizontalCurve(buffer, drawOrder, folderPositions, folderDimensions,
      padding: folderPadding, childIndent: childIndent);

  // Track file anchor positions for dependency edges
  final fileAnchors = <String, Map<String, Point<double>>>{};
  final fileVisuals = <_FileVisual>[];
  final titleVisuals = <_TitleVisual>[];
  final folderBadges = <BadgeModel>[];
  final folderPeers = buildPeerLists(folderDepGraph, labelFor: (path) => path);
  final folderIncomingPeers = folderPeers.incoming;
  final folderOutgoingPeers = folderPeers.outgoing;
  final filePeers = buildPeerLists(relativeGraph, labelFor: (path) => path);
  final fileIncomingPeers = filePeers.incoming;
  final fileOutgoingPeers = filePeers.outgoing;
  // Draw folder containers with hierarchy visualization
  _drawHierarchicalFolders(
    buffer,
    drawOrder,
    folderPositions,
    folderDimensions,
    folderMetrics,
    fileMetrics,
    relativeGraph,
    fileAnchors,
    titleVisuals,
    fileVisuals,
    folderBadges,
    folderIncomingPeers,
    folderOutgoingPeers,
    fileIncomingPeers,
    fileOutgoingPeers,
    depthMap,
    headerHeight: folderHeaderHeight,
    fileItemHeight: fileItemHeight,
    fileItemSpacing: fileItemSpacing,
    fileTopPadding: fileTopPadding,
    projectName: projectName,
    projectVersion: projectVersion,
    inputFolderName: inputFolderName,
  );

  // Calculate the horizontal start of the folder column and file lane for aligned vertical edges
  final leftLaneGutterX = margin + folderEdgeExtraWidth;
  final rightLaneGutterX = margin + folderEdgeExtraWidth + rootSize.width;

  // Draw inter-folder dependency edges between backgrounds and badges
  _drawEdgeVerticalFolders(
    buffer,
    folderDependencies,
    folderPositions,
    folderDimensions,
    folderDepGraph,
    globalGutterX: leftLaneGutterX,
    rootPath: rootNode.fullPath,
  );

  // Draw folder badges above dependency edges
  _drawFolderBadges(buffer, folderBadges);

  // Draw file background pills first
  _drawFilePanels(buffer, fileVisuals);

  // Draw file-to-file dependency edges
  _drawEdgeVerticalsFiles(
    buffer,
    relativeGraph,
    fileAnchors,
    folderLevels,
    rightLaneGutterX: rightLaneGutterX,
  );

  // Draw badges and labels after edges for correct stacking
  _drawFileVisuals(buffer, fileVisuals);
  _drawTitleVisuals(buffer, titleVisuals);

  buffer.writeln('</svg>');
  return buffer.toString();
}

/// Build hierarchical folder structure from file paths
FolderNode _buildFolderHierarchy(List<String> filePaths) {
  if (filePaths.isEmpty) return FolderNode('.', '.', [], []);

  // If all files share the same top-level folder, use it as the root; otherwise use "."
  final commonTop = _commonTopLevelSegment(filePaths);
  final rootName = commonTop ?? '.';
  final rootPath = rootName;
  final startOffset = commonTop == null ? 0 : 1;

  final root = FolderNode(rootName, rootPath, [], []);

  for (final filePath in filePaths) {
    final parts = filePath.split('/');
    if (parts.length <= startOffset) continue;

    FolderNode current = root;
    String currentPath = rootPath == '.' ? '' : rootPath;

    // Build hierarchy path from the first non-root segment
    for (var i = startOffset; i < parts.length - 1; i++) {
      final folderName = parts[i];
      final folderPath =
          currentPath.isEmpty ? folderName : '$currentPath/$folderName';

      var child = current.children.firstWhere(
        (f) => f.name == folderName,
        orElse: () {
          final newChild = FolderNode(folderName, folderPath, [], []);
          current.children.add(newChild);
          return newChild;
        },
      );

      current = child;
      currentPath = folderPath;
    }

    // Add file to the deepest folder (use full relative path as identity)
    if (!current.files.contains(filePath)) {
      current.files.add(filePath);
    }
  }

  // Apply loose files rule: create virtual subfolders for folders with both files and subfolders
  _applyLooseFilesRule(root);

  return root;
}

/// Apply the loose files rule: create virtual subfolders for folders with both files and subfolders.
///
/// This rule ensures that files directly inside a folder are rendered in a dedicated
/// "virtual" subfolder (labeled "...") when that same folder also contains other
/// sub-directories. This resolves visual ambiguity in hierarchical layouts by
/// treating loose files as a distinct sibling to other sub-folders.
void _applyLooseFilesRule(FolderNode node) {
  // Process children first (bottom-up)
  for (final child in node.children) {
    _applyLooseFilesRule(child);
  }

  // If this folder has both files and subfolders, create a virtual subfolder for the loose files
  if (node.files.isNotEmpty && node.children.isNotEmpty) {
    // Create a virtual subfolder for the loose files
    final virtualFolderName = '...';
    final virtualFolderPath = node.fullPath == '.'
        ? virtualFolderName
        : '${node.fullPath}/$virtualFolderName';
    // Create a copy of the files list for the virtual folder
    final virtualFolderFiles = List<String>.from(node.files);
    final virtualFolder = FolderNode(
        virtualFolderName, virtualFolderPath, [], virtualFolderFiles,
        isVirtual: true);

    // Clear the files from the parent folder
    node.files.clear();

    // Insert the virtual folder at the beginning (above all other subfolders)
    node.children.insert(0, virtualFolder);
  }
}

/// Find the actual folder path where a file ends up, considering virtual subfolders.
///
/// This method determines the effective container for a file in the visualization.
/// It distinguishes between internal and external dependencies to correctly route
/// edges:
/// - External connections (between different parent folders) roll up to the
///   top-level branch folders under their Lowest Common Ancestor.
/// - Internal connections (within the same parent sub-tree) use the precise
///   location, including virtual "..." subfolders if applicable.
String _getActualFolderPath(
    String filePath, FolderNode rootNode, String? targetFilePath) {
  // If no target is specified, just return the folder where the file actually is
  if (targetFilePath == null) {
    return _getDeepestFolderPath(filePath, rootNode);
  }

  // Find lowest common ancestor
  final sourceParts = filePath.split('/');
  final targetParts = targetFilePath.split('/');
  int commonDepth = 0;
  while (commonDepth < sourceParts.length - 1 &&
      commonDepth < targetParts.length - 1 &&
      sourceParts[commonDepth] == targetParts[commonDepth]) {
    commonDepth++;
  }

  // Find common path segments
  final commonPathParts = sourceParts.sublist(0, commonDepth);

  // Navigate to the common ancestor node
  FolderNode commonNode = rootNode;
  for (final part in commonPathParts) {
    commonNode = commonNode.children.firstWhere(
      (f) => f.name == part,
      orElse: () => commonNode,
    );
  }

  // Determine which branch to return for the source file
  if (commonDepth >= sourceParts.length - 1) {
    // Source file is directly in commonNode (loose file)
    // Return the virtual folder of commonNode if it exists
    final virtual = commonNode.children.where((f) => f.isVirtual).firstOrNull;
    return virtual?.fullPath ?? commonNode.fullPath;
  } else {
    // Source file is in a sub-branch of commonNode
    // Return the direct child of commonNode that leads to source file
    final branchName = sourceParts[commonDepth];
    final branch = commonNode.children.firstWhere(
      (f) => f.name == branchName,
      orElse: () => commonNode,
    );
    return branch.fullPath;
  }
}

/// Helper to find the actual deepest folder containing a file (including virtual folders).
String _getDeepestFolderPath(String filePath, FolderNode rootNode) {
  if (!filePath.contains('/')) return rootNode.fullPath;
  final parts = filePath.split('/');
  FolderNode current = rootNode;
  for (var i = 0; i < parts.length - 1; i++) {
    final folderName = parts[i];
    current = current.children.firstWhere(
      (f) => f.name == folderName,
      orElse: () => current,
    );
  }
  if (current.files.contains(filePath)) return current.fullPath;
  for (final child in current.children) {
    if (child.isVirtual && child.files.contains(filePath)) {
      return child.fullPath;
    }
  }
  return _getFolderPath(filePath, rootNode.fullPath);
}

/// Calculate dependency metrics for hierarchical folders
Map<String, Map<String, int>> _calculateFolderMetrics(
    Map<String, List<String>> dependencyGraph, FolderNode rootNode) {
  final folderMetrics = <String, Map<String, int>>{};
  final seenEdges = <String>{};

  // Initialize all folders
  _initializeFolderMetrics(rootNode, folderMetrics);

  // Calculate cross-folder dependencies
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final targetFiles = entry.value;

    for (final targetFile in targetFiles) {
      // Use the actual folder paths considering hierarchical roll-ups
      final sourceFolder =
          _getActualFolderPath(sourceFile, rootNode, targetFile);
      final targetFolder =
          _getActualFolderPath(targetFile, rootNode, sourceFile);

      if (sourceFolder != targetFolder) {
        final edgeKey = '$sourceFolder->$targetFolder';
        if (seenEdges.add(edgeKey)) {
          folderMetrics.putIfAbsent(
              sourceFolder, () => {'incoming': 0, 'outgoing': 0});
          folderMetrics.putIfAbsent(
              targetFolder, () => {'incoming': 0, 'outgoing': 0});

          folderMetrics[sourceFolder]!['outgoing'] =
              (folderMetrics[sourceFolder]!['outgoing'] ?? 0) + 1;
          folderMetrics[targetFolder]!['incoming'] =
              (folderMetrics[targetFolder]!['incoming'] ?? 0) + 1;
        }
      }
    }
  }

  return folderMetrics;
}

/// Computes folder levels based on hard dependency constraints and consumption strength.
///
/// This implements the spec's two-phase ordering rules:
/// Phase 1: Hard dependency constraints - consumers must be above providers
/// Phase 2: Consumption strength ordering - higher consumers go above lower consumers
Map<String, int> _computeFolderLevels(
    Map<String, List<String>> dependencyGraph, FolderNode rootNode) {
  // Step 1: Build global folder consumption graph using actual folder paths
  final consumes = <String, Map<String, int>>{};
  final allFolders = <String>{};

  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    for (final target in entry.value) {
      final sourceFolder = _getActualFolderPath(sourceFile, rootNode, target);
      final targetFolder = _getActualFolderPath(target, rootNode, sourceFile);
      allFolders.add(sourceFolder);
      allFolders.add(targetFolder);

      if (sourceFolder != targetFolder) {
        consumes.putIfAbsent(sourceFolder, () => <String, int>{});
        consumes[sourceFolder]![targetFolder] =
            (consumes[sourceFolder]![targetFolder] ?? 0) + 1;
      }
    }
  }

  // Ensure all project folders are included
  _collectAllFolders(rootNode, allFolders);

  // Step 2: Global Layered Topological Sort
  final adj = <String, Set<String>>{};
  final indeg = <String, int>{};
  for (final folder in allFolders) {
    adj[folder] = <String>{};
    indeg[folder] = 0;
  }

  for (final source in allFolders) {
    for (final target in (consumes[source]?.keys ?? <String>{})) {
      if (allFolders.contains(target)) {
        adj[source]!.add(target);
        indeg[target] = (indeg[target] ?? 0) + 1;
      }
    }
  }

  int getGroupOut(String folder, Set<String> activeNodes) {
    var out = 0;
    for (final target in consumes[folder]?.keys ?? <String>{}) {
      if (activeNodes.contains(target)) {
        out += consumes[folder]![target]!;
      }
    }
    return out;
  }

  final levels = <String, int>{};
  final remainingNodes = Set<String>.from(allFolders);
  var currentLevel = 0;

  while (remainingNodes.isNotEmpty) {
    // Collect all nodes that have no incoming edges from REMAINING nodes
    var ready = remainingNodes.where((n) => (indeg[n] ?? 0) == 0).toList();

    if (ready.isEmpty) {
      // Cycle detected - pick the "strongest" consumer among the remaining nodes with least indegree
      final minIndeg = remainingNodes
          .map((n) => indeg[n] ?? 0)
          .reduce((a, b) => a < b ? a : b);
      final candidates =
          remainingNodes.where((n) => indeg[n] == minIndeg).toList();
      candidates.sort((a, b) => getGroupOut(b, remainingNodes)
          .compareTo(getGroupOut(a, remainingNodes)));
      ready = [candidates.first];
    }

    // Sort ready nodes by consumption strength (Phase 2) for deterministic sub-ordering
    ready.sort((a, b) {
      final diff = getGroupOut(b, remainingNodes)
          .compareTo(getGroupOut(a, remainingNodes));
      if (diff != 0) return diff;
      return a.compareTo(b);
    });

    // Assign all ready nodes to the CURRENT level (Layered Ranking)
    for (final folder in ready) {
      levels[folder] = currentLevel;
      remainingNodes.remove(folder);

      // Remove edges
      for (final neighbor in adj[folder]!) {
        indeg[neighbor] = (indeg[neighbor] ?? 1) - 1;
      }
    }

    currentLevel++;
  }

  return levels;
}

/// Recursively collect all folder paths in the hierarchy.
void _collectAllFolders(FolderNode node, Set<String> allFolders) {
  allFolders.add(node.fullPath);
  for (final child in node.children) {
    _collectAllFolders(child, allFolders);
  }
}

/// Calculate per-file incoming/outgoing counts.
Map<String, Map<String, int>> _calculateFileMetrics(
    Map<String, List<String>> dependencyGraph) {
  final metrics = <String, Map<String, int>>{};

  void ensureEntry(String file) {
    metrics.putIfAbsent(file, () => {'incoming': 0, 'outgoing': 0});
  }

  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    ensureEntry(source);
    metrics[source]!['outgoing'] =
        (metrics[source]!['outgoing'] ?? 0) + entry.value.length;

    for (final target in entry.value) {
      ensureEntry(target);
      metrics[target]!['incoming'] = (metrics[target]!['incoming'] ?? 0) + 1;
    }
  }

  return metrics;
}

/// Initialize metrics for all folders in hierarchy
void _initializeFolderMetrics(
    FolderNode node, Map<String, Map<String, int>> metrics) {
  metrics[node.fullPath] = {'incoming': 0, 'outgoing': 0};

  for (final child in node.children) {
    _initializeFolderMetrics(child, metrics);
  }
}

/// Recursively measure folder containers so parents can fit their children.
Rect _computeFolderDimensions(
  FolderNode node,
  Map<String, Rect> dimensions, {
  required double labelWidth,
  Map<String, int>? folderLevels,
  required double baseWidth,
  required double padding,
  required double childIndent,
  required double childSpacing,
  required double headerHeight,
  required double fileItemHeight,
  required double fileItemSpacing,
  required double fileTopPadding,
  required double filesToChildrenSpacing,
}) {
  double maxChildWidth = 0;
  double childrenHeight = 0;

  final children = folderLevels == null
      ? node.children
      : (List<FolderNode>.from(node.children)
        ..sort((a, b) {
          // Virtual folders ("...") are always positioned above regular subfolders
          if (a.isVirtual && !b.isVirtual) return -1;
          if (!a.isVirtual && b.isVirtual) return 1;

          // Otherwise follow dependency levels
          return (folderLevels[a.fullPath] ?? 0)
              .compareTo(folderLevels[b.fullPath] ?? 0);
        }));

  for (var i = 0; i < children.length; i++) {
    final childRect = _computeFolderDimensions(
      children[i],
      dimensions,
      labelWidth: labelWidth,
      folderLevels: folderLevels,
      baseWidth: baseWidth,
      padding: padding,
      childIndent: childIndent,
      childSpacing: childSpacing,
      headerHeight: headerHeight,
      fileItemHeight: fileItemHeight,
      fileItemSpacing: fileItemSpacing,
      fileTopPadding: fileTopPadding,
      filesToChildrenSpacing: filesToChildrenSpacing,
    );

    maxChildWidth = max(maxChildWidth, childRect.width);
    childrenHeight += childRect.height;
    if (i < node.children.length - 1) {
      childrenHeight += childSpacing;
    }
  }

  final filesHeight = node.files.isEmpty
      ? 0.0
      : (node.files.length * fileItemHeight) +
          ((node.files.length - 1) * fileItemSpacing) +
          fileTopPadding;

  double height = headerHeight + filesHeight + padding;
  if (node.children.isNotEmpty) {
    height += (filesHeight > 0 ? filesToChildrenSpacing : fileTopPadding);
    height += childrenHeight;
    height += padding; // Bottom padding under the children block
  }

  /// Extra room for text + badges + margins.
  const double fileRowBadgeSpace = 50.0;
  final fileRowWidth = labelWidth + fileRowBadgeSpace;

  var width = max(baseWidth, fileRowWidth);

  /// Multiplier for padding when calculating total width.
  const double paddingMultiplier = 2.0;
  if (node.children.isNotEmpty) {
    width =
        max(width, childIndent + maxChildWidth + (padding * paddingMultiplier));
  }

  final rect = Rect.fromLTWH(0.0, 0.0, width, height);
  dimensions[node.fullPath] = rect;

  // Match children's width to the parent's interior width for a clean flush look
  if (children.isNotEmpty) {
    final innerWidth = width - (padding * paddingMultiplier) - childIndent;
    for (final child in children) {
      final oldRect = dimensions[child.fullPath]!;
      dimensions[child.fullPath] =
          Rect.fromLTWH(0, 0, innerWidth, oldRect.height);
    }
  }

  return rect;
}

/// Assign absolute positions so each child renders inside its parent.
void _positionFolders(
  FolderNode node,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions, {
  required Map<String, int> folderLevels,
  required double startX,
  required double startY,
  required double padding,
  required double childIndent,
  required double childSpacing,
  required double headerHeight,
  required double fileItemHeight,
  required double fileItemSpacing,
  required double fileTopPadding,
  required double filesToChildrenSpacing,
}) {
  positions[node.fullPath] = Point(startX, startY);

  var childStartY = startY + headerHeight;

  // Add file space for all folders (including virtual folders)
  if (node.files.isNotEmpty) {
    childStartY += fileTopPadding +
        (node.files.length * fileItemHeight) +
        ((node.files.length - 1) * fileItemSpacing) +
        filesToChildrenSpacing;
  } else if (node.children.isNotEmpty) {
    childStartY += fileTopPadding;
  }

  var currentChildY = childStartY;
  final childX = startX + padding + childIndent;

  final sortedChildren = List<FolderNode>.from(node.children)
    ..sort((a, b) {
      // Virtual folders ("...") are always positioned above regular subfolders
      if (a.isVirtual && !b.isVirtual) return -1;
      if (!a.isVirtual && b.isVirtual) return 1;

      // Otherwise follow dependency levels
      return (folderLevels[a.fullPath] ?? 0)
          .compareTo(folderLevels[b.fullPath] ?? 0);
    });

  for (final child in sortedChildren) {
    _positionFolders(
      child,
      positions,
      dimensions,
      folderLevels: folderLevels,
      startX: childX,
      startY: currentChildY,
      padding: padding,
      childIndent: childIndent,
      childSpacing: childSpacing,
      headerHeight: headerHeight,
      fileItemHeight: fileItemHeight,
      fileItemSpacing: fileItemSpacing,
      fileTopPadding: fileTopPadding,
      filesToChildrenSpacing: filesToChildrenSpacing,
    );

    final childRect = dimensions[child.fullPath]!;
    currentChildY += childRect.height + childSpacing;
  }
}

/// Depth-first traversal so parents draw before their nested children.
List<FolderNode> _collectDepthFirst(FolderNode root) {
  final ordered = <FolderNode>[];

  void visit(FolderNode node) {
    ordered.add(node);
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(root);
  return ordered;
}

/// Compute depth of each folder node (root = 0).
Map<String, int> _computeDepths(FolderNode root) {
  final depths = <String, int>{};

  void visit(FolderNode node, int depth) {
    depths[node.fullPath] = depth;
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  visit(root, 0);
  return depths;
}

/// Get folder path from file path (preserving hierarchy)
String _getFolderPath(String filePath, String rootPath) {
  if (!filePath.contains('/')) {
    return rootPath;
  }

  final lastSlash = filePath.lastIndexOf('/');
  return filePath.substring(0, lastSlash);
}

/// Draw hierarchical edges between parent and child folders
void _drawEdgeHorizontalCurve(StringBuffer buffer, List<FolderNode> folders,
    Map<String, Point<double>> positions, Map<String, Rect> dimensions,
    {required double padding, required double childIndent}) {
  for (final folder in folders) {
    for (final child in folder.children) {
      if (!positions.containsKey(folder.fullPath) ||
          !positions.containsKey(child.fullPath)) {
        continue;
      }

      final parentPos = positions[folder.fullPath]!;
      final childPos = positions[child.fullPath]!;
      final childDim = dimensions[child.fullPath]!;

      /// Divisor for halving dimensions.
      const double halfDivisor = 2.0;

      /// Horizontal offset for the edge connection point.
      const double edgeHorizontalOffset = 8.0;

      final parentX = parentPos.x + padding + (childIndent / halfDivisor);
      final parentY = childPos.y + (childDim.height / halfDivisor);
      final childX = childPos.x - edgeHorizontalOffset;
      final childY = childPos.y + (childDim.height / halfDivisor);

      // Control points for a gentle left-to-right curve within the parent box
      final controlX1 = parentX + (childIndent / halfDivisor);
      final controlX2 = childX - (childIndent / halfDivisor);
      final pathData = 'M $parentX $parentY '
          'C $controlX1 $parentY, $controlX2 $childY, $childX $childY';

      renderEdgeWithTooltip(
        buffer,
        pathData: pathData,
        source: folder.name,
        target: child.name,
        cssClass: 'edgeVertical',
      );
    }
  }
}

/// Collect unique folder-to-folder dependency edges.
List<_FolderEdge> _collectFolderDependencies(
    Map<String, List<String>> dependencyGraph, FolderNode rootNode) {
  final edges = <_FolderEdge>[];
  final seen = <String>{};

  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final targetFiles = entry.value;

    for (final targetFile in targetFiles) {
      // Get actual folder paths considering virtual subfolders
      final sourceFolder =
          _getActualFolderPath(sourceFile, rootNode, targetFile);
      final targetFolder =
          _getActualFolderPath(targetFile, rootNode, sourceFile);

      if (sourceFolder == targetFolder) continue;

      final key = '$sourceFolder->$targetFolder';
      if (seen.add(key)) {
        edges.add(_FolderEdge(sourceFolder, targetFolder));
      }
    }
  }

  return edges;
}

/// Detect cycles in a directed graph and return a set of edges that are part of at least one cycle.
/// This uses Tarjan's bridge-finding concepts or SCC detection for more robust marking.
Set<String> _detectCyclesInGraph(Map<String, List<String>> graph) {
  final Set<String> cycleEdges = <String>{};
  final List<List<String>> sccs = _findSCCs(graph);

  for (final scc in sccs) {
    if (scc.length > 1) {
      // All edges between nodes within this SCC are part of a cycle
      for (final node in scc) {
        for (final neighbor in graph[node] ?? []) {
          if (scc.contains(neighbor)) {
            cycleEdges.add('$node->$neighbor');
          }
        }
      }
    } else if (scc.isNotEmpty) {
      // Check for self-loops
      final node = scc.first;
      if (graph[node]?.contains(node) ?? false) {
        cycleEdges.add('$node->$node');
      }
    }
  }

  return cycleEdges;
}

/// Find Strongly Connected Components using Tarjan's algorithm.
List<List<String>> _findSCCs(Map<String, List<String>> graph) {
  final List<List<String>> sccs = [];
  final Map<String, int> index = {};
  final Map<String, int> lowlink = {};
  final List<String> stack = [];
  final Set<String> onStack = {};
  int time = 0;

  void strongConnect(String v) {
    index[v] = time;
    lowlink[v] = time;
    time++;
    stack.add(v);
    onStack.add(v);

    for (final w in graph[v] ?? []) {
      if (!index.containsKey(w)) {
        strongConnect(w);
        lowlink[v] = min(lowlink[v]!, lowlink[w]!);
      } else if (onStack.contains(w)) {
        lowlink[v] = min(lowlink[v]!, index[w]!);
      }
    }

    if (lowlink[v] == index[v]) {
      final List<String> scc = [];
      String w;
      do {
        w = stack.removeLast();
        onStack.remove(w);
        scc.add(w);
      } while (w != v);
      sccs.add(scc);
    }
  }

  for (final node in graph.keys) {
    if (!index.containsKey(node)) {
      strongConnect(node);
    }
  }

  return sccs;
}

/// Determine the CSS class for an edge based on its properties.
String _getEdgeCssClass(
  String sourceFolder,
  String targetFolder,
  double startY,
  double endY,
  Set<String> cycleEdges,
) {
  final edgeKey = '$sourceFolder->$targetFolder';

  // Priority rule: Red (cycle) > Orange (upward) > Default (gradient)
  if (cycleEdges.contains(edgeKey)) {
    return 'cycleEdge';
  } else if (startY > endY) {
    return 'warningEdge';
  } else {
    return 'edgeVertical';
  }
}

/// Draw edges between files based on dependency graph.
void _drawEdgeVerticalsFiles(
  StringBuffer buffer,
  Map<String, List<String>> graph,
  Map<String, Map<String, Point<double>>> anchors,
  Map<String, int> _, // folderLevels
  {
  double? rightLaneGutterX,
}) {
  var edgeCounter = 0;
  final cycleEdges = _detectCyclesInGraph(graph);
  for (final entry in graph.entries) {
    final source = entry.key;
    final targets = entry.value;
    final sourceAnchor = anchors[source]?['out'];
    if (sourceAnchor == null) continue;

    for (final target in targets) {
      final targetAnchor = anchors[target]?['in'];
      if (targetAnchor == null) continue;

      final startX = sourceAnchor.x;
      final startY = sourceAnchor.y;
      final endX = targetAnchor.x;
      final endY = targetAnchor.y;

      /// Base offset for the gutter lane.
      const double gutterBaseOffset = 28.0;

      /// Step width for each subsequent edge in the gutter.
      const double gutterStepWidth = 4.0;

      // Calculate fixed vertical column X for the right lane gutter if reference is provided
      final double? fixedColumnX = rightLaneGutterX != null
          ? (rightLaneGutterX +
              gutterBaseOffset +
              edgeCounter * gutterStepWidth)
          : null;

      final path = _buildStackedEdgePath(
          startX, startY, endX, endY, edgeCounter,
          isLeft: false, fixedColumnX: fixedColumnX);

      /// Vertical offset to recover the original file Y-coordinate (upward).
      const double fileYOffsetUp = 6.0;

      /// Vertical offset to recover the original file Y-coordinate (downward).
      const double fileYOffsetDown = 5.0;

      // Determine the appropriate CSS class based on edge properties
      // Use the actual file top y-coordinate (fileY) for upward detection to avoid badge-offset bias
      final cssClass = _getEdgeCssClass(
        source,
        target,
        startY - fileYOffsetUp, // fileY
        endY + fileYOffsetDown, // fileY
        cycleEdges,
      );

      renderEdgeWithTooltip(
        buffer,
        pathData: path,
        source: source,
        target: target,
        cssClass: cssClass,
      );
      edgeCounter++;
    }
  }
}

/// Draw folder-level dependency edges routed on the left side of folders.
void _drawEdgeVerticalFolders(
  StringBuffer buffer,
  List<_FolderEdge> edges,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions,
  Map<String, List<String>> dependencyGraph, {
  required double globalGutterX,
  required String rootPath,
}) {
  if (edges.isEmpty) return;

  // Detect cycles in the folder dependency graph
  final cycleEdges = _detectCyclesInGraph(dependencyGraph);

  // Group edges by their common parent path to create local gutters
  final edgesByParent = <String, List<_FolderEdge>>{};
  for (final edge in edges) {
    // Both folders are siblings due to hierarchical roll-up, so they share a parent
    final parentPath = _getFolderPath(edge.sourceFolder, rootPath);
    edgesByParent.putIfAbsent(parentPath, () => []).add(edge);
  }

  for (final entry in edgesByParent.entries) {
    final parentPath = entry.key;
    final parentEdges = entry.value;
    final parentPos = positions[parentPath];

    for (var i = 0; i < parentEdges.length; i++) {
      final edge = parentEdges[i];
      final sourcePos = positions[edge.sourceFolder];
      final targetPos = positions[edge.targetFolder];
      final sourceDim = dimensions[edge.sourceFolder];
      final targetDim = dimensions[edge.targetFolder];

      if (sourcePos == null ||
          targetPos == null ||
          sourceDim == null ||
          targetDim == null) {
        continue;
      }

      // Start/end at badge centers.
      const double sourceBadgeOffsetX = 6.0;
      const double sourceBadgeOffsetY = 24.0;
      const double targetBadgeOffsetX = 10.0;
      const double targetBadgeOffsetY = 13.0;

      final startX = sourcePos.x + sourceBadgeOffsetX;
      final startY = sourcePos.y + sourceBadgeOffsetY;
      final endX = targetPos.x + targetBadgeOffsetX;
      final endY = targetPos.y + targetBadgeOffsetY;

      // Calculate fixed vertical column X
      // If parent exists, use its internal lane (indentation area)
      // If root, use the global lane (outside root)
      double fixedColumnX;
      if (parentPos != null) {
        /// Width of each edge lane in the stack.
        const double stackStepWidth = 4.0;

        /// Horizontal offset for the lane within the parent folder.
        const double laneInternalOffset = 24.0;

        /// Width of the indentation area.
        const double indentWidth = 40.0;

        /// Divisor for halving dimensions.
        const double halfDivisor = 2.0;

        // Center the stack of edges within the 40px childIndent area for balanced padding.
        // Gap starts at parentPos.x + 24.0 (border+padding) and ends at parentPos.x + 64.0 (start of children).
        final stackWidth = (parentEdges.length - 1) * stackStepWidth;
        final stackStartX = parentPos.x +
            laneInternalOffset +
            (indentWidth / halfDivisor) -
            (stackWidth / halfDivisor);
        fixedColumnX = stackStartX + (i * stackStepWidth);
      } else {
        /// Base margin for the global gutter.
        const double globalGutterMargin = 40.0;

        /// Step width for global lane stacking.
        const double globalStackStepWidth = 4.0;

        // Step LEFT from the global gutter with a comfortable 40px base margin.
        fixedColumnX =
            globalGutterX - globalGutterMargin - (i * globalStackStepWidth);
      }

      // Folder edges use the LEFT lane (relative to the badges)
      final pathData = _buildStackedEdgePath(startX, startY, endX, endY, i,
          isLeft: true, fixedColumnX: fixedColumnX);

      final cssClass = _getEdgeCssClass(
        edge.sourceFolder,
        edge.targetFolder,
        sourcePos.y,
        targetPos.y,
        cycleEdges,
      );

      renderEdgeWithTooltip(
        buffer,
        pathData: pathData,
        source: edge.sourceFolder,
        target: edge.targetFolder,
        cssClass: cssClass,
      );
    }
  }
}

/// Render folder badges after edges so they sit on top.
void _drawFolderBadges(StringBuffer buffer, List<BadgeModel> badges) {
  for (final b in badges) {
    renderTriangularBadge(buffer, b);
  }
}

/// Draw hierarchical folder containers
void _drawHierarchicalFolders(
  StringBuffer buffer,
  List<FolderNode> folders,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions,
  Map<String, Map<String, int>> metrics,
  Map<String, Map<String, int>> fileMetrics,
  Map<String, List<String>> dependencyGraph,
  Map<String, Map<String, Point<double>>> fileAnchors,
  List<_TitleVisual> titleVisuals,
  List<_FileVisual> fileVisuals,
  List<BadgeModel> folderBadges,
  Map<String, List<String>> folderIncomingPeers,
  Map<String, List<String>> folderOutgoingPeers,
  Map<String, List<String>> fileIncomingPeers,
  Map<String, List<String>> fileOutgoingPeers,
  Map<String, int> depths, {
  required double headerHeight,
  required double fileItemHeight,
  required double fileItemSpacing,
  required double fileTopPadding,
  required String projectName,
  required String projectVersion,
  required String inputFolderName,
}) {
  void drawFolder(FolderNode folder) {
    final pos = positions[folder.fullPath]!;
    final dim = dimensions[folder.fullPath]!;
    final folderMetrics =
        metrics[folder.fullPath] ?? {'incoming': 0, 'outgoing': 0};
    final incoming = folderMetrics['incoming'] ?? 0;
    final outgoing = folderMetrics['outgoing'] ?? 0;
    final depth = depths[folder.fullPath] ?? 0;

    /// Corner radius for folder rectangles.
    const double folderCornerRadius = 12.0;

    /// Divisor for halving dimensions.
    const double halfDivisor = 2.0;

    /// Vertical offset for the folder title text.
    const double titleVerticalOffset = 25.0;

    buffer.writeln('<g class="folderLayer">');
    if (folder.isVirtual) {
      /// Dash array for virtual folder borders.
      const String virtualFolderDashArray = '4 2';

      // Render virtual folder with dash-dot border
      buffer.writeln(
          '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="$folderCornerRadius" ry="$folderCornerRadius" class="layerBackgroundVirtualFolder" stroke-dasharray="$virtualFolderDashArray"/>');
    } else {
      // Render regular folder with solid border
      buffer.writeln(
          '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="$folderCornerRadius" ry="$folderCornerRadius" class="layerBackground"/>');
    }

    final indentLevels = depth > 0 ? depth : 0;
    final indent = List.filled(indentLevels, '  ').join();

    // For root folder (depth 0), show project info instead of folder name
    String titleText;
    if (depth == 0 && folder.name == '.') {
      // Show project name and version, omit folder name if it matches project name
      if (inputFolderName.toLowerCase() == projectName.toLowerCase()) {
        titleText = '$projectName v$projectVersion';
      } else {
        titleText = '$inputFolderName ($projectName v$projectVersion)';
      }
    } else {
      titleText = '$indent${folder.name}';
    }

    /// Horizontal padding reserved for folder title labels.
    const double folderTitleHorizontalPadding = 24.0;
    final titleMaxWidth =
        max(1.0, dim.width - (folderTitleHorizontalPadding * halfDivisor));
    titleVisuals.add(_TitleVisual(pos.x + dim.width / halfDivisor,
        pos.y + titleVerticalOffset, titleText, titleMaxWidth));
    buffer.writeln('</g>');

    /// Horizontal offset for the target (incoming) badge.
    const double targetBadgeOffsetX = 10.0;

    /// Vertical offset for the target (incoming) badge.
    const double targetBadgeOffsetY = 13.0;

    /// Horizontal offset for the source (outgoing) badge.
    const double sourceBadgeOffsetX = 6.0;

    /// Vertical offset for the source (outgoing) badge.
    const double sourceBadgeOffsetY = 24.0;

    folderBadges.add(BadgeModel.incoming(
      cx: pos.x + targetBadgeOffsetX,
      cy: pos.y + targetBadgeOffsetY,
      count: incoming,
      peers: folderIncomingPeers[folder.fullPath] ?? const [],
      direction: BadgeDirection.east, // ▶
    ));
    folderBadges.add(BadgeModel.outgoing(
      cx: pos.x + sourceBadgeOffsetX,
      cy: pos.y + sourceBadgeOffsetY,
      count: outgoing,
      peers: folderOutgoingPeers[folder.fullPath] ?? const [],
      direction: BadgeDirection.west, // ◀
    ));

    final sortedFiles =
        _sortFiles(folder.files, folder.fullPath, fileMetrics, dependencyGraph);
    final List<Point<double>> filePositions = _calculateFilePositions(
      sortedFiles.length,
      0, // compute positions relative to folder top
      headerHeight: headerHeight,
      topPadding: fileTopPadding,
      itemHeight: fileItemHeight,
      itemSpacing: fileItemSpacing,
      startX: 0.0,
    );

    // Draw children after this folder so they appear on top
    for (final child in folder.children) {
      drawFolder(child);
    }

    // Collect file visuals; badges/text drawn later after edges
    // Process files for all folders (including virtual folders)
    if (folder.files.isNotEmpty) {
      for (var j = 0; j < sortedFiles.length; j++) {
        final file = sortedFiles[j];
        final filePos = filePositions[j];

        final fileY = pos.y + filePos.y;
        final filePath = file; // Already the original relative path
        final fileName = file.split('/').last;

        final fIncoming = fileMetrics[filePath]?['incoming'] ?? 0;
        final fOutgoing = fileMetrics[filePath]?['outgoing'] ?? 0;

        /// Horizontal margin for the file panel inside the folder.
        const double panelMarginX = 8.0;

        /// Multiplier to calculate total horizontal padding for the panel.
        const double panelPaddingMultiplier = 2.0;

        /// Vertical offset to recover the original file Y-coordinate (upward).
        const double fileYOffsetUp = 5.0;

        /// Vertical offset to recover the original file Y-coordinate (downward).
        const double fileYOffsetDown = 6.0;

        /// Offset for the outgoing badge anchor.
        const double outgoingAnchorOffset = 4.0;

        final panelX = pos.x + panelMarginX;
        final panelWidth = dim.width -
            (panelMarginX * panelPaddingMultiplier); // flush within folder
        final textX = pos.x + (panelWidth / halfDivisor);
        // Use panel-based coordinates for badges and edge anchors.
        final badgeX =
            panelX + panelWidth - panelMarginX; // align with folder badges
        fileAnchors[filePath] = {
          'in': Point(badgeX, fileY - fileYOffsetUp), // Incoming badge position
          'out': Point(badgeX + outgoingAnchorOffset,
              fileY + fileYOffsetDown), // Outgoing
        };

        final incomingPeers = fileIncomingPeers[filePath] ?? const [];
        final outgoingPeers = fileOutgoingPeers[filePath] ?? const [];

        fileVisuals.add(_FileVisual(
            path: filePath,
            name: fileName,
            textX: textX,
            textY: fileY,
            badgeX: badgeX,
            badgeY: fileY,
            panelX: panelX,
            panelWidth: panelWidth,
            incoming: fIncoming,
            outgoing: fOutgoing,
            incomingPeers: incomingPeers,
            outgoingPeers: outgoingPeers));
      }
    }
  }

  // Start recursive draw from root (first element is root)
  if (folders.isNotEmpty) {
    drawFolder(folders.first);
  }
}

/// Build a directional edge with stacked columns, handling both left and right lanes.
String _buildStackedEdgePath(
  double startX,
  double startY,
  double endX,
  double endY,
  int edgeIndex, {
  required bool isLeft,
  double? fixedColumnX,
}) {
  const double baseOffset = 28.0;
  const double radius = 6.0;
  final dirY = endY >= startY ? 1.0 : -1.0;
  final dirX = isLeft ? -1.0 : 1.0;

  // Each edge gets a slightly larger offset to avoid overlapping runs.
  // Folder edges (isLeft=true) route to the left lane, File edges to the right.
  /// Step width for each subsequent edge in the gutter.
  const double gutterStepWidth = 4.0;

  final columnX = fixedColumnX ??
      (startX + (dirX * baseOffset) + (dirX * edgeIndex * gutterStepWidth));

  final preCurveX = columnX - (dirX * radius);
  final postCurveX = columnX - (dirX * radius);
  final firstQx = columnX;
  final firstQy = startY + dirY * radius;

  final secondVy = endY - dirY * radius;
  final secondQy = endY;

  return 'M $startX $startY '
      'H $preCurveX '
      'Q $firstQx $startY $firstQx $firstQy '
      'V $secondVy '
      'Q $firstQx $secondQy $postCurveX $secondQy '
      'H $endX';
}

/// Render file badges and labels (after edges).
void _drawFileVisuals(StringBuffer buffer, List<_FileVisual> visuals) {
  const double fileLabelBaseFontSize = 14.0;
  const double fileLabelMinFontSize = 6.0;
  const double fileLabelHorizontalPadding = 16.0;

  for (final v in visuals) {
    /// Half-height offset of the file panel.
    const double filePanelHalfHeight = 14.0;

    /// Height of the file panel.
    const double filePanelHeight = 28.0;

    /// Divisor for halving dimensions.
    const double halfDivisor = 2.0;

    final top = v.textY - filePanelHalfHeight;

    /// Vertical offset to recover the original file Y-coordinate (upward).
    const double incomingBadgeOffsetY = 5.0;

    // Create incoming badge (pointing west)
    final incomingBadge = BadgeModel.incoming(
      cx: v.badgeX,
      cy: v.badgeY - incomingBadgeOffsetY,
      count: v.incoming,
      peers: v.incomingPeers,
      direction: BadgeDirection.west,
    );
    renderTriangularBadge(buffer, incomingBadge);

    /// Horizontal offset for the outgoing badge.
    const double outgoingBadgeOffsetX = 4.0;

    /// Vertical offset to recover the original file Y-coordinate (downward).
    const double outgoingBadgeOffsetY = 6.0;

    // Create outgoing badge (pointing east)
    final outgoingBadge = BadgeModel.outgoing(
      cx: v.badgeX + outgoingBadgeOffsetX,
      cy: v.badgeY + outgoingBadgeOffsetY,
      count: v.outgoing,
      peers: v.outgoingPeers,
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, outgoingBadge);
    final labelMaxWidth =
        max(1.0, v.panelWidth - (fileLabelHorizontalPadding * halfDivisor));
    final textClass = fittedTextClass(
      v.name,
      maxWidth: labelMaxWidth,
      baseFontSize: fileLabelBaseFontSize,
      minFontSize: fileLabelMinFontSize,
    );

    buffer.writeln(
        '<text x="${v.textX}" y="${top + filePanelHeight / halfDivisor}" text-anchor="middle" dominant-baseline="middle" class="$textClass">${v.name}</text>');
  }
}

/// Render file background pills before edges.
void _drawFilePanels(StringBuffer buffer, List<_FileVisual> visuals) {
  for (final v in visuals) {
    /// Half-height offset of the file panel.
    const double filePanelHalfHeight = 14.0;

    /// Height of the file panel.
    const double filePanelHeight = 28.0;

    /// Corner radius for file panel rectangles.
    const double filePanelCornerRadius = 5.0;

    final left = v.panelX;
    final width = v.panelWidth;
    final top = v.textY - filePanelHalfHeight;

    buffer.writeln(
        '<rect x="$left" y="$top" width="$width" height="$filePanelHeight" rx="$filePanelCornerRadius" ry="$filePanelCornerRadius" class="fileNode"/>');
  }
}

/// Render folder titles above all edges/items.
void _drawTitleVisuals(StringBuffer buffer, List<_TitleVisual> visuals) {
  const double titleBaseFontSize = 16.0;
  const double titleMinFontSize = 8.0;

  buffer.writeln('<g class="folderTitleLayer">');
  for (final v in visuals) {
    if (v.text.contains('|')) {
      // Multi-line text for root folder (legacy format)
      final parts = v.text.split('|');
      final longestLine = parts.reduce(
        (current, line) => line.length > current.length ? line : current,
      );
      final titleClass = fittedTextClass(
        longestLine,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );
      buffer.writeln(
          '<text x="${v.x}" y="${v.y}" class="$titleClass" text-anchor="middle">');
      for (int i = 0; i < parts.length; i++) {
        final yOffset = i * _titleLineHeight; // Line height spacing
        buffer.writeln(
            '  <tspan x="${v.x}" dy="${i == 0 ? 0 : yOffset}">${parts[i]}</tspan>');
      }
      buffer.writeln('</text>');
    } else if (v.text.contains('(') && v.text.contains(')')) {
      // Multi-line text for root folder: folder (project v version)
      final openParen = v.text.indexOf('(');
      final closeParen = v.text.indexOf(')');
      final firstLine = v.text.substring(0, openParen).trim();
      final secondLine = v.text.substring(openParen + 1, closeParen).trim();
      final longestLine =
          firstLine.length >= secondLine.length ? firstLine : secondLine;
      final titleClass = fittedTextClass(
        longestLine,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );

      buffer.writeln(
          '<text x="${v.x}" y="${v.y}" class="$titleClass" text-anchor="middle">');
      buffer.writeln('  <tspan x="${v.x}" dy="0">$firstLine</tspan>');
      buffer.writeln(
          '  <tspan x="${v.x}" dy="$_titleLineHeight">$secondLine</tspan>');
      buffer.writeln('</text>');
    } else {
      // Single line text for regular folders or when folder name matches project name
      final titleClass = fittedTextClass(
        v.text,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );
      buffer.writeln(
          '<text x="${v.x}" y="${v.y}" class="$titleClass">${v.text}</text>');
    }
  }
  buffer.writeln('</g>');
}

/// Default starting horizontal position for files.
const double _defaultFileStartX = 20.0;

/// Calculate file positions within folder
List<Point<double>> _calculateFilePositions(
  int fileCount,
  double folderY, {
  required double headerHeight,
  required double topPadding,
  required double itemHeight,
  required double itemSpacing,

  /// Default starting horizontal position for files.
  double startX = _defaultFileStartX,
}) {
  final filePositions = <Point<double>>[];
  var y = folderY + headerHeight + topPadding;

  for (var i = 0; i < fileCount; i++) {
    filePositions.add(Point(startX, y.toDouble()));
    y += itemHeight + itemSpacing;
  }

  return filePositions;
}

/// Sorts [files] for folder rendering using dependencies and metrics.
///
/// Order preference:
/// 1. topological order based on in-folder dependencies (consumers first)
/// 2. higher outgoing count
/// 3. lower incoming count
/// 4. lexical path as final tie-breaker
List<String> _sortFiles(
  List<String> files,
  String _, //folderPath,
  Map<String, Map<String, int>> metrics,
  Map<String, List<String>> graph,
) {
  final fullPaths = {for (final f in files) f: f};
  int compareFilesByMetrics(String a, String b) {
    final aPath = fullPaths[a]!;
    final bPath = fullPaths[b]!;

    final aOut = (metrics[aPath]?['outgoing'] ?? 0);
    final bOut = (metrics[bPath]?['outgoing'] ?? 0);
    var diff = bOut.compareTo(aOut); // desc
    if (diff != 0) return diff;

    final aIn = (metrics[aPath]?['incoming'] ?? 0);
    final bIn = (metrics[bPath]?['incoming'] ?? 0);
    diff = aIn.compareTo(bIn); // asc
    if (diff != 0) return diff;

    return a.compareTo(b); // path asc
  }

  // Build in-folder dependency graph: edge source -> target when source depends on target in same folder.
  final adj = <String, Set<String>>{};
  final indeg = <String, int>{};
  for (final f in files) {
    adj[f] = <String>{};
    indeg[f] = 0;
  }

  for (final f in files) {
    final full = fullPaths[f]!;
    for (final target in graph[full] ?? const []) {
      final localTarget = fullPaths.entries
          .firstWhere((e) => e.value == target,
              orElse: () => const MapEntry('', ''))
          .key;
      if (localTarget.isEmpty) continue;
      if (adj[f]!.add(localTarget)) {
        indeg[localTarget] = (indeg[localTarget] ?? 0) + 1;
      }
    }
  }

  // Kahn topo: consumers (sources) first
  final queue = <String>[];
  queue.addAll(files.where((f) => (indeg[f] ?? 0) == 0));

  final result = <String>[];
  while (queue.isNotEmpty) {
    // Tie-break within queue per spec:
    // Primary: file outgoing dependencies (desc)
    // Secondary: file incoming dependencies (asc)
    // Tiebreaker: file path asc
    queue.sort(compareFilesByMetrics);

    final f = queue.removeAt(0);
    result.add(f);
    for (final t in adj[f]!) {
      indeg[t] = (indeg[t] ?? 0) - 1;
      if ((indeg[t] ?? 0) == 0) queue.add(t);
    }
  }

  // Append any remaining (cycles) sorted by the same criteria
  if (result.length < files.length) {
    final remaining = files.where((f) => !result.contains(f)).toList();
    remaining.sort(compareFilesByMetrics);
    result.addAll(remaining);
  }

  return result;
}
