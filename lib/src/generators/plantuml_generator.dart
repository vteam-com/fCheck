/// Generates a PlantUML visualization of the dependency graph.
library;

import 'package:fcheck/src/generators/graph_format_utils.dart';
import 'package:fcheck/src/layers/layers_results.dart';

///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Uses shared helpers to normalize labels/IDs and inject per-node counters.
/// Up-layer dependencies are rendered with a dashed arrow to call out
/// architectural smells; same-layer deps use dotted lines.
String generateDependencyGraphPlantUML(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return emptyPlantUml();
  }

  final formatting = prepareGraphFormatting(layersResult);
  final layerGroups = formatting.layerGroups;
  final incomingCounts = formatting.incomingCounts;
  final outgoingCounts = formatting.outgoingCounts;

  final buffer = StringBuffer();
  buffer.writeln('@startuml Architecture');
  buffer.writeln('!theme plain');
  buffer.writeln('');

  // Define components with counters
  for (final entry in layerGroups.entries) {
    final files = entry.value;

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

      // Create a valid PlantUML component ID by replacing special characters
      final componentId = plantUmlComponentId(file);
      buffer.writeln('component [$displayLabel] as $componentId');
    }
  }
  buffer.writeln('');

  // Add dependencies
  for (final entry in dependencyGraph.entries) {
    final sourceFile = entry.key;
    final dependencies = entry.value;

    for (final targetFile in dependencies) {
      if (layers.containsKey(sourceFile) && layers.containsKey(targetFile)) {
        final sourceLayer = layers[sourceFile]!;
        final targetLayer = layers[targetFile]!;

        // Generate IDs from file paths
        final sourceId = plantUmlComponentId(sourceFile);
        final targetId = plantUmlComponentId(targetFile);

        // Determine relationship style based on direction
        var relationshipStyle = '-->';
        if (targetLayer < sourceLayer) {
          // Upward dependency (architectural smell) - use dashed line
          relationshipStyle = '..>';
        } else if (sourceLayer == targetLayer) {
          // Same layer dependency - use dotted line
          relationshipStyle = '..>';
        }

        buffer.writeln('"$sourceId" $relationshipStyle "$targetId"');
      }
    }
  }

  buffer.writeln('');
  buffer.writeln('@enduml');
  return buffer.toString();
}
