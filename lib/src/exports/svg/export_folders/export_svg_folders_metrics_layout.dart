part of 'export_svg_folders.dart';

/// Calculate dependency metrics for hierarchical folders.
Map<String, Map<String, int>> _calculateFolderMetrics(
  Map<String, List<String>> dependencyGraph,
  FolderNode rootNode,
) {
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
      final sourceFolder = _getActualFolderPath(
        sourceFile,
        rootNode,
        targetFile,
      );
      final targetFolder = _getActualFolderPath(
        targetFile,
        rootNode,
        sourceFile,
      );

      if (sourceFolder != targetFolder) {
        final edgeKey = '$sourceFolder->$targetFolder';
        if (seenEdges.add(edgeKey)) {
          folderMetrics.putIfAbsent(
            sourceFolder,
            () => {'incoming': 0, 'outgoing': 0},
          );
          folderMetrics.putIfAbsent(
            targetFolder,
            () => {'incoming': 0, 'outgoing': 0},
          );

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
Map<String, int> _computeFolderLevels(
  Map<String, List<String>> dependencyGraph,
  FolderNode rootNode,
) {
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
      final candidates = remainingNodes
          .where((n) => indeg[n] == minIndeg)
          .toList();
      candidates.sort(
        (a, b) => getGroupOut(
          b,
          remainingNodes,
        ).compareTo(getGroupOut(a, remainingNodes)),
      );
      ready = [candidates.first];
    }

    // Sort ready nodes by consumption strength (Phase 2) for deterministic sub-ordering
    ready.sort((a, b) {
      final diff = getGroupOut(
        b,
        remainingNodes,
      ).compareTo(getGroupOut(a, remainingNodes));
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
  Map<String, List<String>> dependencyGraph,
) {
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

/// Initialize metrics for all folders in hierarchy.
void _initializeFolderMetrics(
  FolderNode node,
  Map<String, Map<String, int>> metrics,
) {
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
      : (List<FolderNode>.from(node.children)..sort((a, b) {
          // Virtual folders ("...") are always positioned above regular subfolders
          if (a.isVirtual && !b.isVirtual) return -1;
          if (!a.isVirtual && b.isVirtual) return 1;

          // Otherwise follow dependency levels
          return (folderLevels[a.fullPath] ?? 0).compareTo(
            folderLevels[b.fullPath] ?? 0,
          );
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
    width = max(
      width,
      childIndent + maxChildWidth + (padding * paddingMultiplier),
    );
  }

  final rect = Rect.fromLTWH(0.0, 0.0, width, height);
  dimensions[node.fullPath] = rect;

  // Match children's width to the parent's interior width for a clean flush look
  if (children.isNotEmpty) {
    final innerWidth = width - (padding * paddingMultiplier) - childIndent;
    for (final child in children) {
      final oldRect = dimensions[child.fullPath]!;
      dimensions[child.fullPath] = Rect.fromLTWH(
        0,
        0,
        innerWidth,
        oldRect.height,
      );
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
    childStartY +=
        fileTopPadding +
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
      return (folderLevels[a.fullPath] ?? 0).compareTo(
        folderLevels[b.fullPath] ?? 0,
      );
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

/// Default starting horizontal position for files.
const double _defaultFileStartX = 20.0;

/// Calculate file positions within folder.
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
          .firstWhere(
            (e) => e.value == target,
            orElse: () => const MapEntry('', ''),
          )
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
    // Tie-break within queue per spec.
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
