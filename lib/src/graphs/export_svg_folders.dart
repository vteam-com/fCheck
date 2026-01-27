/// Generates a hierarchical SVG visualization of the dependency graph.
/// This approach preserves the parent-child folder relationships.
library;

import 'dart:math';
import 'package:fcheck/src/layers/layers_results.dart';
import 'package:fcheck/src/models/rect.dart';
import 'package:fcheck/src/graphs/svg_common.dart';
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

  /// Creates a folder node.
  FolderNode(this.name, this.fullPath, this.children, this.files);
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
  _TitleVisual(this.x, this.y, this.text);
}

/// Represents a folder-to-folder dependency edge.
class _FolderEdge {
  final String sourceFolder;
  final String targetFolder;
  _FolderEdge(this.sourceFolder, this.targetFolder);
}

/// Captures folder badge positions to render after edges.
class _FolderBadgeVisual {
  final double cx;
  final double cy;
  final int count;
  final bool isIncoming; // true = blue (incoming), false = green (outgoing)
  final List<String> peers;
  _FolderBadgeVisual({
    required this.cx,
    required this.cy,
    required this.count,
    required this.isIncoming,
    required this.peers,
  });
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
///
/// Returns an SVG string representing the hierarchical folder dependency graph.
String exportGraphSvgFolders(LayersAnalysisResult layersResult) {
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
  final folderMetrics =
      _calculateFolderMetrics(relativeGraph, rootNode.fullPath, rootNode);
  final fileMetrics = _calculateFileMetrics(relativeGraph);
  final folderLevels = _computeFolderLevels(relativeGraph);

  // --- Layout Constants ---
  const double baseFolderWidth = 260.0;
  const double folderMinHeight = 140.0;
  const double folderPadding = 16.0;
  const double childIndent = 18.0;
  const double childSpacing = 18.0;
  const double margin = 50.0;
  const double folderHeaderHeight = 32.0;
  const double fileItemHeight = 22.0;
  const double fileItemSpacing = 6.0;
  const double fileTopPadding = 20.0;
  const double filesToChildrenSpacing = 16.0;

  final folderPositions = <String, Point<double>>{};
  final folderDimensions = <String, Rect>{};
  final maxFileNameChars = relativeGraph.keys
      .followedBy(relativeGraph.values.expand((v) => v))
      .map((p) => p.split('/').last.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  final labelWidth = (maxFileNameChars * 6).toDouble() + 12.0;

  // Measure folders bottom-up so parents grow to fit their children
  final rootSize = _computeFolderDimensions(
    rootNode,
    folderDimensions,
    labelWidth: labelWidth,
    folderLevels: folderLevels,
    baseWidth: baseFolderWidth,
    minHeight: folderMinHeight,
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
    startX: margin,
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

  // Extra canvas width to accommodate right-routed edges
  final totalEdges =
      relativeGraph.values.fold<int>(0, (sum, list) => sum + list.length);
  final edgeExtraWidth = 60.0 + (28.0 + totalEdges * 2.0);

  // Calculate total width and height based on root container plus edge padding
  final totalWidth = margin + rootSize.width + edgeExtraWidth + margin;
  final totalHeight = margin + rootSize.height + margin;

  final buffer = StringBuffer();

  // SVG Header
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<svg width="$totalWidth" height="$totalHeight" viewBox="0 0 $totalWidth $totalHeight" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">');

  // Filter Definitions
  buffer.writeln('<defs>');
  buffer.writeln(
      '  <filter id="hierarchicalShadow" x="-20%" y="-20%" width="140%" height="140%">');
  buffer.writeln('    <feGaussianBlur in="SourceAlpha" stdDeviation="5"/>');
  buffer.writeln('    <feOffset dx="2" dy="2" result="offsetblur"/>');
  buffer.writeln(
      '    <feFlood flood-color="rgba(0,0,0,0.1)" flood-opacity="0.8"/>');
  buffer.writeln('    <feComposite in2="offsetblur" operator="in"/>');
  buffer.writeln('    <feMerge>');
  buffer.writeln('      <feMergeNode/>');
  buffer.writeln('      <feMergeNode in="SourceGraphic"/>');
  buffer.writeln('    </feMerge>');
  buffer.writeln('  </filter>');
  buffer.writeln('  <filter id="outlineWhite">');
  buffer.writeln(
      '    <feMorphology in="SourceAlpha" result="DILATED" operator="dilate" radius="2"/>');
  buffer.writeln(
      '    <feFlood flood-color="white" flood-opacity="0.7" result="WHITE"/>');
  buffer.writeln(
      '    <feComposite in="WHITE" in2="DILATED" operator="in" result="OUTLINE"/>');
  buffer.writeln('    <feMerge>');
  buffer.writeln('      <feMergeNode in="OUTLINE"/>');
  buffer.writeln('      <feMergeNode in="SourceGraphic"/>');
  buffer.writeln('    </feMerge>');
  buffer.writeln('  </filter>');

  // Gradient for hierarchical edges
  buffer.writeln(
      '  <linearGradient id="hierarchicalEdgeGradient" x1="0%" y1="0%" x2="100%" y2="100%">');
  buffer.writeln(
      '    <stop offset="0%" stop-color="#6c757d" stop-opacity="0.4"/>');
  buffer.writeln(
      '    <stop offset="100%" stop-color="#495057" stop-opacity="0.4"/>');
  buffer.writeln('  </linearGradient>');
  buffer.writeln(
      '  <linearGradient id="edgeGradient" x1="0%" y1="0%" x2="0%" y2="100%">');
  buffer
      .writeln('    <stop offset="0%" stop-color="green" stop-opacity="0.3"/>');
  buffer.writeln(
      '    <stop offset="100%" stop-color="blue" stop-opacity="0.3"/>');
  buffer.writeln('  </linearGradient>');
  buffer.writeln('</defs>');

  // CSS Styles
  buffer.writeln('<style>');
  buffer.writeln(
      '  .hierarchicalBackground { fill: rgba(52, 58, 64, 0.08); stroke: none; rx: 12; ry: 12; filter: url(#hierarchicalShadow); }');
  buffer.writeln(
      '  .hierarchicalBackground:hover { fill: rgba(52, 58, 64, 0.12); }');
  buffer.writeln(
      '  .hierarchicalTitle { fill: #495057; font-size: 16px; font-weight: bold; text-anchor: middle; filter: url(#outlineWhite); }');
  buffer.writeln(
      '  .hierarchicalMetric { fill: #6c757d; font-size: 12px; font-weight: normal; text-anchor: middle; }');
  buffer.writeln(
      '  .hierarchicalItem { fill: #212529; font-size: 12px; font-weight: normal; cursor: pointer; filter: url(#outlineWhite); }');
  buffer.writeln(
      '  .hierarchicalItem:hover { fill: #007bff; font-weight: bold; }');
  buffer.writeln(
      '  .hierarchicalEdge { fill: none; stroke: url(#hierarchicalEdgeGradient); stroke-width: 1; }');
  buffer.writeln(
      '  .hierarchicalEdge:hover { stroke: #007bff; stroke-width: 4; opacity: 1.0; }');
  buffer.writeln(
      '  .hierarchicalBadge { font-size: 8px; font-weight: bold; fill: white; text-anchor: middle; dominant-baseline: middle; }');
  buffer.writeln('  .hierarchicalBadge { cursor: help; }');
  buffer.writeln('  .hierarchicalBadge:hover { opacity: 0.8; }');
  // Shared dependency edge styling
  buffer.writeln(
      '  .dependencyEdge { fill: none; stroke: url(#edgeGradient); opacity: 0.9; }');
  buffer.writeln('  .dependencyEdge:hover { stroke: purple; opacity: 1; }');
  // File-level edges
  buffer.writeln('  .fileEdge { stroke-width: 0.5; }');
  buffer.writeln('  .fileEdge:hover { stroke-width: 1; }');
  buffer.writeln(
      '  .fileNode { fill: #ffffff; stroke: #d0d7de; stroke-width: 1; }');
  buffer.writeln(
      '  g.folderTitleLayer { pointer-events: none; isolation: isolate; }');

  buffer.writeln('</style>');

  // Background
  buffer.writeln('<rect width="100%" height="100%" fill="#f8f9fa"/>');

  // Draw hierarchical edges (parent-child relationships)
  _drawHierarchicalEdges(buffer, drawOrder, folderPositions, folderDimensions,
      padding: folderPadding, childIndent: childIndent);

  // Track file anchor positions for dependency edges
  final fileAnchors = <String, Map<String, Point<double>>>{};
  final fileVisuals = <_FileVisual>[];
  final titleVisuals = <_TitleVisual>[];
  final folderBadges = <_FolderBadgeVisual>[];
  final folderDependencies = _collectFolderDependencies(relativeGraph);
  final folderDepGraph = <String, List<String>>{};
  for (final edge in folderDependencies) {
    folderDepGraph
        .putIfAbsent(edge.sourceFolder, () => [])
        .add(edge.targetFolder);
  }
  final folderPeers =
      buildPeerLists(folderDepGraph, labelFor: (path) => path.split('/').last);
  final folderIncomingPeers = folderPeers.incoming;
  final folderOutgoingPeers = folderPeers.outgoing;
  final filePeers =
      buildPeerLists(relativeGraph, labelFor: (path) => path.split('/').last);
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
      labelWidth: labelWidth,
      headerHeight: folderHeaderHeight,
      fileItemHeight: fileItemHeight,
      fileItemSpacing: fileItemSpacing,
      fileTopPadding: fileTopPadding);

  // Draw inter-folder dependency edges between backgrounds and badges
  _drawFolderDependencyEdges(
      buffer, folderDependencies, folderPositions, folderDimensions);

  // Draw folder badges above dependency edges
  _drawFolderBadges(buffer, folderBadges);

  // Draw file background pills first
  _drawFilePanels(buffer, fileVisuals);

  // Draw file-to-file dependency edges
  _drawFileEdges(buffer, relativeGraph, fileAnchors);

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

    // Add file to the deepest folder
    final fileName = parts.last;
    if (!current.files.contains(fileName)) {
      current.files.add(fileName);
    }
  }

  return root;
}

/// Calculate dependency metrics for hierarchical folders
Map<String, Map<String, int>> _calculateFolderMetrics(
    Map<String, List<String>> dependencyGraph,
    String rootPath,
    FolderNode rootNode) {
  final folderMetrics = <String, Map<String, int>>{};

  // Initialize all folders
  _initializeFolderMetrics(rootNode, folderMetrics);

  // Calculate cross-folder dependencies
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final targetFiles = entry.value;

    for (final targetFile in targetFiles) {
      final sourceFolder = _getFolderPath(sourceFile, rootPath);
      final targetFolder = _getFolderPath(targetFile, rootPath);

      if (sourceFolder != targetFolder) {
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

  return folderMetrics;
}

/// Compute folder levels so that if X depends on Y, Y gets a greater level (drawn lower).
Map<String, int> _computeFolderLevels(
    Map<String, List<String>> dependencyGraph) {
  final adj = <String, Set<String>>{};
  final indegree = <String, int>{};

  void ensure(String folder) {
    adj.putIfAbsent(folder, () => <String>{});
    indegree.putIfAbsent(folder, () => 0);
  }

  for (final entry in dependencyGraph.entries) {
    final sourceFolder = _getFolderPath(entry.key, '.');
    ensure(sourceFolder);
    for (final target in entry.value) {
      final targetFolder = _getFolderPath(target, '.');
      ensure(targetFolder);
      if (sourceFolder == targetFolder) continue;
      if (adj[sourceFolder]!.add(targetFolder)) {
        indegree[targetFolder] = (indegree[targetFolder] ?? 0) + 1;
      }
    }
  }

  final levels = <String, int>{};
  final queue = <String>[];
  queue.addAll(indegree.entries.where((e) => e.value == 0).map((e) => e.key));

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final currentLevel = levels[current] ?? 0;

    for (final target in adj[current] ?? const {}) {
      final nextLevel = currentLevel + 1;
      if ((levels[target] ?? 0) < nextLevel) {
        levels[target] = nextLevel;
      }
      indegree[target] = (indegree[target] ?? 0) - 1;
      if ((indegree[target] ?? 0) == 0) {
        queue.add(target);
      }
    }
  }

  // For any nodes not processed (cycles), keep level 0
  for (final folder in adj.keys) {
    levels.putIfAbsent(folder, () => 0);
  }

  return levels;
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
  required double minHeight,
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
        ..sort((a, b) => (folderLevels[a.fullPath] ?? 0)
            .compareTo(folderLevels[b.fullPath] ?? 0)));

  for (var i = 0; i < children.length; i++) {
    final childRect = _computeFolderDimensions(
      children[i],
      dimensions,
      labelWidth: labelWidth,
      folderLevels: folderLevels,
      baseWidth: baseWidth,
      minHeight: minHeight,
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

  height = height < minHeight ? minHeight : height;

  final fileRowWidth = labelWidth + 50; // room for text + badges + margins

  var width = max(baseWidth, fileRowWidth);
  if (node.children.isNotEmpty) {
    width = max(width, childIndent + maxChildWidth + (padding * 2));
  }

  final rect = Rect.fromLTWH(0.0, 0.0, width, height);
  dimensions[node.fullPath] = rect;
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
    ..sort((a, b) => (folderLevels[a.fullPath] ?? 0)
        .compareTo(folderLevels[b.fullPath] ?? 0));

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
void _drawHierarchicalEdges(StringBuffer buffer, List<FolderNode> folders,
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

      final parentX = parentPos.x + padding + (childIndent / 2);
      final parentY = childPos.y + (childDim.height / 2);
      final childX = childPos.x - 8;
      final childY = childPos.y + (childDim.height / 2);

      // Control points for a gentle left-to-right curve within the parent box
      final controlX1 = parentX + (childIndent / 2);
      final controlX2 = childX - (childIndent / 2);

      buffer.writeln(
          '<path d="M $parentX $parentY C $controlX1 $parentY, $controlX2 $childY, $childX $childY" class="hierarchicalEdge"/>');
      buffer.writeln(
          '<title>${folder.name} → ${child.name} (parent-child)</title>');
    }
  }
}

/// Collect unique folder-to-folder dependency edges.
List<_FolderEdge> _collectFolderDependencies(
    Map<String, List<String>> dependencyGraph) {
  final edges = <_FolderEdge>[];
  final seen = <String>{};

  for (final entry in dependencyGraph.entries) {
    final sourceFolder = _getFolderPath(entry.key, '.');
    for (final target in entry.value) {
      final targetFolder = _getFolderPath(target, '.');
      if (sourceFolder == targetFolder) continue;

      final key = '$sourceFolder->$targetFolder';
      if (seen.add(key)) {
        edges.add(_FolderEdge(sourceFolder, targetFolder));
      }
    }
  }

  return edges;
}

/// Draw folder-level dependency edges routed on the left side of folders.
void _drawFolderDependencyEdges(
  StringBuffer buffer,
  List<_FolderEdge> edges,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions,
) {
  if (edges.isEmpty) return;

  const double badgeTopOffset = 4.0;
  const double badgeGap = 18.0; // vertical space between incoming and outgoing
  const double columnGap = 32.0;
  const double columnStep = 2.0; // keep columns separated like file edges
  const double cornerRadius = 10.0;
  const double minCanvasInset = 8.0; // keep a clear margin from the canvas

  for (var i = 0; i < edges.length; i++) {
    final edge = edges[i];
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

    // Start/end at badge centers so strokes originate/terminate at badges.
    final startX = sourcePos.x;
    final startY = sourcePos.y + badgeTopOffset + badgeGap; // outgoing badge
    final endX = targetPos.x;
    final endY = targetPos.y + badgeTopOffset; // incoming badge

    // Offset each edge column slightly left of its source to avoid stacking.
    final localMin = min(startX, endX);
    final rawColumnX = (localMin - columnGap) - (i * columnStep);
    final maxLeft = localMin - cornerRadius - minCanvasInset;
    final columnX = max(minCanvasInset, min(rawColumnX, maxLeft));

    // Rounded corners on both turns.
    final dirY = endY >= startY ? 1.0 : -1.0;
    final firstQy = startY + (dirY * cornerRadius);
    final secondVy = endY - (dirY * cornerRadius);

    buffer.writeln('<path d="M $startX $startY '
        'H ${columnX + cornerRadius} '
        'Q $columnX $startY $columnX $firstQy '
        'V $secondVy '
        'Q $columnX $endY ${columnX + cornerRadius} $endY '
        'H $endX" class="dependencyEdge"/>');
    buffer.writeln(
        '<title>${edge.sourceFolder} → ${edge.targetFolder} (folder dependency)</title>');
  }
}

/// Render folder badges after edges so they sit on top.
void _drawFolderBadges(StringBuffer buffer, List<_FolderBadgeVisual> badges) {
  for (final b in badges) {
    final tooltip = b.peers.isEmpty ? '' : b.peers.join('\n');
    renderBadge(
      buffer,
      cx: b.cx,
      cy: b.cy,
      radius: 8,
      count: b.count,
      color: b.isIncoming ? '#007bff' : '#28a745',
      cssClass: 'hierarchicalBadge',
      tooltip: tooltip,
    );
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
  List<_FolderBadgeVisual> folderBadges,
  Map<String, List<String>> folderIncomingPeers,
  Map<String, List<String>> folderOutgoingPeers,
  Map<String, List<String>> fileIncomingPeers,
  Map<String, List<String>> fileOutgoingPeers,
  Map<String, int> depths, {
  required double labelWidth,
  required double headerHeight,
  required double fileItemHeight,
  required double fileItemSpacing,
  required double fileTopPadding,
}) {
  void drawFolder(FolderNode folder) {
    final pos = positions[folder.fullPath]!;
    final dim = dimensions[folder.fullPath]!;
    final folderMetrics =
        metrics[folder.fullPath] ?? {'incoming': 0, 'outgoing': 0};
    final incoming = folderMetrics['incoming'] ?? 0;
    final outgoing = folderMetrics['outgoing'] ?? 0;
    final depth = depths[folder.fullPath] ?? 0;
    const double badgeTopOffset = 4.0;
    const double badgeGap = 18.0;

    buffer.writeln('<g class="folderLayer">');
    buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="12" ry="12" class="hierarchicalBackground"/>');

    final indentLevels = depth > 0 ? depth : 0;
    final indent = List.filled(indentLevels, '  ').join();
    final titleText = '$indent${folder.name}';
    titleVisuals
        .add(_TitleVisual(pos.x + dim.width / 2, pos.y + 25, titleText));
    buffer.writeln('</g>');

    folderBadges.add(_FolderBadgeVisual(
      cx: pos.x,
      cy: pos.y + badgeTopOffset,
      count: incoming,
      isIncoming: true,
      peers: folderIncomingPeers[folder.fullPath] ?? const [],
    ));
    folderBadges.add(_FolderBadgeVisual(
      cx: pos.x,
      cy: pos.y + badgeTopOffset + badgeGap,
      count: outgoing,
      isIncoming: false,
      peers: folderOutgoingPeers[folder.fullPath] ?? const [],
    ));

    final sortedFiles =
        _sortFiles(folder.files, folder.fullPath, fileMetrics, dependencyGraph);
    final filePositions = _calculateFilePositions(
      sortedFiles.length,
      0, // compute positions relative to folder top
      headerHeight: headerHeight,
      topPadding: fileTopPadding,
      itemHeight: fileItemHeight,
      itemSpacing: fileItemSpacing,
      startX: 0.0,
    );

    final textX = pos.x + 12.0; // consistent left padding
    // Draw children after this folder so they appear on top
    for (final child in folder.children) {
      drawFolder(child);
    }

    // Collect file visuals; badges/text drawn later after edges
    for (var j = 0; j < sortedFiles.length; j++) {
      final file = sortedFiles[j];
      final filePos = filePositions[j];
      final fileY = pos.y + filePos.y;
      final filePath =
          folder.fullPath == '.' ? file : '${folder.fullPath}/$file';
      final fileName = file.split('/').last;

      final fIncoming = fileMetrics[filePath]?['incoming'] ?? 0;
      final fOutgoing = fileMetrics[filePath]?['outgoing'] ?? 0;

      final panelX = pos.x + 8.0;
      final panelWidth = dim.width - 16.0; // flush within folder
      // Use panel-based coordinates for badges and edge anchors.
      final badgeX = panelX + panelWidth - 14; // 8px inset + small padding
      fileAnchors[filePath] = {
        'in': Point(badgeX, fileY - 6),
        'out': Point(badgeX, fileY + 6),
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

  // Start recursive draw from root (first element is root)
  if (folders.isNotEmpty) {
    drawFolder(folders.first);
  }
}

/// Draw edges between files based on dependency graph.
void _drawFileEdges(StringBuffer buffer, Map<String, List<String>> graph,
    Map<String, Map<String, Point<double>>> anchors) {
  var edgeCounter = 0;
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

      final path =
          _buildStackedEdgePath(startX, startY, endX, endY, edgeCounter);
      buffer.writeln('<path d="$path" class="dependencyEdge fileEdge"/>');
      buffer.writeln('<title>$source → $target</title>');
      edgeCounter++;
    }
  }
}

/// Build a right-then-vertical-then-left edge with stacked columns.
String _buildStackedEdgePath(
    double startX, double startY, double endX, double endY, int edgeIndex) {
  const double baseOffset = 28.0;
  const double radius = 6.0;
  final dirY = endY >= startY ? 1.0 : -1.0;

  // Each edge gets a slightly larger offset to avoid overlapping vertical runs.
  final columnX = startX + baseOffset + edgeIndex * 1.0;

  final preCurveX = columnX - radius;
  final postCurveX = columnX - radius;
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
  for (final v in visuals) {
    final top = v.textY - 14;
    const height = 28.0;
    final textX = v.textX + 10.0;
    renderBadge(
      buffer,
      cx: v.badgeX,
      cy: v.badgeY - 6,
      radius: 7,
      count: v.incoming,
      color: '#007bff',
      cssClass: 'hierarchicalBadge',
      tooltip: v.incomingPeers.join('\n'),
    );
    renderBadge(
      buffer,
      cx: v.badgeX,
      cy: v.badgeY + 6,
      radius: 7,
      count: v.outgoing,
      color: '#28a745',
      cssClass: 'hierarchicalBadge',
      tooltip: v.outgoingPeers.join('\n'),
    );

    buffer.writeln(
        '<text x="$textX" y="${top + height / 2}" text-anchor="start" dominant-baseline="middle" class="hierarchicalItem">${v.name}</text>');
  }
}

/// Render file background pills before edges.
void _drawFilePanels(StringBuffer buffer, List<_FileVisual> visuals) {
  for (final v in visuals) {
    final left = v.panelX;
    final width = v.panelWidth;
    final top = v.textY - 14;
    const height = 28.0;
    buffer.writeln(
        '<rect x="$left" y="$top" width="$width" height="$height" rx="5" ry="5" class="fileNode"/>');
  }
}

/// Render folder titles above all edges/items.
void _drawTitleVisuals(StringBuffer buffer, List<_TitleVisual> visuals) {
  buffer.writeln('<g class="folderTitleLayer">');
  for (final v in visuals) {
    buffer.writeln(
        '<text x="${v.x}" y="${v.y}" class="hierarchicalTitle">${v.text}</text>');
  }
  buffer.writeln('</g>');
}

/// Calculate file positions within folder
List<Point<double>> _calculateFilePositions(
  int fileCount,
  double folderY, {
  required double headerHeight,
  required double topPadding,
  required double itemHeight,
  required double itemSpacing,
  double startX = 20.0,
}) {
  final filePositions = <Point<double>>[];
  var y = folderY + headerHeight + topPadding;

  for (var i = 0; i < fileCount; i++) {
    filePositions.add(Point(startX, y.toDouble()));
    y += itemHeight + itemSpacing;
  }

  return filePositions;
}

List<String> _sortFiles(
  List<String> files,
  String folderPath,
  Map<String, Map<String, int>> metrics,
  Map<String, List<String>> graph,
) {
  final fullPaths = {
    for (final f in files) f: folderPath == '.' ? f : '$folderPath/$f'
  };

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
    // tie-break within queue by incoming count desc then name
    queue.sort((a, b) {
      final aPath = fullPaths[a]!;
      final bPath = fullPaths[b]!;
      final aIn = (metrics[aPath]?['incoming'] ?? 0);
      final bIn = (metrics[bPath]?['incoming'] ?? 0);
      final diff = bIn.compareTo(aIn);
      if (diff != 0) return diff;
      return a.compareTo(b);
    });

    final f = queue.removeAt(0);
    result.add(f);
    for (final t in adj[f]!) {
      indeg[t] = (indeg[t] ?? 0) - 1;
      if ((indeg[t] ?? 0) == 0) queue.add(t);
    }
  }

  // Append any remaining (cycles) sorted by incoming desc then name
  if (result.length < files.length) {
    final remaining = files.where((f) => !result.contains(f)).toList();
    remaining.sort((a, b) {
      final aPath = fullPaths[a]!;
      final bPath = fullPaths[b]!;
      final aIn = (metrics[aPath]?['incoming'] ?? 0);
      final bIn = (metrics[bPath]?['incoming'] ?? 0);
      final diff = bIn.compareTo(aIn);
      if (diff != 0) return diff;
      return a.compareTo(b);
    });
    result.addAll(remaining);
  }

  return result;
}
