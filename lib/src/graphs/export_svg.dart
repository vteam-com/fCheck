/// Generates an SVG visualization of the dependency graph.
library;

import 'dart:math';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/graphs/svg_common.dart';
import 'package:fcheck/src/graphs/svg_styles.dart';
import 'package:fcheck/src/graphs/badge_model.dart';

/// Generates an SVG visualization of the dependency graph.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns an SVG string representing the dependency graph.
String exportGraphSvg(LayersAnalysisResult layersResult) {
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

  // Precompute cyclic edges
  final cyclicEdges = _findCyclicEdges(dependencyGraph);

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

      final outDiff =
          (outgoingCounts[b] ?? 0).compareTo(outgoingCounts[a] ?? 0);
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

  // Badge constants
  const badgeOffset = 12;

  // Calculate total width based on number of columns
  final totalWidth = margin +
      (sortedLayers.length * nodeWidth) +
      ((sortedLayers.length - 1) * columnSpacing) +
      margin;

  // Calculate max nodes in any layer to determine height
  int maxNodes = 0;
  for (final files in cleanedLayerGroups.values) {
    if (files.length > maxNodes) maxNodes = files.length;
  }

  final totalHeight = margin +
      layerHeaderHeight +
      (maxNodes * nodeHeight) +
      ((maxNodes - 1) * nodeVerticalSpacing) +
      margin;

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
  buffer.writeln('<rect width="100%" height="100%" fill="white"/>');

  // 1. Calculate positions
  final nodePositions = <String, Point<double>>{};

  for (var colIndex = 0; colIndex < sortedLayers.length; colIndex++) {
    final layerNum = sortedLayers[colIndex];
    final files = cleanedLayerGroups[layerNum]!;

    final x = margin + (colIndex * (nodeWidth + columnSpacing));
    var y = margin + layerHeaderHeight;

    for (final file in files) {
      nodePositions[file] = Point(x.toDouble(), y.toDouble());
      y += nodeHeight + nodeVerticalSpacing;
    }
  }

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
    final x = margin +
        (colIndex * (nodeWidth + columnSpacing)) -
        (columnSpacing / columnMarginFactor);
    final width = nodeWidth + (columnSpacing / halfDivisor);
    // Draw column background
    buffer.writeln(
        '<rect x="$x" y="$margin" width="$width" height="${totalHeight - margin * halfDivisor}" rx="$layerCornerRadius" class="layerBackground"/>');
    // Draw layer title
    buffer.writeln(
        '<text x="${x + width / halfDivisor}" y="${margin + titleVerticalOffset}" class="layerTitle">$layerNum</text>');
  }

  // 3. Draw Node Rectangles
  for (final entry in nodePositions.entries) {
    final pos = entry.value;
    buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="$nodeWidth" height="$nodeHeight" class="fileNode"/>');
  }

  // 4. Draw Edges
  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    final targets = entry.value;

    if (!nodePositions.containsKey(source)) continue;
    final sourcePos = nodePositions[source]!;

    for (final target in targets) {
      if (!nodePositions.containsKey(target)) continue;
      final targetPos = nodePositions[target]!;

      // Anchor points: Source outgoing badge -> Target incoming badge
      /// Divisor for halving dimensions.
      const double halfDivisor = 2.0;

      /// Factor for Bezier curve control points.
      const double controlPointFactor = 0.5;

      final startX = sourcePos.x + nodeWidth; // Outgoing badge position
      final startY = sourcePos.y + nodeHeight - badgeOffset;

      final endX =
          targetPos.x + (badgeOffset / halfDivisor); // Incoming badge position
      final endY = targetPos.y + badgeOffset;

      // Bezier curve control points for smooth flow
      final controlX1 = startX + (columnSpacing * controlPointFactor);
      final controlX2 = endX - (columnSpacing * controlPointFactor);

      final isCycle = cyclicEdges.contains('$source|$target');
      final extraClass = isCycle ? ' cycleEdge' : '';
      final pathData =
          'M $startX $startY C $controlX1 $startY, $controlX2 $endY, $endX $endY';

      renderEdgeWithTooltip(
        buffer,
        pathData: pathData,
        source: source,
        target: target,
        cssClass: 'edge$extraClass',
      );
    }
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

    // Render incoming badge (top-left, pointing west)
    final incomingBadge = BadgeModel.incoming(
      cx: pos.x + (badgeOffset / halfDivisor0),
      cy: pos.y + badgeOffset,
      count: inCount,
      peers: incomingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, incomingBadge);

    // Render outgoing badge (bottom-right, pointing east)
    final outgoingBadge = BadgeModel.outgoing(
      cx: pos.x + nodeWidth, // - badgeOffset,
      cy: pos.y + nodeHeight - badgeOffset,
      count: outCount,
      peers: outgoingNodes[file] ?? const [],
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, outgoingBadge);

    // Node Text (Filename) - Drawn LAST
    final fileName = file.split('/').last;

    /// Maximum length of the filename before truncation.
    const int maxLabelLength = 25;

    /// Length to truncate the filename to.
    const int truncateLength = 22;

    // Truncate if too long
    final displayText = fileName.length > maxLabelLength
        ? '${fileName.substring(0, truncateLength)}...'
        : fileName;

    buffer.writeln(
        '<text x="${pos.x + nodeWidth / halfDivisor0}" y="${pos.y + nodeHeight / halfDivisor0}" class="nodeText">$displayText</text>');
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

/// Detect cyclic edges using Tarjan SCC; edges inside any SCC of size > 1 are marked cyclic.
Set<String> _findCyclicEdges(Map<String, List<String>> graph) {
  final index = <String, int>{};
  final lowlink = <String, int>{};
  final onStack = <String, bool>{};
  final stack = <String>[];
  var idx = 0;
  final cycles = <String>{};

  void strongConnect(String v) {
    index[v] = idx;
    lowlink[v] = idx;
    idx++;
    stack.add(v);
    onStack[v] = true;

    for (final w in graph[v] ?? const []) {
      if (!index.containsKey(w)) {
        strongConnect(w);
        lowlink[v] = min(lowlink[v]!, lowlink[w]!);
      } else if (onStack[w] == true) {
        lowlink[v] = min(lowlink[v]!, index[w]!);
      }
    }

    if (lowlink[v] == index[v]) {
      final component = <String>[];
      String w;
      do {
        w = stack.removeLast();
        onStack[w] = false;
        component.add(w);
      } while (w != v && stack.isNotEmpty);

      if (component.length > 1 ||
          (component.length == 1 &&
              (graph[component.first] ?? const []).contains(component.first))) {
        for (final node in component) {
          for (final tgt in graph[node] ?? const []) {
            if (component.contains(tgt)) {
              cycles.add('$node|$tgt');
            }
          }
        }
      }
    }
  }

  for (final v in graph.keys) {
    if (!index.containsKey(v)) strongConnect(v);
  }

  return cycles;
}
