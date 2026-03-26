import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/svg/export_files/source_gap_lane_ordering.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';

/// Builds the files-level dependency graph SVG.
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
    final sortedForGap = orderSourceGapEdgesByCrossingCost(
      gapEntry.value,
      nodePositions: nodePositions,
      nodeHeight: nodeHeight,
      colIndexByFile: colIndexByFile,
    );

    var laneIdx = 0;
    for (final edge in sortedForGap) {
      sourceGapLaneIndices['${edge.$1}|${edge.$2}'] = laneIdx;
      laneIdx++;
    }
  }

  // Track the total number of elbow lanes each source uses in its gap so
  // that the same-row direct Bezier can be routed past the vertical bundle.
  final sourceLaneCount = <String, int>{};
  for (final entry in sourceGapLaneIndices.entries) {
    final src = entry.key.split('|').first;
    final lane = entry.value;
    final prev = sourceLaneCount[src] ?? 0;
    if (lane + 1 > prev) sourceLaneCount[src] = lane + 1;
  }

  // Pre-compute skip-edge passage Y and lane indices.
  final skipEdgesBySource = <String, List<String>>{};
  final skipPassageLaneIndex = <String, int>{};
  final skipPassageLaneCount = <String, int>{};
  for (final fwdEntry in dependencyGraph.entries) {
    final src = fwdEntry.key;
    if (!nodePositions.containsKey(src)) continue;
    final srcCol = colIndexByFile[src] ?? 0;
    for (final tgt in fwdEntry.value) {
      if (!nodePositions.containsKey(tgt)) continue;
      final tgtCol = colIndexByFile[tgt] ?? 0;
      if (tgtCol - srcCol > 1) {
        skipEdgesBySource.putIfAbsent(src, () => []).add(tgt);
      }
    }
  }
  // Assign contiguous passage lane indices per source for skip edges only.
  for (final srcEntry in skipEdgesBySource.entries) {
    final src = srcEntry.key;
    final sorted = List<String>.from(srcEntry.value)
      ..sort((a, b) {
        final aColDiff = (colIndexByFile[a] ?? 0) - (colIndexByFile[src] ?? 0);
        final bColDiff = (colIndexByFile[b] ?? 0) - (colIndexByFile[src] ?? 0);
        final colCompare = aColDiff.compareTo(bColDiff);
        if (colCompare != 0) return colCompare;

        final aY = (nodePositions[a]?.y ?? 0) + nodeHeight / _halfDivisor;
        final bY = (nodePositions[b]?.y ?? 0) + nodeHeight / _halfDivisor;
        final yCompare = aY.compareTo(bY);
        return yCompare != 0 ? yCompare : a.compareTo(b);
      });
    for (var i = 0; i < sorted.length; i++) {
      skipPassageLaneIndex['$src|${sorted[i]}'] = i;
    }
    skipPassageLaneCount[src] = sorted.length;
  }
  // Lane indices for top-bypass special-case edges.
  final topBypassLaneIndex = <String, int>{};
  final topBypassTargetsBySource = <String, List<String>>{};
  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    if (!nodePositions.containsKey(source)) continue;
    final sourceColIdx = colIndexByFile[source] ?? 0;
    final sourceColumnFiles = colFilesByIndex[sourceColIdx] ?? const [];
    final sourceIsFirstInColumn =
        sourceColumnFiles.isNotEmpty && sourceColumnFiles.first == source;
    if (!sourceIsFirstInColumn) continue;

    for (final target in entry.value) {
      if (!nodePositions.containsKey(target)) continue;
      final targetColIdx = colIndexByFile[target] ?? 0;
      final colDiff = targetColIdx - sourceColIdx;
      if (colDiff < _minTopBypassColDiff) continue;

      final targetColumnFiles = colFilesByIndex[targetColIdx] ?? const [];
      final targetIsFirstInColumn =
          targetColumnFiles.isNotEmpty && targetColumnFiles.first == target;
      if (!targetIsFirstInColumn) continue;

      topBypassTargetsBySource.putIfAbsent(source, () => []).add(target);
    }
  }
  // Global lane assignment: edges with the same column span share one lane
  // (same bypass Y) regardless of source.  Shorter spans get lane 0 (highest
  // Y, closest to nodes = visually "inside") and longer spans get higher lane
  // indices (lower Y, further from nodes = visually "outside").
  final allBypassColDiffs = <String, int>{};
  for (final srcEntry in topBypassTargetsBySource.entries) {
    final sourceColIdx = colIndexByFile[srcEntry.key] ?? 0;
    for (final target in srcEntry.value) {
      final diff = (colIndexByFile[target] ?? 0) - sourceColIdx;
      allBypassColDiffs['${srcEntry.key}|$target'] = diff;
    }
  }
  final uniqueColDiffs = allBypassColDiffs.values.toSet().toList()..sort();
  for (final entry in allBypassColDiffs.entries) {
    topBypassLaneIndex[entry.key] = uniqueColDiffs.indexOf(entry.value);
  }

  // Pre-compute topBypassY for every bypass edge using global lane count.
  final topBypassY = <String, double>{};
  {
    final firstRowTopY = (margin + layerHeaderHeight).toDouble();
    final topBypassBaseOffset = _fileEdgeCornerRadius + _edgeLaneOffset;
    final minTopBypassY = margin / _halfDivisor;
    final globalLaneCount = uniqueColDiffs.length;
    final availableTopBand = firstRowTopY - minTopBypassY - topBypassBaseOffset;
    final safeTopBand = availableTopBand > 0 ? availableTopBand : 0.0;
    final topBypassLaneGap = globalLaneCount <= 1
        ? 0.0
        : min(_topBypassPreferredLaneGap, safeTopBand / (globalLaneCount - 1));
    for (final entry in allBypassColDiffs.entries) {
      final laneIdx = topBypassLaneIndex[entry.key] ?? 0;
      final raw =
          firstRowTopY - topBypassBaseOffset - laneIdx * topBypassLaneGap;
      topBypassY[entry.key] = raw < minTopBypassY ? minTopBypassY : raw;
    }
  }

  // Reverse source-side lane X for bypass edges: the longest bypass
  // (outermost/lowest Y) must get the innermost (leftmost) source-side X
  // so its tall vertical doesn't cross shorter bypasses' horizontals.
  final bypassSourceSideLaneIdx = <String, int>{};
  for (final srcEntry in topBypassTargetsBySource.entries) {
    final source = srcEntry.key;
    final sourceColIdx = colIndexByFile[source] ?? 0;
    final targets = List<String>.from(srcEntry.value);
    if (targets.length < _minBypassEdgesForReorder) continue;

    // Sort by ascending colDiff (matches gap-ordering tiebreak for same-Y).
    targets.sort((a, b) {
      final aDiff = (colIndexByFile[a] ?? 0) - sourceColIdx;
      final bDiff = (colIndexByFile[b] ?? 0) - sourceColIdx;
      return aDiff.compareTo(bDiff);
    });

    // Collect their current gap lane indices and sort ascending.
    final currentLanes = <int>[
      for (final t in targets) sourceGapLaneIndices['$source|$t'] ?? 0,
    ]..sort();

    // Reverse: smallest colDiff → highest lane index (outermost X),
    // largest colDiff → lowest lane index (innermost X).
    for (var i = 0; i < targets.length; i++) {
      bypassSourceSideLaneIdx['$source|${targets[i]}'] =
          currentLanes[targets.length - 1 - i];
    }
  }

  // 4. Build and sort edges, then render.
  final edgeRenderList =
      <
        ({
          String source,
          String target,
          String pathData,
          String cssClass,
          String? pathStyle,
          double span,
          int colDiff,
        })
      >[];
  final flatEdgeGradientDefs = <String>[];
  var flatEdgeGradientCounter = 0;

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
      var isFlatStraightAdjacentEdge = false;
      String? edgePathStyle;

      final String pathData;
      final int colDiff;
      if (sourceColIdx < targetColIdx) {
        colDiff = targetColIdx - sourceColIdx;

        // Left edge of target column box for lane bounds.
        final targetLeftX = colLeftXPositions[targetColIdx];

        // Triangle tip positions from badge geometry.
        final sourceBadgeTipX =
            startX +
            BadgeModel.tipOffsetFromCenter(outgoingCounts[source] ?? 0);
        final targetBadgeTipX =
            endX - BadgeModel.baseOffsetFromCenter(incomingCounts[target] ?? 0);

        if (colDiff == 1 && span < 1.0) {
          // Adjacent same-level edge:
          // - exactly one outgoing edge from source => straight line
          // - more than one outgoing edge from source => single arch
          final sourceOutgoingCount = outgoingCounts[source] ?? 0;
          if (sourceOutgoingCount <= 1) {
            isFlatStraightAdjacentEdge = true;
            flatEdgeGradientCounter++;
            final flatGradientId = 'flatEdgeGradient$flatEdgeGradientCounter';
            flatEdgeGradientDefs.add(
              '<linearGradient id="$flatGradientId" gradientUnits="userSpaceOnUse" x1="$sourceBadgeTipX" y1="$startY" x2="$endX" y2="$endY">'
              '<stop offset="0%" stop-color="#28a745"/>'
              '<stop offset="100%" stop-color="#007bff"/>'
              '</linearGradient>',
            );
            edgePathStyle = 'stroke:url(#$flatGradientId);';
            pathData = 'M $sourceBadgeTipX $startY L $endX $endY';
          } else {
            final midX = (sourceBadgeTipX + endX) / _halfDivisor;
            pathData =
                'M $sourceBadgeTipX $startY '
                'Q $midX ${startY - _edgeStraightBellyHeight} $endX $endY';
          }
        } else {
          // Elbow routing through the gap just before the target column.
          final gapKey = targetColIdx - 1;
          final laneIdx = sourceGapLaneIndices['$source|$target'] ?? 0;
          final gapLeftX = colLeftXPositions[gapKey] + nodeWidth;
          // Keep lane start past outgoing badge tip.
          final minLaneX =
              (sourceBadgeTipX > gapLeftX ? sourceBadgeTipX : gapLeftX) +
              _fileEdgeCornerRadius +
              _edgeLaneOffset;
          final maxLaneX = targetLeftX - _fileEdgeCornerRadius;
          final laneX = (minLaneX + laneIdx * _edgeLaneOffset).clamp(
            minLaneX,
            maxLaneX,
          );

          // Source-side X for first vertical turn from this source.
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
            // Skip edge: route through intermediate passage gaps.
            final edgeKey = '$source|$target';
            final laneIdx = sourceGapLaneIndices[edgeKey] ?? 0;
            // Use per-source skip-edge lane index for passage Y stagger.
            final skipLaneIdx = skipPassageLaneIndex[edgeKey] ?? 0;
            final skipTotal = skipPassageLaneCount[source] ?? 1;
            final rawPassageYOffset =
                (skipLaneIdx - (skipTotal - 1) / _halfDivisor) *
                _edgeLaneOffset;
            final maxPassageYOffset = max(
              0.0,
              nodeVerticalSpacing / _halfDivisor - _fileEdgeCornerRadius,
            );
            final passageYOffset = rawPassageYOffset.clamp(
              -maxPassageYOffset,
              maxPassageYOffset,
            );
            final passageYs = <double>[];
            final gapCenterXsList = <double>[];
            final colRightXsList = <double>[];
            for (var c = sourceColIdx + 1; c < targetColIdx; c++) {
              final colLeftX = colLeftXPositions[c];
              final gapBeforeC = gapSpacings[c - 1];
              gapCenterXsList.add(colLeftX - gapBeforeC / _halfDivisor);
              colRightXsList.add(colLeftX + nodeWidth);
              final basePassageY = _findBestPassageY(
                colFilesByIndex[c] ?? const [],
                nodePositions,
                nodeHeight,
                nodeVerticalSpacing,
                endY,
              );
              passageYs.add(basePassageY + passageYOffset);
            }
            final laneOffset = laneIdx * _edgeLaneOffset;
            final gapOffsets = <double>[
              if (gapCenterXsList.isNotEmpty)
                sourceSideLaneX - gapCenterXsList[0],
              for (var i = 1; i < gapCenterXsList.length; i++) laneOffset,
            ];
            final sourceColumnFiles = colFilesByIndex[sourceColIdx] ?? const [];
            final targetColumnFiles = colFilesByIndex[targetColIdx] ?? const [];
            final sourceIsFirstInColumn =
                sourceColumnFiles.isNotEmpty &&
                sourceColumnFiles.first == source;
            final targetIsFirstInColumn =
                targetColumnFiles.isNotEmpty &&
                targetColumnFiles.first == target;

            if (sourceIsFirstInColumn &&
                targetIsFirstInColumn &&
                colDiff >= _minTopBypassColDiff) {
              final r = _fileEdgeCornerRadius;
              final bypassY =
                  topBypassY[edgeKey] ??
                  (margin + layerHeaderHeight).toDouble() -
                      _fileEdgeCornerRadius -
                      _edgeLaneOffset;
              final bypassSrcIdx = bypassSourceSideLaneIdx[edgeKey] ?? laneIdx;
              final bypassSrcLaneX =
                  srcMinLaneX + bypassSrcIdx * _edgeLaneOffset;
              pathData =
                  'M $sourceBadgeTipX $startY '
                  'L ${bypassSrcLaneX - r} $startY '
                  'Q $bypassSrcLaneX $startY $bypassSrcLaneX ${startY - r} '
                  'V ${bypassY + r} '
                  'Q $bypassSrcLaneX $bypassY ${bypassSrcLaneX + r} $bypassY '
                  'L ${laneX - r} $bypassY '
                  'Q $laneX $bypassY $laneX ${bypassY + r} '
                  'V ${endY - r} '
                  'Q $laneX $endY ${laneX + r} $endY '
                  'L $targetBadgeTipX $endY '
                  'L $endX $endY';
            } else {
              pathData =
                  '${_buildMultiHopElbowPath(targetLeftX, endY, laneX, passageYs: passageYs, gapCenterXs: gapCenterXsList, colRightXs: colRightXsList, badgeTipX: sourceBadgeTipX, badgeTipY: startY, badgeCenterY: endY, gapOffsets: gapOffsets)} L $endX $endY';
            }
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
        cssClass:
            'edge${isFlatStraightAdjacentEdge ? ' edgeFlat' : ''}$extraClass',
        pathStyle: edgePathStyle,
        span: span,
        colDiff: colDiff,
      ));
    }
  }

  // Sort by colDiff ascending; within same colDiff, shorter span first.
  // This paints taller/longer vertical runs later so they remain visually on
  // top of horizontal peel-offs, reducing apparent crossings.
  edgeRenderList.sort((a, b) {
    final colCmp = a.colDiff.compareTo(b.colDiff);
    if (colCmp != 0) return colCmp;
    return a.span.compareTo(b.span);
  });

  if (flatEdgeGradientDefs.isNotEmpty) {
    buffer.writeln('<defs>');
    for (final gradient in flatEdgeGradientDefs) {
      buffer.writeln(gradient);
    }
    buffer.writeln('</defs>');
  }

  for (final edge in edgeRenderList) {
    renderEdgeWithTooltip(
      buffer,
      pathData: edge.pathData,
      source: edge.source,
      target: edge.target,
      cssClass: edge.cssClass,
      pathStyle: edge.pathStyle,
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

/// Aggregates severity labels by resolved file path.
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

String _maxSeverity(String? current, String? next) {
  if (next == null) {
    return current ?? '';
  }
  if (current == 'error' || next == 'error') {
    return 'error';
  }
  return next;
}

String? _severityClassForFileNode(String? severity) {
  if (severity == 'error') {
    return 'fileNodeError';
  }
  if (severity == 'warning') {
    return 'fileNodeWarning';
  }
  return null;
}

/// Aggregates warning counters by resolved file path.
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

const double _edgeLaneOffset = 2.0;

const int _bothSides = 2;

const double _halfDivisor = 2.0;

const double _bezierBellyHeight = 16.0;

const double _edgeStraightBellyHeight = 6.0;

const double _fileEdgeCornerRadius = 6.0;

const int _minTopBypassColDiff = 2;

const double _topBypassPreferredLaneGap = 4.0;

/// Minimum number of bypass edges from one source before lane reordering
/// applies.
const int _minBypassEdgesForReorder = 2;

/// Builds a multi-hop elbow path through intermediate passage gaps.
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
      buf.write('L $crX $py ');
      currentY = py;
    } else {
      buf.write('L ${gcX - r} $currentY ');
      buf.write('Q $gcX $currentY $gcX ${currentY + dirY * r} ');
      buf.write('V ${py - dirY * r} ');
      buf.write('Q $gcX $py ${gcX + r} $py ');
      buf.write('L $crX $py ');
      currentY = py;
    }
  }

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

/// Finds the closest valid inter-node passage Y for a target Y.
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
