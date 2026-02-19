part of 'export_svg_folders.dart';

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
      .map(
        (pPath) => p
            .normalize(pPath)
            .split(p.separator)
            .where((p) => p.isNotEmpty)
            .toList(),
      )
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
  Map<String, List<String>> graph,
  String root,
) {
  final relative = <String, List<String>>{};

  for (final entry in graph.entries) {
    final source = p.relative(entry.key, from: root);
    final targets = entry.value
        .map((target) => p.relative(target, from: root))
        .toList();
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

/// Build hierarchical folder structure from file paths.
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
      final folderPath = currentPath.isEmpty
          ? folderName
          : '$currentPath/$folderName';

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
      virtualFolderName,
      virtualFolderPath,
      [],
      virtualFolderFiles,
      isVirtual: true,
    );

    // Clear the files from the parent folder
    node.files.clear();

    // Insert the virtual folder at the beginning (above all other subfolders)
    node.children.insert(0, virtualFolder);
  }
}

/// Find the actual folder path where a file ends up, considering virtual subfolders.
String _getActualFolderPath(
  String filePath,
  FolderNode rootNode,
  String? targetFilePath,
) {
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

/// Get folder path from file path (preserving hierarchy)
String _getFolderPath(String filePath, String rootPath) {
  if (!filePath.contains('/')) {
    return rootPath;
  }

  final lastSlash = filePath.lastIndexOf('/');
  return filePath.substring(0, lastSlash);
}

/// Collect unique folder-to-folder dependency edges.
List<_FolderEdge> _collectFolderDependencies(
  Map<String, List<String>> dependencyGraph,
  FolderNode rootNode,
) {
  final edges = <_FolderEdge>[];
  final seen = <String>{};

  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final targetFiles = entry.value;

    for (final targetFile in targetFiles) {
      // Get actual folder paths considering virtual subfolders
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

      if (sourceFolder == targetFolder) continue;

      final key = '$sourceFolder->$targetFolder';
      if (seen.add(key)) {
        edges.add(_FolderEdge(sourceFolder, targetFolder));
      }
    }
  }

  return edges;
}

/// Extract folder paths involved in folder cycles or layer violations from layers issues.
/// This normalizes paths to match the SVG's folder hierarchy.
Map<String, Object> _extractFolderIssuesFromIssues(
  List<LayersIssue> issues,
  Map<String, List<String>> dependencyGraph,
) {
  // For folder cycles: set of folder paths that are in a cycle
  final Set<String> folderCycles = <String>{};
  // For layer violations: map of sourceFolder -> Set<targetFolder> that are violating
  final Map<String, Set<String>> layerViolationEdges = <String, Set<String>>{};

  // Find common root to normalize paths
  final allPaths = <String>{};
  for (final entry in dependencyGraph.entries) {
    allPaths.add(entry.key);
    allPaths.addAll(entry.value);
  }
  final commonRoot = _findCommonRoot(allPaths);

  for (final issue in issues) {
    if (issue.type == LayersIssueType.folderCycle) {
      // Normalize the path the same way the SVG does
      final normalizedPath = p.relative(issue.filePath, from: commonRoot);
      folderCycles.add(normalizedPath);
    } else if (issue.type == LayersIssueType.wrongFolderLayer) {
      // Extract target folder from message: 'Folder at layer X depends on folder "Y" at higher layer Z'
      final message = issue.message;
      final targetMatch = RegExp(r'folder "([^"]+)"').firstMatch(message);
      if (targetMatch != null) {
        final targetPath = targetMatch.group(1)!;
        // Normalize the target path
        final normalizedTarget = p.relative(targetPath, from: commonRoot);

        // Also normalize source path
        final normalizedSource = p.relative(issue.filePath, from: commonRoot);

        // Add this specific violating edge
        layerViolationEdges.putIfAbsent(normalizedSource, () => <String>{});
        layerViolationEdges[normalizedSource]!.add(normalizedTarget);
      }
    }
  }

  // Also extract just the source folders for backward compatibility if needed
  final folderLayerViolations = layerViolationEdges.keys.toSet();

  return {
    'cycles': folderCycles,
    'layerViolations': folderLayerViolations,
    'layerViolationEdges': layerViolationEdges,
  };
}
