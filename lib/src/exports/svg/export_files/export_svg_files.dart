import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';

/// Generates an SVG visualization of the dependency graph.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns an SVG string representing the dependency graph.
String exportGraphSvgFiles(
  LayersAnalysisResult layersResult, {
  ProjectMetrics? projectMetrics,
}) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return generateEmptySvg('No dependencies found');
  }

  // Use provided layers if available; otherwise fall back to a single layer 0 for all files.
  final effectiveLayers = layers.isNotEmpty
      ? layers
      : {
          for (final file in dependencyGraph.keys) file: 0,
          for (final deps in dependencyGraph.values)
            for (final t in deps) t: 0,
        };
  final knownPaths = effectiveLayers.keys.toSet();
  final fileSeverity = _buildFileSeverityByPath(
    layersResult.issues,
    knownPaths: knownPaths,
    projectMetrics: projectMetrics,
  );
  final fileWarnings = _buildFileWarningsByPath(
    layersResult.issues,
    knownPaths: knownPaths,
    projectMetrics: projectMetrics,
  );

  // Precompute cyclic edges
  final cyclicEdges = findCycleEdges(dependencyGraph, separator: '|');

  // Group files by layer
  final layerGroups = <int, List<String>>{};
  for (final entry in effectiveLayers.entries) {
    final layer = entry.value;
    final file = entry.key;
    layerGroups.putIfAbsent(layer, () => []).add(file);
  }

  // Remove duplicates and clean groups
  final cleanedLayerGroups = <int, List<String>>{};
  for (final layer in layerGroups.keys.toList()..sort()) {
    final uniqueFiles = layerGroups[layer]!.toSet().toList();
    if (uniqueFiles.isNotEmpty) {
      cleanedLayerGroups[layer] = uniqueFiles;
    }
  }

  // Sort layers by layer number (Layer 1 is left-most) 1..to.N
  final sortedLayers = cleanedLayerGroups.keys.toList()
    ..sort((a, b) => a.compareTo(b));

  // Sort files within each layer
  final incomingCounts = <String, int>{};
  final outgoingCounts = <String, int>{};

  // Calculate counts
  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    for (final target in entry.value) {
      if (effectiveLayers.containsKey(source) &&
          effectiveLayers.containsKey(target)) {
        outgoingCounts[source] = (outgoingCounts[source] ?? 0) + 1;
        incomingCounts[target] = (incomingCounts[target] ?? 0) + 1;
      }
    }
  }

  for (final layerNum in cleanedLayerGroups.keys) {
    cleanedLayerGroups[layerNum]!.sort((a, b) {
      // Sort priority: Incoming (desc), Outgoing (desc), Name (asc)
      final inDiff = (incomingCounts[b] ?? 0).compareTo(incomingCounts[a] ?? 0);
      if (inDiff != 0) return inDiff;

      final outDiff = (outgoingCounts[b] ?? 0).compareTo(
        outgoingCounts[a] ?? 0,
      );
      if (outDiff != 0) return outDiff;

      return a.split('/').last.compareTo(b.split('/').last);
    });
  }

  // --- Column Layout Dimensions ---
  const nodeWidth = 220;
  const nodeHeight = 50;
  const nodeVerticalSpacing = 20; // Space between nodes in a column
  const columnSpacing = 100; // Space between layer columns
  const margin = 50;
  const layerHeaderHeight = 40;
  const nodeLabelBaseFontSize = 14.0;
  const nodeLabelMinFontSize = 6.0;
  const nodeLabelHorizontalPadding = 16.0;

  // Badge constants
  const badgeOffset = 12;

  // Calculate total width based on number of columns
  final totalWidth =
      margin +
      (sortedLayers.length * nodeWidth) +
      ((sortedLayers.length - 1) * columnSpacing) +
      margin;

  // Calculate max nodes in any layer to determine height
  int maxNodes = 0;
  for (final files in cleanedLayerGroups.values) {
    if (files.length > maxNodes) maxNodes = files.length;
  }

  final totalHeight =
      margin +
      layerHeaderHeight +
      (maxNodes * nodeHeight) +
      ((maxNodes - 1) * nodeVerticalSpacing) +
      margin;

  final buffer = StringBuffer();

  writeSvgDocumentStart(
    buffer,
    width: totalWidth,
    height: totalHeight,
    includeUnifiedStyles: true,
    backgroundFill: 'white',
  );

  // 1. Calculate positions
  final nodePositions = <String, Point<double>>{};
  final colIndexByFile = <String, int>{};

  for (var colIndex = 0; colIndex < sortedLayers.length; colIndex++) {
    final layerNum = sortedLayers[colIndex];
    final files = cleanedLayerGroups[layerNum]!;

    final x = margin + (colIndex * (nodeWidth + columnSpacing));
    var y = margin + layerHeaderHeight;

    for (final file in files) {
      nodePositions[file] = Point(x.toDouble(), y.toDouble());
      colIndexByFile[file] = colIndex;
      y += nodeHeight + nodeVerticalSpacing;
    }
  }

  // Maps column index → list of files in that column (same order as layout).
  final colFilesByIndex = <int, List<String>>{
    for (var i = 0; i < sortedLayers.length; i++)
      i: cleanedLayerGroups[sortedLayers[i]]!,
  };

  // 2. Draw Layer Columns (Backgrounds)
  for (var colIndex = 0; colIndex < sortedLayers.length; colIndex++) {
    /// Divisor for halving dimensions.
    const double halfDivisor = 2.0;

    /// Factor for column spacing offset.
    const double columnMarginFactor = 4.0;

    /// Corner radius for layer background rectangles.
    const double layerCornerRadius = 8.0;

    /// Vertical offset for the layer title text.
    const double titleVerticalOffset = 25.0;

    final layerNum = sortedLayers[colIndex];
    final x =
        margin +
        (colIndex * (nodeWidth + columnSpacing)) -
        (columnSpacing / columnMarginFactor);
    final width = nodeWidth + (columnSpacing / halfDivisor);
    // Draw column background
    buffer.writeln(
      '<rect x="$x" y="$margin" width="$width" height="${totalHeight - margin * halfDivisor}" rx="$layerCornerRadius" class="layerBackground"/>',
    );
    // Draw layer title
    buffer.writeln(
      '<text x="${x + width / halfDivisor}" y="${margin + titleVerticalOffset}" class="layerTitle">$layerNum</text>',
    );
  }

  // 3. Draw Node Rectangles
  for (final entry in nodePositions.entries) {
    final filePath = entry.key;
    final pos = entry.value;
    final severity = fileSeverity[filePath];
    final severityClass = _severityClassForFileNode(severity);
    final classAttribute = severityClass == null
        ? 'fileNode'
        : 'fileNode $severityClass';
    final title = _buildNodeTitle(filePath, fileWarnings[filePath]);
    buffer.writeln(
      '<rect x="${pos.x}" y="${pos.y}" width="$nodeWidth" height="$nodeHeight" class="$classAttribute"><title>$title</title></rect>',
    );
  }

  // Pre-compute lane slots for forward (sourceCol < targetCol) edges.
  // Edges are grouped by the column gap they route through — the gap just
  // before the target column (gapKey = targetColIdx - 1). All edges entering
  // the same target column share the same stagger pool so their vertical
  // segments are separated by _edgeLaneOffset pixels.
  final forwardEdgesByTargetGap = <int, List<(String, String)>>{};
  for (final fwdEntry in dependencyGraph.entries) {
    final src = fwdEntry.key;
    if (!nodePositions.containsKey(src)) continue;
    final srcCol = colIndexByFile[src] ?? 0;
    for (final tgt in fwdEntry.value) {
      if (!nodePositions.containsKey(tgt)) continue;
      final tgtCol = colIndexByFile[tgt] ?? 0;
      if (srcCol < tgtCol) {
        forwardEdgesByTargetGap.putIfAbsent(tgtCol - 1, () => []).add((
          src,
          tgt,
        ));
      }
    }
  }
  final edgeLaneIndices = <String, int>{};
  for (final gapEntry in forwardEdgesByTargetGap.entries) {
    // Sort descending by Y-span: longest (farthest target) gets laneIdx 0
    // → the leftmost (outermost) lane.  Shortest (nearest target) gets the
    // rightmost (innermost) lane.  This ensures that no horizontal exit
    // segment ever crosses the vertical segment of another edge in the same
    // bundle — the classic "no-crossing fan-out" assignment.
    final gapEdges = List<(String, String)>.from(gapEntry.value)
      ..sort((a, b) {
        final aSpan = _edgeYSpan(a.$1, a.$2, nodePositions, nodeHeight);
        final bSpan = _edgeYSpan(b.$1, b.$2, nodePositions, nodeHeight);
        return bSpan.compareTo(
          aSpan,
        ); // descending: longest → index 0 → leftmost
      });
    for (var i = 0; i < gapEdges.length; i++) {
      edgeLaneIndices['${gapEdges[i].$1}|${gapEdges[i].$2}'] = i;
    }
  }

  // 4. Build and sort all edges by Y-span descending, then render.
  // Painting longest-span edges first (deepest vertical reach) puts them
  // behind shorter edges.  Shorter-span and near-straight edges are painted
  // last, on top, so the close connections always appear clean and unobscured.
  final edgeRenderList =
      <
        ({
          String source,
          String target,
          String pathData,
          String cssClass,
          double span,
        })
      >[];

  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    final targets = entry.value;

    if (!nodePositions.containsKey(source)) continue;
    final sourcePos = nodePositions[source]!;
    final sourceColIdx = colIndexByFile[source] ?? 0;

    for (final target in targets) {
      if (!nodePositions.containsKey(target)) continue;
      final targetPos = nodePositions[target]!;
      final targetColIdx = colIndexByFile[target] ?? 0;

      // Anchor points: vertically centred on the source/target node.
      /// Divisor for halving dimensions.
      const double halfDivisor = 2.0;

      final startX = sourcePos.x + nodeWidth; // Outgoing badge position
      final startY = sourcePos.y + nodeHeight / halfDivisor; // Vertical center

      final endX =
          targetPos.x + (badgeOffset / halfDivisor); // Incoming badge position
      final endY = targetPos.y + nodeHeight / halfDivisor; // Vertical center

      final isCycle = cyclicEdges.contains('$source|$target');
      final extraClass = isCycle ? ' cycleEdge' : '';
      final span = (endY - startY).abs();

      final String pathData;
      if (sourceColIdx < targetColIdx) {
        final colDiff = targetColIdx - sourceColIdx;
        if (colDiff == 1 && span < 1.0) {
          // Adjacent column, same row: near-straight 1px-belly Bezier.
          // A pure H path produces a zero-height bounding box which causes
          // SVG objectBoundingBox gradients to render as invisible.
          final midX = (startX + endX) / halfDivisor;
          pathData =
              'M $startX $startY '
              'C $midX ${startY - _edgeStraightBellyHeight}, '
              '$midX ${startY - _edgeStraightBellyHeight}, '
              '$endX $endY';
        } else {
          // Elbow routing through the gap just before the target column.
          final gapKey = targetColIdx - 1;
          final laneIdx = edgeLaneIndices['$source|$target'] ?? 0;
          final gapLeftX =
              (margin + gapKey * (nodeWidth + columnSpacing) + nodeWidth)
                  .toDouble();
          final targetLeftX =
              (margin + targetColIdx * (nodeWidth + columnSpacing)).toDouble();
          // Anchor lanes from the left edge of the gap and grow rightward.
          // This guarantees laneX is always inside the gap [gapLeftX, targetLeftX]
          // regardless of how many edges share the same pool — preventing the
          // backward H that occurs when a centered pool overflows into the
          // preceding column.
          final minLaneX = gapLeftX + _fileEdgeCornerRadius;
          final maxLaneX = targetLeftX - _fileEdgeCornerRadius;
          final laneX = (minLaneX + laneIdx * _edgeLaneOffset).clamp(
            minLaneX,
            maxLaneX,
          );

          if (colDiff == 1) {
            // Adjacent columns: single H-V-H elbow.
            pathData = _buildElbowEdgePath(startX, startY, endX, endY, laneX);
          } else {
            // Skip edge: route through intermediate column passage gaps so the
            // horizontal traversal never overlaps intermediate node boxes.
            final passageYs = <double>[];
            final gapCenterXsList = <double>[];
            final colRightXsList = <double>[];
            for (var c = sourceColIdx + 1; c < targetColIdx; c++) {
              final colLeftX = (margin + c * (nodeWidth + columnSpacing))
                  .toDouble();
              gapCenterXsList.add(colLeftX - columnSpacing / halfDivisor);
              colRightXsList.add(colLeftX + nodeWidth);
              final fraction =
                  (c - sourceColIdx) / (targetColIdx - sourceColIdx);
              final directY = startY + (endY - startY) * fraction;
              passageYs.add(
                _findBestPassageY(
                  colFilesByIndex[c] ?? const [],
                  nodePositions,
                  nodeHeight,
                  nodeVerticalSpacing,
                  directY,
                ),
              );
            }
            pathData = _buildMultiHopElbowPath(
              startX,
              startY,
              endX,
              endY,
              laneX,
              passageYs: passageYs,
              gapCenterXs: gapCenterXsList,
              colRightXs: colRightXsList,
            );
          }
        }
      } else {
        // Same-column or backward (cycle) edge: Bezier arcing downward.
        pathData = _buildBezierEdgePath(startX, startY, endX, endY);
      }

      edgeRenderList.add((
        source: source,
        target: target,
        pathData: pathData,
        cssClass: 'edge$extraClass',
        span: span,
      ));
    }
  }

  // Sort: longest span first (painted behind), shortest last (painted in front).
  edgeRenderList.sort((a, b) => b.span.compareTo(a.span));

  for (final edge in edgeRenderList) {
    renderEdgeWithTooltip(
      buffer,
      pathData: edge.pathData,
      source: edge.source,
      target: edge.target,
      cssClass: edge.cssClass,
    );
  }

  // 5. Draw Node Content (Counters and Labels)

  final peers = buildPeerLists(dependencyGraph);
  final incomingNodes = peers.incoming;
  final outgoingNodes = peers.outgoing;

  for (final entry in nodePositions.entries) {
    /// Divisor for halving dimensions.
    const double halfDivisor0 = 2.0;

    final file = entry.key;
    final pos = entry.value;

    // Badges (Incoming/Outgoing) - Drawn BEFORE text
    final inCount = incomingCounts[file] ?? 0;
    final outCount = outgoingCounts[file] ?? 0;

    // Render incoming badge (left edge, vertically centred)
    final incomingBadge = BadgeModel.incoming(
      cx: pos.x + (badgeOffset / halfDivisor0),
      cy: pos.y + nodeHeight / halfDivisor0,
      count: inCount,
      peers: incomingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, incomingBadge);

    // Render outgoing badge (right edge, vertically centred)
    final outgoingBadge = BadgeModel.outgoing(
      cx: pos.x + nodeWidth,
      cy: pos.y + nodeHeight / halfDivisor0,
      count: outCount,
      peers: outgoingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, outgoingBadge);

    // Node Text (Filename) - Drawn LAST
    final fileName = file.split('/').last;
    final labelMaxWidth =
        nodeWidth - (nodeLabelHorizontalPadding * halfDivisor0);
    final textClass = fittedTextClass(
      fileName,
      maxWidth: labelMaxWidth,
      baseFontSize: nodeLabelBaseFontSize,
      minFontSize: nodeLabelMinFontSize,
    );

    buffer.writeln(
      '<text x="${pos.x + nodeWidth / halfDivisor0}" y="${pos.y + nodeHeight / halfDivisor0}" class="$textClass">$fileName</text>',
    );
  }

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}

