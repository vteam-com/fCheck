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
  const minColumnSpacing = 100; // Minimum space between layer columns
  const margin = 50;
  const layerHeaderHeight = 40;
  const nodeLabelBaseFontSize = 14.0;
  const nodeLabelMinFontSize = 6.0;
  const nodeLabelHorizontalPadding = 16.0;

  // Badge constants
  const badgeOffset = 12;

  // --- Dynamic per-gap column spacing ---
  // Count how many forward edges cross each gap. An edge from col s to col t
  // crosses gaps s, s+1, ..., t-1. The gap must be wide enough for all lanes.
  final colIndexByFileEarly = <String, int>{};
  for (var colIndex = 0; colIndex < sortedLayers.length; colIndex++) {
    final layerNum = sortedLayers[colIndex];
    for (final file in cleanedLayerGroups[layerNum]!) {
      colIndexByFileEarly[file] = colIndex;
    }
  }

  final numGaps = sortedLayers.length - 1;
  final edgesPerGap = List<int>.filled(numGaps > 0 ? numGaps : 0, 0);
  for (final entry in dependencyGraph.entries) {
    final src = entry.key;
    final srcCol = colIndexByFileEarly[src];
    if (srcCol == null) continue;
    for (final tgt in entry.value) {
      final tgtCol = colIndexByFileEarly[tgt];
      if (tgtCol == null) continue;
      final lo = srcCol < tgtCol ? srcCol : tgtCol;
      final hi = srcCol < tgtCol ? tgtCol : srcCol;
      for (var g = lo; g < hi; g++) {
        edgesPerGap[g]++;
      }
    }
  }

  // Compute per-gap spacing: enough room for all lanes plus corner radii.
  final gapSpacings = List<double>.generate(numGaps, (g) {
    final lanesNeeded = edgesPerGap[g];
    final neededWidth =
        _fileEdgeCornerRadius * _bothSides +
        _edgeLaneOffset * (lanesNeeded + 1);
    return neededWidth > minColumnSpacing
        ? neededWidth
        : minColumnSpacing.toDouble();
  });

  // Build cumulative column left-X positions.
  final colLeftXPositions = List<double>.generate(sortedLayers.length, (i) {
    var x = margin.toDouble();
    for (var g = 0; g < i; g++) {
      x += nodeWidth + gapSpacings[g];
    }
    return x;
  });

  // Calculate total width from cumulative positions.
  final totalWidth =
      (colLeftXPositions.isNotEmpty
          ? colLeftXPositions.last + nodeWidth
          : margin + nodeWidth) +
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
    width: totalWidth.toInt(),
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

    final x = colLeftXPositions[colIndex];
    var y = margin + layerHeaderHeight;

    for (final file in files) {
      nodePositions[file] = Point(x, y.toDouble());
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
    /// Factor for column spacing offset.
    const double columnMarginFactor = 4.0;

    /// Corner radius for layer background rectangles.
    const double layerCornerRadius = 8.0;

    /// Vertical offset for the layer title text.
    const double titleVerticalOffset = 25.0;

    final layerNum = sortedLayers[colIndex];
    final gapBefore = colIndex > 0
        ? gapSpacings[colIndex - 1]
        : minColumnSpacing.toDouble();
    final gapAfter = colIndex < numGaps
        ? gapSpacings[colIndex]
        : minColumnSpacing.toDouble();
    final x = colLeftXPositions[colIndex] - (gapBefore / columnMarginFactor);
    final width = nodeWidth + (gapBefore + gapAfter) / columnMarginFactor;
    // Draw column background
    buffer.writeln(
      '<rect x="$x" y="$margin" width="$width" height="${totalHeight - margin * _halfDivisor}" rx="$layerCornerRadius" class="layerBackground"/>',
    );
    // Draw layer title
    buffer.writeln(
      '<text x="${x + width / _halfDivisor}" y="${margin + titleVerticalOffset}" class="layerTitle">$layerNum</text>',
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

  // Assign lane indices per source-side gap (column) so all edges sharing the
  // same gap still get unique staggered X lanes. Within each source node we
  // order farthest-target edges first so the longest-reach edges get the
  // leftmost lane and shortest-reach edges get the rightmost, producing a
  // clean nested visual in the vertical bundle.
  final sourceGapLaneIndices = <String, int>{};
  final edgesBySourceGap = <int, List<(String, String)>>{};
  for (final fwdEntry in dependencyGraph.entries) {
    final src = fwdEntry.key;
    if (!nodePositions.containsKey(src)) continue;
    final srcCol = colIndexByFile[src] ?? 0;
    for (final tgt in fwdEntry.value) {
      if (!nodePositions.containsKey(tgt)) continue;
      final tgtCol = colIndexByFile[tgt] ?? 0;
      if (srcCol < tgtCol) {
        edgesBySourceGap.putIfAbsent(srcCol, () => []).add((src, tgt));
      }
    }
  }
  for (final gapEntry in edgesBySourceGap.entries) {
    final edgesBySource = <String, List<(String, String)>>{};
    for (final edge in gapEntry.value) {
      edgesBySource.putIfAbsent(edge.$1, () => []).add(edge);
    }

    final orderedSources = edgesBySource.keys.toList()..sort();
    var laneIdx = 0;
    for (final src in orderedSources) {
      final srcCenterY =
          (nodePositions[src]?.y ?? 0) + nodeHeight / _halfDivisor;
      final sortedForSource =
          List<(String, String)>.from(edgesBySource[src] ?? const [])
            ..sort((a, b) {
              final aTargetCenterY =
                  (nodePositions[a.$2]?.y ?? 0) + nodeHeight / _halfDivisor;
              final bTargetCenterY =
                  (nodePositions[b.$2]?.y ?? 0) + nodeHeight / _halfDivisor;
              final aDeltaAbs = (aTargetCenterY - srcCenterY).abs();
              final bDeltaAbs = (bTargetCenterY - srcCenterY).abs();
              final deltaCompare = bDeltaAbs.compareTo(aDeltaAbs);
              if (deltaCompare != 0) return deltaCompare;

              final targetYCompare = bTargetCenterY.compareTo(aTargetCenterY);
              if (targetYCompare != 0) return targetYCompare;

              return '${a.$1}|${a.$2}'.compareTo('${b.$1}|${b.$2}');
            });

      for (final edge in sortedForSource) {
        sourceGapLaneIndices['${edge.$1}|${edge.$2}'] = laneIdx;
        laneIdx++;
      }
    }
  }

  // 4. Build and sort all edges by Y-span descending, then render.
  // Painting longest-span edges first (deepest vertical reach) puts them
  // behind shorter edges.  Shorter-span and straight/near-straight edges are painted
  // last, on top, so the close connections always appear clean and unobscured.
  final edgeRenderList =
      <
        ({
          String source,
          String target,
          String pathData,
          String cssClass,
          double span,
          int colDiff,
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
      final startX = sourcePos.x + nodeWidth; // Outgoing badge center X
      final startY = sourcePos.y + nodeHeight / _halfDivisor; // Vertical center

      final endX =
          targetPos.x + (badgeOffset / _halfDivisor); // Incoming badge center X
      final endY = targetPos.y + nodeHeight / _halfDivisor; // Vertical center

      final isCycle = cyclicEdges.contains('$source|$target');
      final extraClass = isCycle ? ' cycleEdge' : '';
      final span = (endY - startY).abs();

      final String pathData;
      final int colDiff;
      if (sourceColIdx < targetColIdx) {
        colDiff = targetColIdx - sourceColIdx;

        // The left edge of the target column box — used for lane gap bounds.
        final targetLeftX = colLeftXPositions[targetColIdx];

        // Actual triangle tip positions computed from badge geometry so the
        // edge path visually touches each badge's pointed tip.
        final sourceBadgeTipX =
            startX +
            BadgeModel.tipOffsetFromCenter(outgoingCounts[source] ?? 0);
        final targetBadgeTipX =
            endX - BadgeModel.baseOffsetFromCenter(incomingCounts[target] ?? 0);

        if (colDiff == 1 && span < 1.0) {
          // Adjacent column, same row: use a near-straight cubic with a tiny
          // belly so the path has non-zero height and remains visible with
          // objectBoundingBox gradients.
          final midX = (sourceBadgeTipX + endX) / _halfDivisor;
          pathData =
              'M $sourceBadgeTipX $startY '
              'C $midX ${startY - _edgeStraightBellyHeight}, '
              '$midX ${endY - _edgeStraightBellyHeight}, '
              '$endX $endY';
        } else {
          // Elbow routing through the gap just before the target column.
          final gapKey = targetColIdx - 1;
          final laneIdx = sourceGapLaneIndices['$source|$target'] ?? 0;
          final gapLeftX = colLeftXPositions[gapKey] + nodeWidth;
          // minLaneX must be past the outgoing badge tip so that the exit
          // horizontal (badge tip → laneX-r, startY) always travels rightward.
          // For colDiff==1 gapLeftX == startX (the badge sits inside the gap),
          // so we clamp to sourceBadgeTipX.  For colDiff>1 gapLeftX is already
          // far past the badge, so the max() has no effect.
          // Reserve the source tip column for the direct edge so routed lanes
          // never start on the same pixel column at the badge tip.
          final minLaneX =
              (sourceBadgeTipX > gapLeftX ? sourceBadgeTipX : gapLeftX) +
              _fileEdgeCornerRadius +
              _edgeLaneOffset;
          final maxLaneX = targetLeftX - _fileEdgeCornerRadius;
          final laneX = (minLaneX + laneIdx * _edgeLaneOffset).clamp(
            minLaneX,
            maxLaneX,
          );

          // Source-side lane X: the X column used for the FIRST vertical turn
          // for every forward edge from this source (adjacent AND skip alike).
          // Anchored to the gap immediately right of the source badge so that
          // all outgoing edges share one compact continuous incremental band
          // with no gap between adjacent-column and skip edges.
          final srcImmGapLeftX = colLeftXPositions[sourceColIdx] + nodeWidth;
          final srcMinLaneX =
              (sourceBadgeTipX > srcImmGapLeftX
                  ? sourceBadgeTipX
                  : srcImmGapLeftX) +
              _fileEdgeCornerRadius +
              _edgeLaneOffset;
          final sourceSideLaneX = srcMinLaneX + laneIdx * _edgeLaneOffset;

          if (colDiff == 1) {
            // Adjacent columns: fixed-radius elbow from the badge tip into the
            // shared lane, then a final fixed-radius elbow into the target.
            final dirY =
                (endY - startY).abs() < _fileEdgeCornerRadius * _halfDivisor
                ? 0.0
                : (endY > startY ? 1.0 : -1.0);
            if (dirY == 0.0) {
              // Near-zero vertical span: diagonal to lane then converge to
              // badge centre Y so the arrival stays within the badge.
              pathData =
                  'M $sourceBadgeTipX $startY '
                  'L $sourceSideLaneX $startY '
                  'L $targetBadgeTipX $endY '
                  'L $endX $endY';
            } else {
              final r = _fileEdgeCornerRadius;
              final v1Start = startY + dirY * r;
              final v2End = endY - dirY * r;
              pathData =
                  'M $sourceBadgeTipX $startY '
                  'L ${sourceSideLaneX - r} $startY '
                  'Q $sourceSideLaneX $startY $sourceSideLaneX $v1Start '
                  'V $v2End '
                  'Q $sourceSideLaneX $endY ${sourceSideLaneX + r} $endY '
                  'L $targetBadgeTipX $endY '
                  'L $endX $endY';
            }
          } else {
            // Skip edge: route through intermediate column passage gaps so the
            // horizontal traversal never overlaps intermediate node boxes.
            final passageYs = <double>[];
            final gapCenterXsList = <double>[];
            final colRightXsList = <double>[];
            for (var c = sourceColIdx + 1; c < targetColIdx; c++) {
              final colLeftX = colLeftXPositions[c];
              final gapBeforeC = gapSpacings[c - 1];
              gapCenterXsList.add(colLeftX - gapBeforeC / _halfDivisor);
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
            // The multi-hop builder starts at the badge tip and routes
            // to the incoming badge tip. Final L converges to badge centre.
            //
            // The FIRST intermediate passage uses sourceSideLaneX so that
            // adjacent and skip edges share one compact continuous band in the
            // gap immediately right of the source — no visual gap between them.
            // Subsequent passages (index > 0) use a consistent lane offset.
            final edgeKey = '$source|$target';
            final laneOffset =
                (sourceGapLaneIndices[edgeKey] ?? 0) * _edgeLaneOffset;
            final gapOffsets = <double>[
              if (gapCenterXsList.isNotEmpty)
                sourceSideLaneX -
                    gapCenterXsList[0], // align 1st passage to shared source band
              for (var i = 1; i < gapCenterXsList.length; i++) laneOffset,
            ];
            pathData =
                '${_buildMultiHopElbowPath(targetLeftX, endY, laneX, passageYs: passageYs, gapCenterXs: gapCenterXsList, colRightXs: colRightXsList, badgeTipX: sourceBadgeTipX, badgeTipY: startY, badgeCenterY: endY, gapOffsets: gapOffsets)} L $endX $endY';
          }
        }
      } else {
        // Same-column or backward (cycle) edge: Bezier arcing downward.
        colDiff = 0;
        pathData = _buildBezierEdgePath(startX, startY, endX, endY);
      }

      edgeRenderList.add((
        source: source,
        target: target,
        pathData: pathData,
        cssClass: 'edge$extraClass',
        span: span,
        colDiff: colDiff,
      ));
    }
  }

  // Sort globally by vertical span descending: long-reach edges are painted
  // first (behind), short-reach edges last (on top). This keeps the vertical
  // lane bundle ordered so that the outermost (longest) edges sit behind the
  // innermost (shortest) edges, producing a clean nested visual.
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
    final file = entry.key;
    final pos = entry.value;

    // Badges (Incoming/Outgoing) - Drawn BEFORE text
    final inCount = incomingCounts[file] ?? 0;
    final outCount = outgoingCounts[file] ?? 0;

    // Render incoming badge (left edge, vertically centred)
    final incomingBadge = BadgeModel.incoming(
      cx: pos.x + (badgeOffset / _halfDivisor),
      cy: pos.y + nodeHeight / _halfDivisor,
      count: inCount,
      peers: incomingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, incomingBadge);

    // Render outgoing badge (right edge, vertically centred)
    final outgoingBadge = BadgeModel.outgoing(
      cx: pos.x + nodeWidth,
      cy: pos.y + nodeHeight / _halfDivisor,
      count: outCount,
      peers: outgoingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, outgoingBadge);

    // Node Text (Filename) - Drawn LAST
    final fileName = file.split('/').last;
    final labelMaxWidth =
        nodeWidth - (nodeLabelHorizontalPadding * _halfDivisor);
    final textClass = fittedTextClass(
      fileName,
      maxWidth: labelMaxWidth,
      baseFontSize: nodeLabelBaseFontSize,
      minFontSize: nodeLabelMinFontSize,
    );

    buffer.writeln(
      '<text x="${pos.x + nodeWidth / _halfDivisor}" y="${pos.y + nodeHeight / _halfDivisor}" class="$textClass">$fileName</text>',
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

/// Multiplier accounting for corner radii on both sides of a column gap.
const int _bothSides = 2;

/// Reusable divisor for halving a dimension at file scope.
const double _halfDivisor = 2.0;

/// Downward arc applied to backward/cycle Bezier control points.
///
/// Ensures the path bounding box is never zero-height even when source and
/// target nodes share the same Y (which would break the horizontal SVG gradient).
const double _bezierBellyHeight = 16.0;

/// Tiny belly for direct same-row edges to avoid zero-height path bounds.
const double _edgeStraightBellyHeight = 1.0;

/// Corner radius for elbow turns in edge paths.
const double _fileEdgeCornerRadius = 6.0;

/// Builds a multi-hop elbow path through one or more intermediate column
/// passage gaps so the edge never visually crosses an intermediate node box.
///
/// The path begins at ([badgeTipX], [badgeTipY]) — the single shared tip of
/// the outgoing badge — then travels diagonally to the first gap, traverses
/// each intermediate column at [passageYs[i]], and ends at [endX]/[endY]
/// (left edge of the target column).  Callers must append the final
/// `L targetBadgeCenterX targetBadgeCenterY` to converge to the incoming badge.
///
/// [gapOffsets] provides a per-intermediate-gap X offset (indexed parallel to
/// [passageYs]) that staggers the vertical segment of each parallel edge so no
/// two edges share the same X column.  Defaults to zero offset when omitted.
///
/// Every elbow uses the same fixed radius: a horizontal pre-corner segment,
/// one quarter-turn into the vertical lane, the vertical run, and one
/// quarter-turn back out. This keeps all elbow radii visually uniform.
String _buildMultiHopElbowPath(
  double endX,
  double endY,
  double laneX, {
  required List<double> passageYs,
  required List<double> gapCenterXs,
  required List<double> colRightXs,
  required double badgeTipX,
  required double badgeTipY,
  required double badgeCenterY,
  List<double> gapOffsets = const [],
}) {
  const double r = _fileEdgeCornerRadius;
  final buf = StringBuffer();
  // Start at the outgoing badge tip — the single shared origin for all paths.
  buf.write('M $badgeTipX $badgeTipY ');
  double currentY = badgeTipY;

  for (var i = 0; i < passageYs.length; i++) {
    final xOffset = i < gapOffsets.length ? gapOffsets[i] : 0.0;
    final gcX = gapCenterXs[i] + xOffset;
    final crX = colRightXs[i];
    final py = passageYs[i];
    final dy = py - currentY;
    final dirY = dy >= 0 ? 1.0 : -1.0;

    if (dy.abs() < r * _halfDivisor) {
      buf.write('L $crX $currentY ');
    } else {
      buf.write('L ${gcX - r} $currentY ');
      buf.write('Q $gcX $currentY $gcX ${currentY + dirY * r} ');
      buf.write('V ${py - dirY * r} ');
      buf.write('Q $gcX $py ${gcX + r} $py ');
      buf.write('L $crX $py ');
      currentY = py;
    }
  }

  // Final elbow at laneX in the gap before the target column.
  final finalDy = endY - currentY;
  final finalDirY = finalDy >= 0 ? 1.0 : -1.0;
  if (finalDy.abs() < r * _halfDivisor) {
    buf.write('L $laneX $currentY V $endY L $endX $badgeCenterY');
  } else {
    buf.write('L ${laneX - r} $currentY ');
    buf.write('Q $laneX $currentY $laneX ${currentY + finalDirY * r} ');
    buf.write('V ${endY - finalDirY * r} ');
    buf.write('Q $laneX $endY ${laneX + r} $endY ');
    buf.write('L $endX $badgeCenterY');
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
