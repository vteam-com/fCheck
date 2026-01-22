/// Generates a Mermaid visualization of the dependency graph.
library;

import '../layers/layers_issue.dart';

///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns a Mermaid string representing the dependency graph.
String generateDependencyGraphMermaid(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return _generateEmptyMermaid();
  }

  // Group files by layer
  final layerGroups = <int, List<String>>{};
  for (final entry in layers.entries) {
    final layer = entry.value;
    final file = entry.key;
    layerGroups.putIfAbsent(layer, () => []).add(file);
  }

  // Calculate edge counts for each file
  final incomingCounts = <String, int>{};
  final outgoingCounts = <String, int>{};

  // Initialize counters for all files
  for (final files in layerGroups.values) {
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

  final buffer = StringBuffer();
  buffer.writeln('graph TD');

  // Define subgraphs for layers
  for (final entry in layerGroups.entries) {
    final layerNum = entry.key;
    final files = entry.value;

    buffer.writeln('    subgraph Layer_$layerNum["Layer $layerNum"]');

    for (final file in files) {
      // Normalize to path relative to lib directory
      final parts = file.split('/');
      final libIndex = parts.indexOf('lib');
      final relativeFile =
          libIndex >= 0 ? parts.sublist(libIndex + 1).join('/') : file;
      final fileName = relativeFile; // relative path as label

      // Add counter information to label
      final incomingCount = incomingCounts[file] ?? 0;
      final outgoingCount = outgoingCounts[file] ?? 0;
      final counterInfo = incomingCount > 0 || outgoingCount > 0
          ? '\\n↓$incomingCount ↑$outgoingCount'
          : '';
      final displayLabel = '$fileName$counterInfo';

      // Create a valid Mermaid node ID by replacing special characters
      final nodeId = _generateMermaidNodeId(file);
      buffer.writeln('        $nodeId["$displayLabel"]');
    }

    buffer.writeln('    end');
  }

  // Add edges
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final dependencies = entry.value;

    for (final targetFile in dependencies) {
      if (layers.containsKey(sourceFile) && layers.containsKey(targetFile)) {
        final sourceLayer = layers[sourceFile]!;
        final targetLayer = layers[targetFile]!;

        // Generate IDs from file paths
        final sourceId = _generateMermaidNodeId(sourceFile);
        final targetId = _generateMermaidNodeId(targetFile);

        // Determine edge style based on direction
        var edgeStyle = '-->';
        if (targetLayer < sourceLayer) {
          // Upward dependency (architectural smell) - use dashed line with circle
          edgeStyle = '-.-o';
        } else if (sourceLayer == targetLayer) {
          // Same layer dependency - use dashed line
          edgeStyle = '-.->';
        }

        buffer.writeln('    $sourceId $edgeStyle $targetId');
      }
    }
  }

  return buffer.toString();
}

/// Generates a Mermaid node ID from a file path.
String _generateMermaidNodeId(String filePath) {
  // Normalize to path relative to lib directory
  final parts = filePath.split('/');
  final libIndex = parts.indexOf('lib');
  final relativeFile =
      libIndex >= 0 ? parts.sublist(libIndex + 1).join('/') : filePath;
  final fileName = relativeFile; // relative path as label
  // Create a valid Mermaid node ID by replacing special characters
  return fileName.replaceAll('/', '_').replaceAll('.dart', '');
}

/// Generates an empty Mermaid for when there are no dependencies.
String _generateEmptyMermaid() {
  return '''graph TD
    Empty["No dependencies found"]''';
}