/// Aggregates severity per file path from layer issues and project metrics.
Map<String, String> _buildFileSeverityByPath(
  List<LayersIssue> issues, {
  required Set<String> knownPaths,
  required ProjectMetrics? projectMetrics,
}) {
  final severityByPath = <String, String>{};
  void push(String filePath, String? severity) {
    if (filePath.isEmpty) {
      return;
    }
    final resolved = resolvePathToKnown(filePath, knownPaths);
    if (resolved == null) {
      return;
    }
    severityByPath[resolved] = _maxSeverity(severityByPath[resolved], severity);
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

/// Maps severity label to file-node fill color.
String? _severityClassForFileNode(String? severity) {
  if (severity == 'error') {
    return 'fileNodeError';
  }
  if (severity == 'warning') {
    return 'fileNodeWarning';
  }
  return null;
}

/// Aggregates warning counts per file path from all analyzers.
Map<String, Map<String, int>> _buildFileWarningsByPath(
  List<LayersIssue> issues, {
  required Set<String> knownPaths,
  required ProjectMetrics? projectMetrics,
}) {
  final warningsByPath = <String, Map<String, int>>{};
  void add(String filePath, String warningType) {
    if (filePath.isEmpty) {
      return;
    }
    final resolved = resolvePathToKnown(filePath, knownPaths);
    if (resolved == null) {
      return;
    }
    final bucket = warningsByPath.putIfAbsent(resolved, () => <String, int>{});
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

String _buildNodeTitle(String filePath, Map<String, int>? warnings) {
  return buildWarningTooltipTitle('File: $filePath', warnings);
}

/// Pixel increment between parallel edge lanes in the same column gap.
const double _edgeLaneOffset = 2.0;

/// Minimum belly applied to same-row adjacent edges.
///
/// A pure horizontal `H` path has a zero-height bounding box which causes
/// SVG `objectBoundingBox` gradients to render as invisible. A 1 px upward
/// arc is imperceptible to the eye but gives the path a non-zero height.
const double _edgeStraightBellyHeight = 1.0;

/// Reusable divisor for halving a dimension at file scope.
const double _halfDivisor = 2.0;

/// Downward arc applied to backward/cycle Bezier control points.
///
/// Ensures the path bounding box is never zero-height even when source and
/// target nodes share the same Y (which would break the horizontal SVG gradient).
const double _bezierBellyHeight = 16.0;

/// Corner radius for elbow turns in edge paths.
const double _fileEdgeCornerRadius = 6.0;

/// Builds a multi-hop elbow path through one or more intermediate column
/// passage gaps so the edge never visually crosses an intermediate node box.
///
/// For each intermediate column the vertical transition runs at [gapCenterXs[i]]
/// (centre of the gap to the left of the column), and the horizontal traversal
/// crosses the column at [passageYs[i]] (nearest inter-node gap centre).
/// The final vertical uses the staggered [laneX] in the gap before the target.
String _buildMultiHopElbowPath(
  double startX,
  double startY,
  double endX,
  double endY,
  double laneX, {
  required List<double> passageYs,
  required List<double> gapCenterXs,
  required List<double> colRightXs,
}) {
  const double r = _fileEdgeCornerRadius;
  final buf = StringBuffer();
  buf.write('M $startX $startY ');
  double currentY = startY;

  for (var i = 0; i < passageYs.length; i++) {
    final gcX = gapCenterXs[i];
    final crX = colRightXs[i];
    final py = passageYs[i];
    final dy = py - currentY;
    final dirY = dy >= 0 ? 1.0 : -1.0;

    if (dy.abs() < r * _halfDivisor) {
      buf.write('H $crX ');
    } else {
      buf.write('H ${gcX - r} ');
      buf.write('Q $gcX $currentY $gcX ${currentY + dirY * r} ');
      buf.write('V ${py - dirY * r} ');
      buf.write('Q $gcX $py ${gcX + r} $py ');
      buf.write('H $crX ');
      currentY = py;
    }
  }

  // Final elbow at laneX in the gap before the target column.
  final finalDy = endY - currentY;
  final finalDirY = finalDy >= 0 ? 1.0 : -1.0;
  if (finalDy.abs() < r * _halfDivisor) {
    buf.write('H $laneX V $endY H $endX');
  } else {
    buf.write('H ${laneX - r} ');
    buf.write('Q $laneX $currentY $laneX ${currentY + finalDirY * r} ');
    buf.write('V ${endY - finalDirY * r} ');
    buf.write('Q $laneX $endY ${laneX + r} $endY ');
    buf.write('H $endX');
  }
  return buf.toString();
}

/// Returns the Y-centre of the inter-node gap in [files] that is nearest to
/// [targetY], used to route skip edges through intermediate columns without
/// visually crossing node boxes.
double _findBestPassageY(
  List<String> files,
  Map<String, Point<double>> nodePositions,
  int nodeHeight,
  int nodeVerticalSpacing,
  double targetY,
) {
  if (files.isEmpty) return targetY;
  final sortedNodeYs =
      files.map((f) => nodePositions[f]?.y).whereType<double>().toList()
        ..sort();
  if (sortedNodeYs.isEmpty) return targetY;
  final halfSpacing = nodeVerticalSpacing / _halfDivisor;
  final candidates = [
    sortedNodeYs.first - halfSpacing,
    for (var i = 0; i < sortedNodeYs.length - 1; i++)
      sortedNodeYs[i] + nodeHeight + halfSpacing,
    sortedNodeYs.last + nodeHeight + halfSpacing,
  ];
  return candidates.reduce(
    (best, c) => (c - targetY).abs() < (best - targetY).abs() ? c : best,
  );
}

/// Builds an orthogonal H-V-H elbow path with rounded corners.
///
/// Routes from ([startX], [startY]) horizontally to [laneX], then
/// vertically to [endY], then horizontally to ([endX], [endY]).
String _buildElbowEdgePath(
  double startX,
  double startY,
  double endX,
  double endY,
  double laneX,
) {
  final dirY = endY >= startY ? 1.0 : -1.0;
  final h1End = laneX - _fileEdgeCornerRadius;
  final v1Start = startY + dirY * _fileEdgeCornerRadius;
  final v2End = endY - dirY * _fileEdgeCornerRadius;
  final h2Start = laneX + _fileEdgeCornerRadius;
  // Guard against a near-zero vertical span (two nodes at nearly the same Y).
  if ((endY - startY).abs() < _fileEdgeCornerRadius * _halfDivisor) {
    return 'M $startX $startY H $laneX V $endY H $endX';
  }
  return 'M $startX $startY '
      'H $h1End '
      'Q $laneX $startY $laneX $v1Start '
      'V $v2End '
      'Q $laneX $endY $h2Start $endY '
      'H $endX';
}

/// Builds a smooth cubic Bezier path for backward or same-column edges.
///
/// Control points spread horizontally so the edge forms a visible arc.
/// Both control points are offset downward by [_bezierBellyHeight] so the
/// path never has a zero-height bounding box (which would break the
/// horizontal SVG gradient) even when source and target share the same Y.
String _buildBezierEdgePath(
  double startX,
  double startY,
  double endX,
  double endY,
) {
  const double controlPointFactor = 0.5;
  final dx = (endX - startX).abs();
  final controlX1 = startX + dx * controlPointFactor;
  final controlX2 = endX - dx * controlPointFactor;
  final cy1 = startY + _bezierBellyHeight;
  final cy2 = endY + _bezierBellyHeight;
  return 'M $startX $startY C $controlX1 $cy1, $controlX2 $cy2, $endX $endY';
}

/// Returns the absolute Y distance between edge anchor points (badge centres).
double _edgeYSpan(
  String source,
  String target,
  Map<String, Point<double>> nodePositions,
  int nodeHeight,
) {
  final sourcePos = nodePositions[source];
  final targetPos = nodePositions[target];
  if (sourcePos == null || targetPos == null) return double.infinity;
  const double halfDivisor = 2.0;
  final startY = sourcePos.y + nodeHeight / halfDivisor;
  final endY = targetPos.y + nodeHeight / halfDivisor;
  return (endY - startY).abs();
}
