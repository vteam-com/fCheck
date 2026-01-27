/// Generates an SVG visualization of the dependency graph.
library;

import 'dart:math';
import 'package:fcheck/src/layers/layers_results.dart';

/// Generates an SVG visualization of the dependency graph.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns an SVG string representing the dependency graph.
String exportGraphSvg(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return _generateEmptySvg();
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
  const badgeRadius = 9;
  const badgeOffset = 12;
  const badgeTextOffset = 1;

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

  // Filter Definitions
  buffer.writeln('<defs>');
  buffer.writeln(
      '  <filter id="whiteShadow" x="-20%" y="-20%" width="140%" height="140%">');
  buffer.writeln('    <feGaussianBlur in="SourceAlpha" stdDeviation="3"/>');
  buffer.writeln('    <feOffset dx="0" dy="0" result="offsetblur"/>');
  buffer.writeln('    <feFlood flood-color="white" flood-opacity="1"/>');
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
      '    <feFlood flood-color="white" flood-opacity="0.5" result="WHITE"/>');
  buffer.writeln(
      '    <feComposite in="WHITE" in2="DILATED" operator="in" result="OUTLINE"/>');
  buffer.writeln('    <feMerge>');
  buffer.writeln('      <feMergeNode in="OUTLINE"/>');
  buffer.writeln('      <feMergeNode in="SourceGraphic"/>');
  buffer.writeln('    </feMerge>');
  buffer.writeln('  </filter>');

  // Gradient for edges (green to blue)
  buffer.writeln(
      '  <linearGradient id="edgeGradient" x1="0%" y1="0%" x2="100%" y2="0%">');
  buffer
      .writeln('    <stop offset="0%" stop-color="green" stop-opacity="0.3"/>');
  buffer.writeln(
      '    <stop offset="100%" stop-color="#007bff" stop-opacity="0.3"/>');
  buffer.writeln('  </linearGradient>');
  buffer.writeln('</defs>');

  // CSS Styles
  buffer.writeln('<style>');
  buffer.writeln(
      '  .layerBackground { fill: #f8f9fa; stroke: #dee2e6; stroke-width: 1; stroke-dasharray: 4,4; }');
  buffer.writeln(
      '  .layerTitle { fill: #6c757d; font-size: 14px; font-weight: bold; text-anchor: middle; }');
  buffer.writeln(
      '  .nodeRect { fill: #ffffff; stroke: #343a40; stroke-width: 2; rx: 6; ry: 6; cursor: pointer; filter: url(#whiteShadow); }');
  buffer.writeln('  .nodeRect:hover { stroke: #007bff; stroke-width: 3; }');
  buffer.writeln(
      '  .nodeText { fill: #212529; font-size: 14px; font-weight: 900; text-anchor: middle; dominant-baseline: middle; filter: url(#outlineWhite); }');
  buffer.writeln('  .edge { fill: none; stroke: url(#edgeGradient); }');
  buffer.writeln(
      '  .edge:hover { stroke: #007bff; stroke-width: 3; opacity: 1.0; }');
  buffer
      .writeln('  .cycleEdge { stroke: red; stroke-width: 5; opacity: 0.9; }');
  buffer.writeln(
      '  .badge { font-size: 10px; font-weight: bold; fill: white; text-anchor: middle; dominant-baseline: middle; cursor: help; }');
  buffer.writeln('  .badge:hover { opacity: 0.8; }');
  buffer.writeln('</style>');

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
    final layerNum = sortedLayers[colIndex];
    final x =
        margin + (colIndex * (nodeWidth + columnSpacing)) - (columnSpacing / 4);
    final width = nodeWidth + (columnSpacing / 2);
    // Draw column background
    buffer.writeln(
        '<rect x="$x" y="$margin" width="$width" height="${totalHeight - margin * 2}" rx="8" class="layerBackground"/>');
    // Draw layer title
    buffer.writeln(
        '<text x="${x + width / 2}" y="${margin + 25}" class="layerTitle">$layerNum</text>');
  }

  // 3. Draw Node Rectangles
  for (final entry in nodePositions.entries) {
    final pos = entry.value;
    buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="$nodeWidth" height="$nodeHeight" class="nodeRect"/>');
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

      // Anchor points: Bottom-right of source -> Top-left of target
      final startX = sourcePos.x + nodeWidth - badgeOffset;
      final startY = sourcePos.y + nodeHeight - badgeOffset;

      final endX = targetPos.x + badgeOffset;
      final endY = targetPos.y + badgeOffset;

      // Bezier curve control points for smooth flow
      final controlX1 = startX + (columnSpacing * 0.5);
      final controlX2 = endX - (columnSpacing * 0.5);

      final isCycle = cyclicEdges.contains('$source|$target');
      final extraClass = isCycle ? ' cycleEdge' : '';
      buffer.writeln(
          '<path d="M $startX $startY C $controlX1 $startY, $controlX2 $endY, $endX $endY" class="edge$extraClass"/>');
    }
  }

  // 5. Draw Node Content (Counters and Labels)

  // Pre-calculate incoming and outgoing node lists for tooltips
  final incomingNodes = <String, List<String>>{};
  final outgoingNodes = <String, List<String>>{};

  for (final entry in dependencyGraph.entries) {
    final source = entry.key;
    for (final target in entry.value) {
      if (effectiveLayers.containsKey(source) &&
          effectiveLayers.containsKey(target)) {
        outgoingNodes.putIfAbsent(source, () => []).add(target.split('/').last);
        incomingNodes.putIfAbsent(target, () => []).add(source.split('/').last);
      }
    }
  }

  for (final entry in nodePositions.entries) {
    final file = entry.key;
    final pos = entry.value;

    // Badges (Incoming/Outgoing) - Drawn BEFORE text
    final inCount = incomingCounts[file] ?? 0;
    final outCount = outgoingCounts[file] ?? 0;

    // Render incoming badge (top-left)
    _renderBadge(
      buffer,
      pos,
      nodeWidth,
      nodeHeight,
      inCount,
      incomingNodes[file] ?? [],
      badgeOffset,
      badgeOffset, // Y offset from top
      badgeRadius,
      badgeTextOffset,
      '#007bff', // Blue for incoming
    );

    // Render outgoing badge (bottom-right)
    _renderBadge(
      buffer,
      pos,
      nodeWidth,
      nodeHeight,
      outCount,
      outgoingNodes[file] ?? [],
      nodeWidth - badgeOffset,
      nodeHeight - badgeOffset, // Y offset from bottom
      badgeRadius,
      badgeTextOffset,
      '#28a745', // Green for outgoing
    );

    // Node Text (Filename) - Drawn LAST
    final fileName = file.split('/').last;
    // Truncate if too long
    final displayText =
        fileName.length > 25 ? '${fileName.substring(0, 22)}...' : fileName;

    buffer.writeln(
        '<text x="${pos.x + nodeWidth / 2}" y="${pos.y + nodeHeight / 2}" class="nodeText">$displayText</text>');
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

/// Helper method to render a badge on an SVG node
void _renderBadge(
  StringBuffer buffer,
  Point<double> pos,
  num nodeWidth,
  num nodeHeight,
  int count,
  List<String> nodeNames,
  num xOffset,
  num yOffset,
  num radius,
  num textOffset,
  String color,
) {
  if (count <= 0) return;

  // Sort node names alphabetically and generate tooltip
  final sortedNodeNames = List<String>.from(nodeNames)..sort();
  final tooltipLines = sortedNodeNames.join('\n');

  buffer.writeln('<g>');
  buffer.writeln(
      '<circle cx="${pos.x + xOffset}" cy="${pos.y + yOffset}" r="$radius" fill="$color"/>');
  buffer.writeln(
      '<text x="${pos.x + xOffset}" y="${pos.y + yOffset + textOffset}" class="badge">$count</text>');
  buffer.writeln('<title>$tooltipLines</title>');
  buffer.writeln('</g>');
}

/// Generates an empty SVG for when there are no dependencies.
String _generateEmptySvg() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="200" fill="#f8f9fa"/>
  <text x="200" y="100" text-anchor="middle" fill="#6c757d"
        font-family="Arial, sans-serif" font-size="16">No dependencies found</text>
</svg>''';
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
