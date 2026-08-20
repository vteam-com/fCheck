import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:fcheck/src/input_output/path_style_utils.dart';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/models/rect.dart';
import 'package:path/path.dart' as p;

part 'export_svg_folders_models.dart';
part 'export_svg_folders_paths.dart';
part 'export_svg_folders_metrics_layout.dart';
part 'export_svg_folders_rendering.dart';

String _normalizeSvgPath(String path) => normalizeToPosixPath(path);

String _relativeSvgPath(String path, String from) =>
    p.posix.relative(_normalizeSvgPath(path), from: _normalizeSvgPath(from));

/// Rebases [normalizedPath] to [commonRoot] using normalized POSIX paths.
String _relativizeSvgPathFromCommonRoot({
  required String commonRoot,
  required String normalizedPath,
}) {
  final normalizedRoot = _normalizeSvgPath(commonRoot);
  final normalizedInput = _normalizeSvgPath(normalizedPath);
  if (p.posix.isAbsolute(normalizedInput)) {
    return p.posix.relative(normalizedInput, from: normalizedRoot);
  }
  if (normalizedRoot != '.' && normalizedInput.startsWith('$normalizedRoot/')) {
    return normalizedInput.substring(normalizedRoot.length + 1);
  }
  return normalizedInput;
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
  ProjectMetrics? projectMetrics,
}) {
  final dependencyGraph = layersResult.dependencyGraph;

  final layout = _buildFolderGraphLayoutContext(dependencyGraph);
  if (layout == null) {
    return generateEmptySvg('No hierarchical dependencies found');
  }

  final commonRoot = layout.commonRoot;
  final relativeGraph = layout.relativeGraph;
  final knownRelativeFiles = layout.knownRelativeFiles;
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
  final rootNode = layout.rootNode;
  final folderMetrics = layout.folderMetrics;
  final fileMetrics = layout.fileMetrics;
  final folderLevels = layout.folderLevels;
  final folderDependencies = layout.folderDependencies;
  final folderDepGraph = <String, List<String>>{};
  for (final edge in folderDependencies) {
    folderDepGraph
        .putIfAbsent(edge.sourceFolder, () => [])
        .add(edge.targetFolder);
  }
  final folderPositions = layout.folderPositions;
  final folderDimensions = layout.folderDimensions;
  final drawOrder = layout.drawOrder;
  final depthMap = layout.depthMap;

  final buffer = StringBuffer();

  writeSvgDocumentStart(
    buffer,
    width: layout.totalWidth,
    height: layout.totalHeight,
    includeUnifiedStyles: true,
    backgroundFill: '#f8f9fa',
  );

  // Draw hierarchical edges (parent-child relationships)
  _drawEdgeHorizontalCurve(
    buffer,
    drawOrder,
    folderPositions,
    folderDimensions,
    padding: _folderGraphFolderPadding,
    childIndent: _folderGraphChildIndent,
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
    headerHeight: _folderGraphHeaderHeight,
    fileItemHeight: _folderGraphFileItemHeight,
    fileItemSpacing: _folderGraphFileItemSpacing,
    fileTopPadding: _folderGraphFileTopPadding,
    projectName: projectName,
    projectVersion: projectVersion,
    inputFolderName: inputFolderName,
  );

  // Calculate the horizontal start of the folder column and file lane for aligned vertical edges
  final leftLaneGutterX = layout.leftLaneGutterX;
  final rightLaneGutterX = layout.rightLaneGutterX;

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

/// Returns the file dependency edges that render upward in the folders graph.
List<({String sourceFilePath, String targetFilePath})>
findRenderedUpwardFileEdgesInFolderGraph(
  Map<String, List<String>> dependencyGraph,
) {
  final layout = _buildFolderGraphLayoutContext(dependencyGraph);
  if (layout == null) {
    return const <({String sourceFilePath, String targetFilePath})>[];
  }

  final folderDepGraph = <String, List<String>>{};
  for (final edge in layout.folderDependencies) {
    folderDepGraph
        .putIfAbsent(edge.sourceFolder, () => <String>[])
        .add(edge.targetFolder);
  }

  final fileAnchors = <String, Map<String, Point<double>>>{};
  final fileVisuals = <_FileVisual>[];
  final titleVisuals = <_TitleVisual>[];
  final folderBadges = <BadgeModel>[];
  final folderPeers = buildPeerLists(folderDepGraph, labelFor: (path) => path);
  final filePeers = buildPeerLists(
    layout.relativeGraph,
    labelFor: (path) => path,
  );

  _drawHierarchicalFolders(
    StringBuffer(),
    layout.drawOrder,
    layout.folderPositions,
    layout.folderDimensions,
    layout.folderMetrics,
    layout.fileMetrics,
    layout.relativeGraph,
    fileAnchors,
    titleVisuals,
    fileVisuals,
    folderBadges,
    folderPeers.incoming,
    folderPeers.outgoing,
    filePeers.incoming,
    filePeers.outgoing,
    layout.depthMap,
    folderSeverityByPath: const <String, String>{},
    fileSeverityByPath: const <String, String>{},
    folderWarningsByPath: const <String, Map<String, int>>{},
    fileWarningsByPath: const <String, Map<String, int>>{},
    headerHeight: _folderGraphHeaderHeight,
    fileItemHeight: _folderGraphFileItemHeight,
    fileItemSpacing: _folderGraphFileItemSpacing,
    fileTopPadding: _folderGraphFileTopPadding,
    projectName: 'unknown',
    projectVersion: 'unknown',
    inputFolderName: '.',
  );

  final fileYByPath = <String, double>{
    for (final visual in fileVisuals) visual.path: visual.textY,
  };
  final upwardEdges = <({String sourceFilePath, String targetFilePath})>[];
  final seenEdges = <String>{};
  for (final entry in layout.relativeGraph.entries) {
    final sourceY = fileYByPath[entry.key];
    if (sourceY == null) {
      continue;
    }

    for (final targetFile in entry.value) {
      final targetY = fileYByPath[targetFile];
      if (targetY == null || sourceY <= targetY) {
        continue;
      }

      final sourceOriginal =
          layout.originalPathByRelative[entry.key] ?? entry.key;
      final targetOriginal =
          layout.originalPathByRelative[targetFile] ?? targetFile;
      final edgeKey = '$sourceOriginal->$targetOriginal';
      if (!seenEdges.add(edgeKey)) {
        continue;
      }

      upwardEdges.add((
        sourceFilePath: sourceOriginal,
        targetFilePath: targetOriginal,
      ));
    }
  }

  return upwardEdges;
}

/// Builds the reported layers issue list so reports match folders-SVG warnings.
List<LayersIssue> buildReportedLayersIssuesFromFolderGraph(
  LayersAnalysisResult layersResult,
) {
  final issues = List<LayersIssue>.from(layersResult.issues);
  final existingEdgeKeys = <String>{
    for (final issue in issues)
      if (issue.type == LayersIssueType.wrongFolderLayer)
        if (_extractReportedLayerTargetPath(issue.message)
            case final targetPath?)
          '${issue.filePath}->$targetPath',
  };

  for (final edge in findRenderedUpwardFileEdgesInFolderGraph(
    layersResult.dependencyGraph,
  )) {
    final edgeKey = '${edge.sourceFilePath}->${edge.targetFilePath}';
    if (!existingEdgeKeys.add(edgeKey)) {
      continue;
    }

    issues.add(
      LayersIssue(
        type: LayersIssueType.wrongFolderLayer,
        filePath: edge.sourceFilePath,
        message: AppStrings.renderedUpwardFolderDependency(edge.targetFilePath),
      ),
    );
  }

  return issues;
}

/// Extracts the target file path from a reported layers issue message.
String? _extractReportedLayerTargetPath(String message) {
  final match = RegExp(
    r'depends on file "([^"]+)"',
    caseSensitive: false,
  ).firstMatch(message);
  return match?.group(1);
}

/// Builds the shared folders-SVG layout context used during rendering.
_FolderGraphLayoutContext? _buildFolderGraphLayoutContext(
  Map<String, List<String>> dependencyGraph,
) {
  if (dependencyGraph.isEmpty) {
    return null;
  }

  final allAbsolutePaths = _collectAllFilePaths(dependencyGraph);
  final commonRoot = _findCommonRoot(allAbsolutePaths);
  final relativeGraph = _relativizeGraph(dependencyGraph, commonRoot);
  final knownRelativeFiles = _collectAllFilePaths(relativeGraph);
  final originalPathByRelative = <String, String>{};
  for (final entry in dependencyGraph.entries) {
    originalPathByRelative[_relativeSvgPath(entry.key, commonRoot)] = entry.key;
    for (final target in entry.value) {
      originalPathByRelative[_relativeSvgPath(target, commonRoot)] = target;
    }
  }

  final rootNode = _buildFolderHierarchy(knownRelativeFiles.toList());
  final folderMetrics = _calculateFolderMetrics(relativeGraph, rootNode);
  final fileMetrics = _calculateFileMetrics(relativeGraph);
  final folderLevels = _computeFolderLevels(relativeGraph, rootNode);
  final folderDependencies = _collectFolderDependencies(
    relativeGraph,
    rootNode,
  );

  final totalFileEdges = relativeGraph.values.fold<int>(
    0,
    (sum, list) => sum + list.length,
  );
  final fileEdgeExtraWidth =
      _folderGraphEdgeLanePadding +
      (_folderGraphEdgeLaneBaseWidth + totalFileEdges * _edgeLaneStepWidth);
  final folderEdgeExtraWidth =
      _folderGraphEdgeLanePadding +
      (_folderGraphEdgeLaneBaseWidth +
          folderDependencies.length * _edgeLaneStepWidth);

  final folderPositions = <String, Point<double>>{};
  final folderDimensions = <String, Rect>{};
  final maxFileNameChars = knownRelativeFiles
      .map((path) => path.split('/').last.length)
      .fold<int>(0, (left, right) => left > right ? left : right);
  final labelWidth =
      (maxFileNameChars * _folderGraphCharToPixelFactor) +
      _folderGraphLabelPadding;

  final rootSize = _computeFolderDimensions(
    rootNode,
    folderDimensions,
    labelWidth: labelWidth,
    folderLevels: folderLevels,
    baseWidth: _folderGraphBaseFolderWidth,
    padding: _folderGraphFolderPadding,
    childIndent: _folderGraphChildIndent,
    childSpacing: _folderGraphChildSpacing,
    headerHeight: _folderGraphHeaderHeight,
    fileItemHeight: _folderGraphFileItemHeight,
    fileItemSpacing: _folderGraphFileItemSpacing,
    fileTopPadding: _folderGraphFileTopPadding,
    filesToChildrenSpacing: _folderGraphFilesToChildrenSpacing,
  );

  _positionFolders(
    rootNode,
    folderPositions,
    folderDimensions,
    folderLevels: folderLevels,
    startX: _folderGraphMargin + folderEdgeExtraWidth,
    startY: _folderGraphMargin,
    padding: _folderGraphFolderPadding,
    childIndent: _folderGraphChildIndent,
    childSpacing: _folderGraphChildSpacing,
    headerHeight: _folderGraphHeaderHeight,
    fileItemHeight: _folderGraphFileItemHeight,
    fileItemSpacing: _folderGraphFileItemSpacing,
    fileTopPadding: _folderGraphFileTopPadding,
    filesToChildrenSpacing: _folderGraphFilesToChildrenSpacing,
  );

  final totalWidth =
      _folderGraphMargin +
      folderEdgeExtraWidth +
      rootSize.width +
      fileEdgeExtraWidth +
      _folderGraphMargin;
  final totalHeight = _folderGraphMargin + rootSize.height + _folderGraphMargin;

  return _FolderGraphLayoutContext(
    commonRoot: commonRoot,
    relativeGraph: relativeGraph,
    originalPathByRelative: originalPathByRelative,
    knownRelativeFiles: knownRelativeFiles,
    rootNode: rootNode,
    folderDependencies: folderDependencies,
    folderMetrics: folderMetrics,
    fileMetrics: fileMetrics,
    folderLevels: folderLevels,
    folderPositions: folderPositions,
    folderDimensions: folderDimensions,
    drawOrder: _collectDepthFirst(rootNode),
    depthMap: _computeDepths(rootNode),
    totalWidth: totalWidth,
    totalHeight: totalHeight,
    leftLaneGutterX: _folderGraphMargin + folderEdgeExtraWidth,
    rightLaneGutterX:
        _folderGraphMargin + folderEdgeExtraWidth + rootSize.width,
  );
}

/// Aggregates severity per relative file path for folder SVG rendering.
Map<String, String> _buildRelativeFileSeverityByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final severityByPath = <String, String>{};

  void push(String filePath, String? severity) {
    if (filePath.isEmpty) {
      return;
    }
    final normalized = _normalizeSvgPath(filePath);
    final relative = resolvePathToKnown(
      _relativizeSvgPathFromCommonRoot(
        commonRoot: commonRoot,
        normalizedPath: normalized,
      ),
      knownRelativeFiles,
      fallbackToNormalized: true,
    );
    if (relative == null || relative == '.' || relative.isEmpty) {
      return;
    }
    severityByPath[relative] = _maxSeverity(severityByPath[relative], severity);
  }

  for (final issue in issues) {
    push(issue.filePath, severityForLayersIssueType(issue.type));
  }

  if (projectMetrics != null) {
    if (projectMetrics.usesLocalization) {
      for (final issue in projectMetrics.hardcodedStringIssues) {
        push(issue.filePath, 'warning');
      }
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

/// Aggregates severity per relative folder path for folder SVG rendering.
Map<String, String> _buildFolderSeverityByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  final severityByPath = <String, String>{};

  void pushFolder(String filePath, String? severity) {
    if (filePath.isEmpty) {
      return;
    }
    final normalized = _normalizeSvgPath(filePath);
    final relative = resolvePathToKnown(
      _relativizeSvgPathFromCommonRoot(
        commonRoot: commonRoot,
        normalizedPath: normalized,
      ),
      knownRelativeFiles,
      fallbackToNormalized: true,
    );
    if (relative == null || relative == '.' || relative.isEmpty) {
      return;
    }
    final folderPath = p.posix.dirname(relative);
    severityByPath[folderPath] = _maxSeverity(
      severityByPath[folderPath],
      severity,
    );
  }

  for (final issue in issues) {
    if (issue.filePath.isEmpty) {
      continue;
    }
    final normalized = _normalizeSvgPath(issue.filePath);
    final relative = issue.type == LayersIssueType.folderCycle
        ? _relativizeSvgPathFromCommonRoot(
            commonRoot: commonRoot,
            normalizedPath: normalized,
          )
        : resolvePathToKnown(
            _relativizeSvgPathFromCommonRoot(
              commonRoot: commonRoot,
              normalizedPath: normalized,
            ),
            knownRelativeFiles,
            fallbackToNormalized: true,
          );
    if (relative == null || relative == '.' || relative.isEmpty) {
      continue;
    }
    final folderPath = issue.type == LayersIssueType.folderCycle
        ? relative
        : p.posix.dirname(relative);
    severityByPath[folderPath] = _maxSeverity(
      severityByPath[folderPath],
      severityForLayersIssueType(issue.type),
    );
  }

  if (projectMetrics != null) {
    if (projectMetrics.usesLocalization) {
      for (final issue in projectMetrics.hardcodedStringIssues) {
        pushFolder(issue.filePath, 'warning');
      }
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

/// Returns the strongest severity between [current] and [next].
String _maxSeverity(String? current, String? next) {
  if (next == null) {
    return current ?? '';
  }
  if (current == 'error' || next == 'error') {
    return 'error';
  }
  return next;
}

/// Maps severity label to folder/file node fill color.
String? _severityClassSuffix(String? severity) {
  if (severity == 'error') {
    return 'Error';
  }
  if (severity == 'warning') {
    return 'Warning';
  }
  return null;
}

/// Builds warning counters keyed by relative file path.
Map<String, Map<String, int>> _buildRelativeFileWarningsByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  return _buildRelativeWarningsByPath(
    issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
    keyForRelativePath: (relative) => relative,
  );
}

/// Builds warning counters keyed by relative folder path.
Map<String, Map<String, int>> _buildFolderWarningsByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
}) {
  return _buildRelativeWarningsByPath(
    issues,
    commonRoot,
    knownRelativeFiles: knownRelativeFiles,
    projectMetrics: projectMetrics,
    keyForRelativePath: p.posix.dirname,
  );
}

/// Shared warning aggregation for relative file/folder keys.
Map<String, Map<String, int>> _buildRelativeWarningsByPath(
  List<LayersIssue> issues,
  String commonRoot, {
  required Set<String> knownRelativeFiles,
  required ProjectMetrics? projectMetrics,
  required String Function(String) keyForRelativePath,
}) {
  final warningsByPath = <String, Map<String, int>>{};

  void add(String rawPath, String warningType) {
    if (rawPath.isEmpty) {
      return;
    }
    final relative = resolvePathToKnown(
      _relativizeSvgPathFromCommonRoot(
        commonRoot: commonRoot,
        normalizedPath: _normalizeSvgPath(rawPath),
      ),
      knownRelativeFiles,
      fallbackToNormalized: true,
    );
    if (relative == null || relative == '.' || relative.isEmpty) {
      return;
    }
    final key = keyForRelativePath(relative);
    final bucket = warningsByPath.putIfAbsent(key, () => <String, int>{});
    bucket[warningType] = (bucket[warningType] ?? 0) + 1;
  }

  for (final issue in issues) {
    add(issue.filePath, 'Layers');
  }
  if (projectMetrics != null) {
    if (projectMetrics.usesLocalization) {
      for (final issue in projectMetrics.hardcodedStringIssues) {
        add(issue.filePath, 'Hardcoded Strings');
      }
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

String _buildWarningTitle(String heading, Map<String, int>? warningTypeCounts) {
  return buildWarningTooltipTitle(heading, warningTypeCounts);
}
