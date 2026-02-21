/// Generates a Mermaid visualization of the dependency graph.
library;

import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/graphs/graph_format_utils.dart';

///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Uses shared helpers to normalize labels/IDs and to include per-node
/// incoming/outgoing counts in the rendered label. Up-layer edges are dashed
/// with a circle to highlight architectural violations.
String exportGraphMermaid(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return emptyMermaidGraph();
  }

  final formatting = prepareGraphFormatting(layersResult);
  final layerGroups = formatting.layerGroups;
  final incomingCounts = formatting.incomingCounts;
  final outgoingCounts = formatting.outgoingCounts;

  final buffer = StringBuffer();
  buffer.writeln('graph TD');

  // Define subgraphs for layers
  for (final entry in layerGroups.entries) {
    final layerNum = entry.key;
    final files = entry.value;

    buffer.writeln('    subgraph Layer_$layerNum["Layer $layerNum"]');

    for (final file in files) {
      // Normalize to path relative to lib directory
      final fileName = relativeFileLabel(file); // relative path as label

      // Add counter information to label
      final incomingCount = incomingCounts[file] ?? 0;
      final outgoingCount = outgoingCounts[file] ?? 0;
      final counterInfo = incomingCount > 0 || outgoingCount > 0
          ? '\\n↓$incomingCount ↑$outgoingCount'
          : '';
      final displayLabel = '$fileName$counterInfo';

      // Create a valid Mermaid node ID by replacing special characters
      final nodeId = mermaidNodeId(file);
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
        final sourceId = mermaidNodeId(sourceFile);
        final targetId = mermaidNodeId(targetFile);

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
