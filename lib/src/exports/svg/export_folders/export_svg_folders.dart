import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:fcheck/src/models/rect.dart';
import 'package:path/path.dart' as p;

part 'export_svg_folders_models.dart';
part 'export_svg_folders_paths.dart';
part 'export_svg_folders_metrics_layout.dart';
part 'export_svg_folders_rendering.dart';

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
  ProjectMetrics? projectMetrics,
}) {
  final dependencyGraph = layersResult.dependencyGraph;

  if (dependencyGraph.isEmpty) {
    return generateEmptySvg('No hierarchical dependencies found');
  }

  // Normalize paths to a common root and include target-only files
  final allAbsolutePaths = _collectAllFilePaths(dependencyGraph);
  final commonRoot = _findCommonRoot(allAbsolutePaths);
  final relativeGraph = _relativizeGraph(dependencyGraph, commonRoot);
  final knownRelativeFiles = _collectAllFilePaths(relativeGraph);
  final fileSeverityByPath = _buildRelativeFileSeverityByPath(
    layersResult.issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
  );
  final fileWarningsByPath = _buildRelativeFileWarningsByPath(
    layersResult.issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
  );
  final folderSeverityByPath = _buildFolderSeverityByPath(
    layersResult.issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
  );
  final folderWarningsByPath = _buildFolderWarningsByPath(
    layersResult.issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
  );

  // Build hierarchical folder structure from relative paths
  final allRelativePaths = _collectAllFilePaths(relativeGraph).toList();
  final rootNode = _buildFolderHierarchy(allRelativePaths);

  // Calculate folder-level dependency counts using relative paths
  final folderMetrics = _calculateFolderMetrics(relativeGraph, rootNode);
  final fileMetrics = _calculateFileMetrics(relativeGraph);
  final folderLevels = _computeFolderLevels(relativeGraph, rootNode);

  final folderDependencies = _collectFolderDependencies(
    relativeGraph,
    rootNode,
  );
  final folderDepGraph = <String, List<String>>{};
  for (final edge in folderDependencies) {
    folderDepGraph
        .putIfAbsent(edge.sourceFolder, () => [])
        .add(edge.targetFolder);
  }

  // --- Extra canvas width to accommodate left/right-routed edges ---
  const double edgeLanePadding = 0.0;
  const double edgeLaneBaseWidth = 0.0;
  const double edgeLanePerEdgeWidth = _edgeLaneStepWidth;

  // Extra canvas width to accommodate left/right-routed edges
  final totalFileEdges = relativeGraph.values.fold<int>(
    0,
    (sum, list) => sum + list.length,
  );
  final fileLaneColumns = totalFileEdges;
  final fileEdgeExtraWidth =
      edgeLanePadding +
      (edgeLaneBaseWidth + fileLaneColumns * edgeLanePerEdgeWidth);
  final folderEdgeExtraWidth =
      edgeLanePadding +
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

  // Folders are centered, with dedicated lanes for folder and file connections
  final totalWidth =
      margin +
      folderEdgeExtraWidth +
      rootSize.width +
      fileEdgeExtraWidth +
      margin;
  final totalHeight = margin + rootSize.height + margin;

  final buffer = StringBuffer();

  writeSvgDocumentStart(
    buffer,
    width: totalWidth,
    height: totalHeight,
    includeUnifiedStyles: true,
    backgroundFill: '#f8f9fa',
  );

  // Draw hierarchical edges (parent-child relationships)
  _drawEdgeHorizontalCurve(
    buffer,
    drawOrder,
    folderPositions,
    folderDimensions,
    padding: folderPadding,
    childIndent: childIndent,
  );

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
    folderSeverityByPath: folderSeverityByPath,
    fileSeverityByPath: fileSeverityByPath,
    folderWarningsByPath: folderWarningsByPath,
    fileWarningsByPath: fileWarningsByPath,
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

  // Extract folder cycles and layer violations from issues (with dependencyGraph for path normalization)
  final folderIssues = _extractFolderIssuesFromIssues(
    layersResult.issues,
    dependencyGraph,
  );
  final folderCycles = folderIssues['cycles'] as Set<String>;
  final layerViolationEdges =
      folderIssues['layerViolationEdges'] as Map<String, Set<String>>? ?? {};
  final fileViolationEdges =
      folderIssues['fileViolationEdges'] as Set<String>? ?? const <String>{};

  // Draw inter-folder dependency edges between backgrounds and badges
  _drawEdgeVerticalFolders(
    buffer,
    folderDependencies,
    folderPositions,
    folderDimensions,
    globalGutterX: leftLaneGutterX,
    rootPath: rootNode.fullPath,
    folderCycles: folderCycles,
    layerViolationEdges: layerViolationEdges,
  );

  _drawFolderBadges(buffer, folderBadges);
  _drawFilePanels(buffer, fileVisuals);

  _drawEdgeVerticalsFiles(
    buffer,
    relativeGraph,
    fileAnchors,
    folderLevels,
    rightLaneGutterX: rightLaneGutterX,
    fileViolationEdges: fileViolationEdges,
  );

  _drawFileVisuals(buffer, fileVisuals);
  _drawTitleVisuals(buffer, titleVisuals);

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}

Map<String, String> _buildRelativeFileSeverityByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final severityByPath = <String, String>{};
  String relativize(String normalizedPath) {
    if (p.isAbsolute(normalizedPath)) {
      return p.relative(normalizedPath, from: commonRoot);
    }
    if (commonRoot != '.' && normalizedPath.startsWith('$commonRoot/')) {
      return normalizedPath.substring(commonRoot.length + 1);
    }
    return normalizedPath;
  }

  void push(String filePath, String? severity) {
    if (filePath.isEmpty) {
      return;
    }
    final normalized = p.normalize(filePath);
    final relative = _resolveToKnownRelativeFilePath(
      relativize(normalized),
      knownRelativeFiles,
    );
    if (relative == '.' || relative.isEmpty) {
      return;
    }
    severityByPath[relative] = _maxSeverity(severityByPath[relative], severity);
  }

  for (final issue in issues) {
    push(issue.filePath, _severityForIssueType(issue.type));
  }

  if (projectMetrics != null) {
    for (final issue in projectMetrics.hardcodedStringIssues) {
      push(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.magicNumberIssues) {
      push(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.secretIssues) {
      final filePath = issue.filePath;
      if (filePath != null) {
        push(filePath, 'warning');
      }
    }
    for (final issue in projectMetrics.documentationIssues) {
      push(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.sourceSortIssues) {
      push(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.duplicateCodeIssues) {
      push(issue.firstFilePath, 'warning');
      push(issue.secondFilePath, 'warning');
    }
    for (final issue in projectMetrics.deadCodeIssues) {
      push(issue.filePath, 'error');
    }
  }
  return severityByPath;
}

Map<String, String> _buildFolderSeverityByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final severityByPath = <String, String>{};
  String relativize(String normalizedPath) {
    if (p.isAbsolute(normalizedPath)) {
      return p.relative(normalizedPath, from: commonRoot);
    }
    if (commonRoot != '.' && normalizedPath.startsWith('$commonRoot/')) {
      return normalizedPath.substring(commonRoot.length + 1);
    }
    return normalizedPath;
  }

  void pushFolder(String filePath, String? severity) {
    if (filePath.isEmpty) {
      return;
    }
    final normalized = p.normalize(filePath);
    final relative = _resolveToKnownRelativeFilePath(
      relativize(normalized),
      knownRelativeFiles,
    );
    if (relative == '.' || relative.isEmpty) {
      return;
    }
    final folderPath = p.dirname(relative);
    severityByPath[folderPath] = _maxSeverity(
      severityByPath[folderPath],
      severity,
    );
  }

  for (final issue in issues) {
    if (issue.filePath.isEmpty) {
      continue;
    }
    final normalized = p.normalize(issue.filePath);
    final relative = issue.type == LayersIssueType.folderCycle
        ? relativize(normalized)
        : _resolveToKnownRelativeFilePath(
            relativize(normalized),
            knownRelativeFiles,
          );
    if (relative == '.' || relative.isEmpty) {
      continue;
    }
    final folderPath = issue.type == LayersIssueType.folderCycle
        ? relative
        : p.dirname(relative);
    severityByPath[folderPath] = _maxSeverity(
      severityByPath[folderPath],
      _severityForIssueType(issue.type),
    );
  }

  if (projectMetrics != null) {
    for (final issue in projectMetrics.hardcodedStringIssues) {
      pushFolder(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.magicNumberIssues) {
      pushFolder(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.secretIssues) {
      final filePath = issue.filePath;
      if (filePath != null) {
        pushFolder(filePath, 'warning');
      }
    }
    for (final issue in projectMetrics.documentationIssues) {
      pushFolder(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.sourceSortIssues) {
      pushFolder(issue.filePath, 'warning');
    }
    for (final issue in projectMetrics.duplicateCodeIssues) {
      pushFolder(issue.firstFilePath, 'warning');
      pushFolder(issue.secondFilePath, 'warning');
    }
    for (final issue in projectMetrics.deadCodeIssues) {
      pushFolder(issue.filePath, 'error');
    }
  }
  return severityByPath;
}

String? _severityForIssueType(LayersIssueType type) {
  switch (type) {
    case LayersIssueType.cyclicDependency:
    case LayersIssueType.folderCycle:
      return 'error';
    case LayersIssueType.wrongLayer:
    case LayersIssueType.wrongFolderLayer:
      return 'warning';
  }
}

String _maxSeverity(String? current, String? next) {
  if (next == null) {
    return current ?? '';
  }
  if (current == 'error' || next == 'error') {
    return 'error';
  }
  return next;
}

String? _fillColorForSeverity(String? severity) {
  if (severity == 'error') {
    return '#e05545';
  }
  if (severity == 'warning') {
    return '#f2a23a';
  }
  return null;
}

Map<String, Map<String, int>> _buildRelativeFileWarningsByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final warningsByPath = <String, Map<String, int>>{};
  String relativize(String normalizedPath) {
    if (p.isAbsolute(normalizedPath)) {
      return p.relative(normalizedPath, from: commonRoot);
    }
    if (commonRoot != '.' && normalizedPath.startsWith('$commonRoot/')) {
      return normalizedPath.substring(commonRoot.length + 1);
    }
    return normalizedPath;
  }

  void add(String rawPath, String warningType) {
    if (rawPath.isEmpty) {
      return;
    }
    final relative = _resolveToKnownRelativeFilePath(
      relativize(p.normalize(rawPath)),
      knownRelativeFiles,
    );
    if (relative == '.' || relative.isEmpty) {
      return;
    }
    final bucket = warningsByPath.putIfAbsent(relative, () => <String, int>{});
    bucket[warningType] = (bucket[warningType] ?? 0) + 1;
  }

  for (final issue in issues) {
    add(issue.filePath, 'Layers');
  }
  if (projectMetrics != null) {
    for (final issue in projectMetrics.hardcodedStringIssues) {
      add(issue.filePath, 'Hardcoded Strings');
    }
    for (final issue in projectMetrics.magicNumberIssues) {
      add(issue.filePath, 'Magic Numbers');
    }
    for (final issue in projectMetrics.secretIssues) {
      final filePath = issue.filePath;
      if (filePath != null) {
        add(filePath, 'Secrets');
      }
    }
    for (final issue in projectMetrics.documentationIssues) {
      add(issue.filePath, 'Documentation');
    }
    for (final issue in projectMetrics.sourceSortIssues) {
      add(issue.filePath, 'Source Sorting');
    }
    for (final issue in projectMetrics.duplicateCodeIssues) {
      add(issue.firstFilePath, 'Duplicate Code');
      add(issue.secondFilePath, 'Duplicate Code');
    }
    for (final issue in projectMetrics.deadCodeIssues) {
      add(issue.filePath, 'Dead Code');
    }
  }
  return warningsByPath;
}

Map<String, Map<String, int>> _buildFolderWarningsByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final warningsByPath = <String, Map<String, int>>{};
  String relativize(String normalizedPath) {
    if (p.isAbsolute(normalizedPath)) {
      return p.relative(normalizedPath, from: commonRoot);
    }
    if (commonRoot != '.' && normalizedPath.startsWith('$commonRoot/')) {
      return normalizedPath.substring(commonRoot.length + 1);
    }
    return normalizedPath;
  }

  void addFolder(String rawPath, String warningType) {
    if (rawPath.isEmpty) {
      return;
    }
    final relative = _resolveToKnownRelativeFilePath(
      relativize(p.normalize(rawPath)),
      knownRelativeFiles,
    );
    if (relative == '.' || relative.isEmpty) {
      return;
    }
    final folderPath = p.dirname(relative);
    final bucket = warningsByPath.putIfAbsent(
      folderPath,
      () => <String, int>{},
    );
    bucket[warningType] = (bucket[warningType] ?? 0) + 1;
  }

  for (final issue in issues) {
    final rawPath = issue.type == LayersIssueType.folderCycle
        ? issue.filePath
        : issue.filePath;
    addFolder(rawPath, 'Layers');
  }
  if (projectMetrics != null) {
    for (final issue in projectMetrics.hardcodedStringIssues) {
      addFolder(issue.filePath, 'Hardcoded Strings');
    }
    for (final issue in projectMetrics.magicNumberIssues) {
      addFolder(issue.filePath, 'Magic Numbers');
    }
    for (final issue in projectMetrics.secretIssues) {
      final filePath = issue.filePath;
      if (filePath != null) {
        addFolder(filePath, 'Secrets');
      }
    }
    for (final issue in projectMetrics.documentationIssues) {
      addFolder(issue.filePath, 'Documentation');
    }
    for (final issue in projectMetrics.sourceSortIssues) {
      addFolder(issue.filePath, 'Source Sorting');
    }
    for (final issue in projectMetrics.duplicateCodeIssues) {
      addFolder(issue.firstFilePath, 'Duplicate Code');
      addFolder(issue.secondFilePath, 'Duplicate Code');
    }
    for (final issue in projectMetrics.deadCodeIssues) {
      addFolder(issue.filePath, 'Dead Code');
    }
  }
  return warningsByPath;
}

String _resolveToKnownRelativeFilePath(
  String rawRelativePath,
  Set<String> knownRelativeFiles,
) {
  final normalizedRaw = p.normalize(rawRelativePath).replaceAll('\\', '/');
  if (knownRelativeFiles.contains(normalizedRaw)) {
    return normalizedRaw;
  }

  final noDot = normalizedRaw.startsWith('./')
      ? normalizedRaw.substring(2)
      : normalizedRaw;
  if (knownRelativeFiles.contains(noDot)) {
    return noDot;
  }

  String? bestMatch;
  for (final candidate in knownRelativeFiles) {
    if (candidate == normalizedRaw ||
        candidate.endsWith('/$normalizedRaw') ||
        normalizedRaw.endsWith('/$candidate') ||
        candidate == noDot ||
        candidate.endsWith('/$noDot') ||
        noDot.endsWith('/$candidate')) {
      if (bestMatch == null || candidate.length > bestMatch.length) {
        bestMatch = candidate;
      }
    }
  }
  return bestMatch ?? normalizedRaw;
}

String _buildWarningTitle(String heading, Map<String, int>? warningTypeCounts) {
  final lines = <String>[heading];
  if (warningTypeCounts != null && warningTypeCounts.isNotEmpty) {
    lines.add('');
    final sorted = warningTypeCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    for (final entry in sorted) {
      final suffix = entry.value == 1 ? 'warning' : 'warnings';
      lines.add('${entry.value} ${entry.key} $suffix');
    }
  }
  return escapeXml(lines.join('\n'));
}
