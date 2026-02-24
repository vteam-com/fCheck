import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
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
