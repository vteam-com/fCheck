/// Generates a folder-based SVG visualization of the dependency graph.
library;

import 'dart:math';
import 'package:fcheck/src/layers/layers_results.dart';

/// Generates a folder-based SVG visualization of the dependency graph.
///
/// This visualization groups files by their containing folders and shows
/// folder-level dependencies with rollup incoming/outgoing counts.
///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns an SVG string representing the folder-based dependency graph.
String generateFolderDependencyGraphSvg(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return _generateEmptyFolderSvg();
  }

  // Group files by folder
  final folderGroups = <String, List<String>>{};
  for (final file in dependencyGraph.keys) {
    final folder = _extractFolderPath(file);
    folderGroups.putIfAbsent(folder, () => []).add(file);
  }

  // Calculate folder-level dependency counts
  final folderIncomingCounts = <String, int>{};
  final folderOutgoingCounts = <String, int>{};
  final folderIncomingDetails = <String, Map<String, List<String>>>{};
  final folderOutgoingDetails = <String, Map<String, List<String>>>{};

  // Initialize counts for all folders
  for (final folder in folderGroups.keys) {
    folderIncomingCounts[folder] = 0;
    folderOutgoingCounts[folder] = 0;
    folderIncomingDetails[folder] = {};
    folderOutgoingDetails[folder] = {};
  }

  // Calculate folder-level dependencies
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final sourceFolder = _extractFolderPath(sourceFile);

    for (final targetFile in entry.value) {
      if (!layers.containsKey(targetFile)) continue;

      final targetFolder = _extractFolderPath(targetFile);

      if (sourceFolder != targetFolder) {
        // Cross-folder dependency
        folderOutgoingCounts[sourceFolder] =
            (folderOutgoingCounts[sourceFolder] ?? 0) + 1;
        folderIncomingCounts[targetFolder] =
            (folderIncomingCounts[targetFolder] ?? 0) + 1;

        // Track detailed dependencies for tooltips
        folderOutgoingDetails[sourceFolder]!
            .putIfAbsent(targetFolder, () => [])
            .add(_getFileName(targetFile));
        folderIncomingDetails[targetFolder]!
            .putIfAbsent(sourceFolder, () => [])
            .add(_getFileName(sourceFile));
      }
    }
  }

  // Sort folders by dependency hierarchy (entry points first, leaf folders last)
  // We want left-to-right ordering: entry points -> dependent folders -> leaf folders
  final sortedFolders = folderGroups.keys.toList()
    ..sort((a, b) {
      final aIncoming = folderIncomingCounts[a] ?? 0;
      final bIncoming = folderIncomingCounts[b] ?? 0;
      final aOutgoing = folderOutgoingCounts[a] ?? 0;
      final bOutgoing = folderOutgoingCounts[b] ?? 0;

      // Primary sort: folders with 0 incoming dependencies come first (true entry points)
      final aIsEntry = aIncoming == 0;
      final bIsEntry = bIncoming == 0;
      if (aIsEntry != bIsEntry) {
        return aIsEntry ? -1 : 1; // Entry points first
      }

      // Secondary sort: among entry points, sort by outgoing dependencies descending
      // Among non-entry points, sort by outgoing dependencies descending
      final outgoingDiff = bOutgoing.compareTo(aOutgoing);
      if (outgoingDiff != 0) return outgoingDiff;

      // Tertiary sort: by incoming dependencies ascending (fewer dependencies first)
      return aIncoming.compareTo(bIncoming);
    });

  // --- Layout Constants ---
  const folderWidth = 300;
  const folderMinHeight = 100;
  const folderSpacing = 150;
  const margin = 50;
  const folderHeaderHeight = 40;
  const fileItemHeight = 30;
  const fileItemSpacing = 5;

  // Calculate file positions within each folder
  final folderFilePositions = <String, List<Point<double>>>{};
  final folderDimensions = <String, Rect>{};

  for (final folder in sortedFolders) {
    final files = folderGroups[folder]!;
    final fileCount = files.length;

    // Calculate folder height based on file count
    final calculatedHeight = folderHeaderHeight +
        (fileCount * fileItemHeight) +
        ((fileCount - 1) * fileItemSpacing) +
        40; // padding

    final folderHeight =
        calculatedHeight > folderMinHeight ? calculatedHeight : folderMinHeight;

    folderDimensions[folder] = Rect.fromLTWH(
        0.0, 0.0, folderWidth.toDouble(), folderHeight.toDouble());

    // Calculate file positions within folder
    final filePositions = <Point<double>>[];
    var y = folderHeaderHeight + 20; // Start below folder header

    for (var i = 0; i < files.length; i++) {
      filePositions.add(Point(20.0, y.toDouble())); // 20px padding from left
      y += fileItemHeight + fileItemSpacing;
    }

    folderFilePositions[folder] = filePositions;
  }

  // Calculate total width and height
  final totalWidth = margin +
      (sortedFolders.length * folderWidth) +
      ((sortedFolders.length - 1) * folderSpacing) +
      margin;

  // Find max folder height for total height calculation
  final maxFolderHeight = folderDimensions.values
      .map((rect) => rect.height)
      .fold(0.0, (a, b) => a > b ? a : b);

  final totalHeight = margin + maxFolderHeight + margin;

  final buffer = StringBuffer();

  // SVG Header
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<svg width="$totalWidth" height="$totalHeight" viewBox="0 0 $totalWidth $totalHeight" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">');

  // Filter Definitions
  buffer.writeln('<defs>');
  buffer.writeln(
      '  <filter id="folderShadow" x="-20%" y="-20%" width="140%" height="140%">');
  buffer.writeln('    <feGaussianBlur in="SourceAlpha" stdDeviation="5"/>');
  buffer.writeln('    <feOffset dx="2" dy="2" result="offsetblur"/>');
  buffer.writeln(
      '    <feFlood flood-color="rgba(0,0,0,0.1)" flood-opacity="0.8"/>');
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
      '    <feFlood flood-color="white" flood-opacity="0.7" result="WHITE"/>');
  buffer.writeln(
      '    <feComposite in="WHITE" in2="DILATED" operator="in" result="OUTLINE"/>');
  buffer.writeln('    <feMerge>');
  buffer.writeln('      <feMergeNode in="OUTLINE"/>');
  buffer.writeln('      <feMergeNode in="SourceGraphic"/>');
  buffer.writeln('    </feMerge>');
  buffer.writeln('  </filter>');

  // Gradient for folder edges (different from file edges)
  buffer.writeln(
      '  <linearGradient id="folderEdgeGradient" x1="0%" y1="0%" x2="100%" y2="100%">');
  buffer.writeln(
      '    <stop offset="0%" stop-color="#6c757d" stop-opacity="0.4"/>');
  buffer.writeln(
      '    <stop offset="100%" stop-color="#495057" stop-opacity="0.4"/>');
  buffer.writeln('  </linearGradient>');
  buffer.writeln('</defs>');

  // CSS Styles
  buffer.writeln('<style>');
  buffer.writeln(
      '  .folderBackground { fill: #ffffff; stroke: #dee2e6; stroke-width: 2; rx: 12; ry: 12; filter: url(#folderShadow); }');
  buffer.writeln(
      '  .folderBackground:hover { stroke: #007bff; stroke-width: 3; }');
  buffer.writeln(
      '  .folderTitle { fill: #495057; font-size: 16px; font-weight: bold; text-anchor: middle; }');
  buffer.writeln(
      '  .folderMetric { fill: #6c757d; font-size: 12px; font-weight: normal; text-anchor: middle; }');
  buffer.writeln(
      '  .fileItem { fill: #212529; font-size: 12px; font-weight: normal; cursor: pointer; }');
  buffer.writeln('  .fileItem:hover { fill: #007bff; font-weight: bold; }');
  buffer.writeln(
      '  .folderEdge { fill: none; stroke: url(#folderEdgeGradient); stroke-width: 3; }');
  buffer.writeln(
      '  .folderEdge:hover { stroke: #007bff; stroke-width: 4; opacity: 1.0; }');
  buffer.writeln(
      '  .folderBadge { font-size: 14px; font-weight: bold; fill: white; text-anchor: middle; dominant-baseline: middle; }');
  buffer.writeln('  .folderBadge:hover { opacity: 0.8; }');
  buffer.writeln('</style>');

  // Background
  buffer.writeln('<rect width="100%" height="100%" fill="#f8f9fa"/>');

  // Calculate folder positions
  final folderPositions = <String, Point<double>>{};
  for (var i = 0; i < sortedFolders.length; i++) {
    final folder = sortedFolders[i];
    final x = margin + (i * (folderWidth + folderSpacing));
    final y = margin;
    folderPositions[folder] = Point(x.toDouble(), y.toDouble());
  }

  // 1. Draw Folder Edges (between folders)
  for (final entry in folderOutgoingDetails.entries) {
    final sourceFolder = entry.key;
    final targets = entry.value;

    if (!folderPositions.containsKey(sourceFolder)) continue;
    final sourcePos = folderPositions[sourceFolder]!;
    final sourceFolderDim = folderDimensions[sourceFolder]!;

    // Source folder center-right position
    final sourceX = sourcePos.x + sourceFolderDim.width;
    final sourceY = sourcePos.y + (sourceFolderDim.height / 2);

    for (final targetEntry in targets.entries) {
      final targetFolder = targetEntry.key;

      if (!folderPositions.containsKey(targetFolder)) continue;
      final targetPos = folderPositions[targetFolder]!;
      final targetFolderDim = folderDimensions[targetFolder]!;

      // Target folder center-left position
      final targetX = targetPos.x;
      final targetY = targetPos.y + (targetFolderDim.height / 2);

      // Create a smooth bezier curve between folders
      final controlX1 = sourceX + (folderSpacing * 0.3);
      final controlX2 = targetX - (folderSpacing * 0.3);

      buffer.writeln(
          '<path d="M $sourceX $sourceY C $controlX1 $sourceY, $controlX2 $targetY, $targetX $targetY" class="folderEdge"/>');

      // Add tooltip with dependency details
      final sourceFiles = targetEntry.value.join(', ');
      buffer.writeln(
          '<title>$sourceFolder → $targetFolder: $sourceFiles</title>');
    }
  }

  // 2. Draw Folder Containers
  for (var i = 0; i < sortedFolders.length; i++) {
    final folder = sortedFolders[i];
    final pos = folderPositions[folder]!;
    final dim = folderDimensions[folder]!;

    // Draw folder background
    buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="12" ry="12" class="folderBackground"/>');

    // Folder title
    final folderName = _getFolderDisplayName(folder);
    buffer.writeln(
        '<text x="${pos.x + dim.width / 2}" y="${pos.y + 25}" class="folderTitle">$folderName</text>');

    // Folder metrics (incoming/outgoing)
    final inCount = folderIncomingCounts[folder] ?? 0;
    final outCount = folderOutgoingCounts[folder] ?? 0;

    buffer.writeln(
        '<text x="${pos.x + dim.width / 2}" y="${pos.y + 45}" class="folderMetric">↓$inCount ↑$outCount dependencies</text>');

    // Draw files within folder
    final files = folderGroups[folder]!;
    final filePositions = folderFilePositions[folder]!;

    for (var j = 0; j < files.length; j++) {
      final file = files[j];
      final filePos = filePositions[j];
      final fileX = pos.x + filePos.x;
      final fileY = pos.y + filePos.y;

      // File item
      final fileName = _getFileName(file);
      buffer.writeln(
          '<text x="$fileX" y="$fileY" class="fileItem">$fileName</text>');

      // File-level metrics (smaller badges)
      final fileInCount = _countFileDependencies(dependencyGraph, file, true);
      final fileOutCount = _countFileDependencies(dependencyGraph, file, false);

      if (fileInCount > 0) {
        buffer.writeln(
            '<circle cx="${fileX - 15}" cy="$fileY" r="8" fill="#007bff" opacity="0.7"/>');
        buffer.writeln(
            '<text x="${fileX - 15}" y="${fileY + 3}" class="folderBadge" font-size="10">$fileInCount</text>');
        buffer.writeln('<title>Incoming dependencies: $fileInCount</title>');
      }

      if (fileOutCount > 0) {
        buffer.writeln(
            '<circle cx="${fileX + 15}" cy="$fileY" r="8" fill="#28a745" opacity="0.7"/>');
        buffer.writeln(
            '<text x="${fileX + 15}" y="${fileY + 3}" class="folderBadge" font-size="10">$fileOutCount</text>');
        buffer.writeln('<title>Outgoing dependencies: $fileOutCount</title>');
      }
    }
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

/// Extracts the folder path from a file path
String _extractFolderPath(String filePath) {
  // Remove the filename to get the folder path
  final lastSlash = filePath.lastIndexOf('/');
  if (lastSlash <= 0) return 'root'; // Handle root files

  // Get the parent folder
  final folderPath = filePath.substring(0, lastSlash);

  // For lib/src/... paths, we want to show the immediate parent folder
  final parts = folderPath.split('/');
  if (parts.length >= 2) {
    return parts[parts.length - 1]; // Return just the immediate folder name
  }

  return folderPath;
}

/// Gets the display name for a folder (clean up path)
String _getFolderDisplayName(String folderPath) {
  if (folderPath == 'lib') return 'lib';
  if (folderPath == 'bin') return 'bin';

  final parts = folderPath.split('/');
  if (parts.isNotEmpty) {
    return parts.last; // Return the last part of the path
  }

  return folderPath;
}

/// Gets just the filename from a file path
String _getFileName(String filePath) {
  final lastSlash = filePath.lastIndexOf('/');
  if (lastSlash >= 0 && lastSlash < filePath.length - 1) {
    return filePath.substring(lastSlash + 1);
  }
  return filePath;
}

/// Counts dependencies for a specific file
int _countFileDependencies(
    Map<String, List<String>> dependencyGraph, String filePath, bool incoming) {
  if (incoming) {
    // Count how many files depend on this file
    int count = 0;
    for (final entry in dependencyGraph.entries) {
      if (entry.value.contains(filePath)) {
        count++;
      }
    }
    return count;
  } else {
    // Count how many files this file depends on
    return dependencyGraph[filePath]?.length ?? 0;
  }
}

/// Generates an empty SVG for when there are no dependencies.
String _generateEmptyFolderSvg() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="200" fill="#f8f9fa"/>
  <text x="200" y="100" text-anchor="middle" fill="#6c757d"
        font-family="Arial, sans-serif" font-size="16">No folder dependencies found</text>
</svg>''';
}

/// Simple rectangle class for folder dimensions.
class Rect {
  /// Left position.
  final double x;

  /// Top position.
  final double y;

  /// Width of the rectangle.
  final double width;

  /// Height of the rectangle.
  final double height;

  /// Creates a rectangle from left, top, width, height.
  Rect.fromLTWH(this.x, this.y, this.width, this.height);
}
