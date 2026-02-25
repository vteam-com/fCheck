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
