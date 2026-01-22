/// Generates an SVG visualization of the dependency graph.
library;

import 'dart:math';
import '../layers/layers_issue.dart';

/// Generates an SVG visualization of the dependency graph.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns an SVG string representing the dependency graph.
String generateDependencyGraphSvg(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return _generateEmptySvg();
  }

  // Group files by layer (ensure each file appears in only one layer)
  final layerGroups = <int, List<String>>{};
  for (final entry in layers.entries) {
    final layer = entry.value;
    final file = entry.key;
    layerGroups.putIfAbsent(layer, () => []).add(file);
  }

  // Remove duplicates by keeping only the first occurrence of each file
  final seenFiles = <String>{};
  final cleanedLayerGroups = <int, List<String>>{};
  for (final layer in layerGroups.keys.toList()..sort()) {
    final files = layerGroups[layer]!;
    final uniqueFiles = <String>[];
    for (final file in files) {
      if (!seenFiles.contains(file)) {
        uniqueFiles.add(file);
        seenFiles.add(file);
      }
    }
    if (uniqueFiles.isNotEmpty) {
      cleanedLayerGroups[layer] = uniqueFiles;
    }
  }

  // Sort layers by layer number (top to bottom: lowest layer first for cake layout)
  final sortedLayers = cleanedLayerGroups.keys.toList()
    ..sort((a, b) => a.compareTo(b));

  // Calculate edge counts for each file
  final incomingCounts = <String, int>{};
  final outgoingCounts = <String, int>{};

  // Initialize counters for all files
  for (final files in cleanedLayerGroups.values) {
    for (final file in files) {
      outgoingCounts[file] = 0;
      incomingCounts[file] = 0;
    }
  }

  // Count edges
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final dependencies = entry.value;

    for (final targetFile in dependencies) {
      if (layers.containsKey(sourceFile) && layers.containsKey(targetFile)) {
        outgoingCounts[sourceFile] = (outgoingCounts[sourceFile] ?? 0) + 1;
        incomingCounts[targetFile] = (incomingCounts[targetFile] ?? 0) + 1;
      }
    }
  }

  // Sort files within each layer: first by outgoing count (descending), then by incoming count (ascending), then by name (ascending)
  // This places components with more dependencies above those with fewer, then importers above imported, then alphabetically
  for (final layerNum in cleanedLayerGroups.keys) {
    cleanedLayerGroups[layerNum]!.sort((a, b) {
      final aOutgoing = outgoingCounts[a] ?? 0;
      final bOutgoing = outgoingCounts[b] ?? 0;

      // First compare by outgoing count (descending)
      if (aOutgoing != bOutgoing) {
        return bOutgoing.compareTo(aOutgoing);
      }

      final aIncoming = incomingCounts[a] ?? 0;
      final bIncoming = incomingCounts[b] ?? 0;

      // Then compare by incoming count (ascending)
      if (aIncoming != bIncoming) {
        return aIncoming.compareTo(bIncoming);
      }

      // Then compare by name (case-insensitive ascending)
      final aName = a.split('/').last.split('.').first.toLowerCase();
      final bName = b.split('/').last.split('.').first.toLowerCase();
      return aName.compareTo(bName);
    });
  }

  // Calculate dimensions for vertical cake layout
  const nodeWidth = 200;
  const nodeHeight = 50;
  const nodeSpacing = 70;
  const margin = 50;

  // Calculate height based on content: each layer gets space proportional to its node count
  final totalContentHeight = sortedLayers.fold(0, (sum, layerNum) {
    final files = cleanedLayerGroups[layerNum]!;
    final layerHeight =
        files.length * nodeHeight + (files.length - 1) * nodeSpacing + margin;
    return sum + layerHeight;
  });

  // Calculate width based on longest filename: each char is ~8px + padding + margins
  final longestFileName = cleanedLayerGroups.values
      .expand((files) => files)
      .fold(
          '',
          (longest, current) =>
              current.length > longest.length ? current : longest);

  final textWidth = longestFileName.length * 8; // Approximate character width
  final requiredWidth =
      textWidth + 50 + margin * 2; // text width + node padding + margins
  final width = requiredWidth > (nodeWidth + margin * 2)
      ? requiredWidth
      : (nodeWidth + margin * 2);

  final height = totalContentHeight;

  final buffer = StringBuffer();

  // SVG header with viewBox for scalability
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">');

  // CSS Styles
  buffer.writeln('<style>');
  buffer.writeln('  .layerRectangle {');
  buffer.writeln('    stroke: black;');
  buffer.writeln('    stroke-dasharray: 5,5;');
  buffer.writeln('    fill: url(#layers);');
  buffer.writeln('  }');
  buffer.writeln('  .layerText {');
  buffer.writeln('    fill: purple;');
  buffer.writeln('    font-size: 24px;');
  buffer.writeln('    font-weight: bold;');
  buffer.writeln('  }');
  buffer.writeln('  .nodeFile {');
  buffer.writeln('    fill: #ffffff;');
  buffer.writeln('    stroke: gray;');
  buffer.writeln('    opacity: 0.9;');
  buffer.writeln('  }');
  buffer.writeln('  .nodeName {');
  buffer.writeln('    fill: black;');
  buffer.writeln('    font-weight: bold;');
  buffer.writeln('    text-anchor: middle;');
  buffer.writeln('    dominant-baseline: central;');
  buffer.writeln('  }');
  buffer.writeln('  .line {');
  buffer.writeln('    fill: none;');
  buffer.writeln('    stroke: #377E22;');
  buffer.writeln('    stroke-width: 3;');
  buffer.writeln('    opacity: 0.5;');
  buffer.writeln('  }');
  buffer.writeln('  .line:hover {');
  buffer.writeln('    stroke-width: 6;');
  buffer.writeln('    opacity: 1;');
  buffer.writeln('  }');
  buffer.writeln('</style>');

  // Background
  buffer.writeln('<rect width="100%" height="100%" fill="white"/>');

  // Gradient definition
  buffer.writeln('<defs>');
  buffer
      .writeln('  <linearGradient id="layers" gradientTransform="rotate(90)">');
  buffer.writeln(
      '    <stop offset="0%" stop-color="#691872" stop-opacity="0.1"/>');
  buffer.writeln(
      '    <stop offset="100%" stop-color="#691872" stop-opacity="0.3"/>');
  buffer.writeln('  </linearGradient>');
  buffer.writeln('</defs>');

  // Position all nodes first (vertical cake layout - nodes stacked vertically within each layer)
  final nodePositions = <String, Point<double>>{};
  final drawnFiles = <String>{}; // Track files that have been positioned
  var currentY = 0; // Start at top

  for (var layerIndex = 0; layerIndex < sortedLayers.length; layerIndex++) {
    final layerNum = sortedLayers[layerIndex];
    final files = cleanedLayerGroups[layerNum]!;
    final startY = currentY + nodeHeight / 2; // Start position for first node

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      // Skip if already positioned (prevent duplicates)
      if (drawnFiles.contains(file)) continue;

      final x = margin.toDouble(); // left edge of node
      final y = startY + i * (nodeHeight + nodeSpacing); // vertically stacked
      nodePositions[file] = Point(x, y);
      drawnFiles.add(file);
    }

    // Move to next layer: add space for this layer's nodes only
    final layerNodeHeight =
        files.length * (nodeHeight + nodeSpacing) - nodeSpacing;
    currentY +=
        layerNodeHeight + margin; // Next layer starts after this one's content
  }

  // 1. Draw layer rectangles (background layers) - vertical cake layout
  var currentLayerY = 0; // Start at top
  for (var i = 0; i < sortedLayers.length; i++) {
    final layerNum = sortedLayers[i];
    final files = cleanedLayerGroups[layerNum]!;
    // Calculate layer height: just enough for the nodes
    final layerNodeHeight =
        files.length * (nodeHeight + nodeSpacing) - nodeSpacing;
    final layerHeight = layerNodeHeight + margin; // Add bottom margin

    buffer.writeln(
        '<rect x="0" y="$currentLayerY" width="$width" height="$layerHeight" rx="2" ry="2" class="layerRectangle"/>');
    buffer.writeln(
        '<text x="10" y="${currentLayerY + 30}" class="layerText" dominant-baseline="hanging" text-anchor="start">$layerNum</text>');

    // Move to next layer position (same as node positioning)
    currentLayerY += layerNodeHeight + margin;
  }

  // 2. Draw node rectangles - vertical cake layout
  var currentNodeY = 0; // Start at top
  final drawnNodes = <String>{}; // Track nodes that have been drawn
  for (var layerIndex = 0; layerIndex < sortedLayers.length; layerIndex++) {
    final layerNum = sortedLayers[layerIndex];
    final files = cleanedLayerGroups[layerNum]!;
    final startY =
        currentNodeY + nodeHeight / 2; // Start position for first node

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      // Skip if already drawn (prevent duplicates)
      if (drawnNodes.contains(file)) continue;

      final x = margin; // left aligned within layer
      final y = startY + i * (nodeHeight + nodeSpacing); // vertically stacked

      // Node rectangle
      buffer.writeln(
          '<rect x="$x" y="$y" width="$nodeWidth" height="$nodeHeight" rx="8" ry="8" class="nodeFile"/>');
      drawnNodes.add(file);
    }

    // Move to next layer (same as node positioning)
    final layerNodeHeight =
        files.length * (nodeHeight + nodeSpacing) - nodeSpacing;
    currentNodeY += layerNodeHeight + margin;
  }

  // 3. Draw edges - vertical cake layout
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final dependencies = entry.value;
    for (final targetFile in dependencies) {
      if (nodePositions.containsKey(targetFile) &&
          nodePositions.containsKey(sourceFile)) {
        // Use the stored node positions for edge drawing
        final startPos = nodePositions[sourceFile]!;
        final endPos = nodePositions[targetFile]!;

        // Draw connection lines centered on counter circles
        // Outgoing counter is at bottom-right of source node
        final startX = startPos.x + nodeWidth - 15; // Outgoing counter center
        final startY = startPos.y + nodeHeight - 15; // Outgoing counter center

        // Incoming counter is at top-left of target node
        final endX = endPos.x + 15; // Incoming counter center
        final endY = endPos.y + 15; // Incoming counter center

        // Draw the line without end marker
        buffer.writeln('<line x1="$startX" y1="$startY" x2="$endX" y2="$endY" '
            'stroke="#6c757d" stroke-width="4"/>');
      }
    }
  }

  // 4. Draw node labels - vertical cake layout
  var currentLabelY = 0; // Start at top
  final drawnLabels = <String>{}; // Track labels that have been drawn
  for (var layerIndex = 0; layerIndex < sortedLayers.length; layerIndex++) {
    final layerNum = sortedLayers[layerIndex];
    final files = cleanedLayerGroups[layerNum]!;
    final startY =
        currentLabelY + nodeHeight / 2; // Start position for first node

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      // Skip if already drawn (prevent duplicates)
      if (drawnLabels.contains(file)) continue;

      final x = margin; // left aligned within layer
      final y = startY + i * (nodeHeight + nodeSpacing); // vertically stacked

      // File name text (vertically centered in node)
      final parts = file.split('/');
      final libIndex = parts.indexOf('lib');
      final relativeFile =
          libIndex >= 0 ? parts.sublist(libIndex + 1).join('/') : file;
      final fileName = relativeFile; // relative path
      final textX = x + nodeWidth / 2;
      final textY = y + nodeHeight / 2; // Vertically centered in rectangle

      // Add white background rectangle for text readability
      final textWidth = fileName.length * 8; // Approximate character width
      final bgX = textX - textWidth / 2 - 4; // 4px padding
      final bgY = textY - 12; // 12px above text
      final bgWidth = textWidth + 8; // text width + padding
      final bgHeight = 16; // text height + padding

      buffer.writeln(
          '<rect x="$bgX" y="$bgY" width="$bgWidth" height="$bgHeight" fill="white" fill-opacity="0.8" rx="3" ry="3"/>');
      buffer.writeln(
          '<text x="$textX" y="$textY" class="nodeName">$fileName</text>');
      drawnLabels.add(file);
    }

    // Move to next layer (same as node positioning)
    final layerNodeHeight =
        files.length * (nodeHeight + nodeSpacing) - nodeSpacing;
    currentLabelY += layerNodeHeight + margin;
  }

  // 5. Draw edge counters (badges) - vertical cake layout
  var currentBadgeY = 0; // Start at top
  final drawnBadges = <String>{}; // Track badges that have been drawn
  for (var layerIndex = 0; layerIndex < sortedLayers.length; layerIndex++) {
    final layerNum = sortedLayers[layerIndex];
    final files = cleanedLayerGroups[layerNum]!;
    final startY =
        currentBadgeY + nodeHeight / 2; // Start position for first node

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      // Skip if already drawn (prevent duplicates)
      if (drawnBadges.contains(file)) continue;

      final x = margin; // left aligned within layer
      final y = startY + i * (nodeHeight + nodeSpacing); // vertically stacked

      // Counter badges (inside the nodes)
      final incomingCount = incomingCounts[file] ?? 0;
      final outgoingCount = outgoingCounts[file] ?? 0;

      if (incomingCount > 0) {
        // Top-left corner inside the node
        buffer.writeln(
            '<circle cx="${x + 15}" cy="${y + 15}" r="10" fill="blue"/>');
        buffer.writeln(
            '<text x="${x + 15}" y="${y + 15}" fill="white" font-size="10" text-anchor="middle" dominant-baseline="central">$incomingCount</text>');
      }

      if (outgoingCount > 0) {
        // Bottom-right corner inside the node
        buffer.writeln(
            '<circle cx="${x + nodeWidth - 15}" cy="${y + nodeHeight - 15}" r="10" fill="green"/>');
        buffer.writeln(
            '<text x="${x + nodeWidth - 15}" y="${y + nodeHeight - 15}" fill="white" font-size="10" text-anchor="middle" dominant-baseline="central">$outgoingCount</text>');
      }

      drawnBadges.add(file);
    }

    // Move to next layer (same as node positioning)
    final layerNodeHeight =
        files.length * (nodeHeight + nodeSpacing) - nodeSpacing;
    currentBadgeY += layerNodeHeight + margin;
  }

  buffer.writeln('</svg>');
  return buffer.toString();
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
