/// Generates a PlantUML visualization of the dependency graph.
library;

import 'package:fcheck/src/layers/layers_results.dart';

///
/// [layersResult] The result of layers analysis containing the dependency graph.
///
/// Returns a PlantUML string representing the dependency graph.
String generateDependencyGraphPlantUML(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

  if (dependencyGraph.isEmpty) {
    return _generateEmptyPlantUML();
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
  buffer.writeln('@startuml Architecture');
  buffer.writeln('!theme plain');
  buffer.writeln('');

  // Define components with counters
  for (final entry in layerGroups.entries) {
    final files = entry.value;

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

      // Create a valid PlantUML component ID by replacing special characters
      final baseName = fileName
          .replaceAll('.dart', '')
          .replaceAll('/', '_')
          .replaceAll('_', ' ');
      final camelCase = baseName
          .split(' ')
          .map((part) =>
              part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
          .join('');
      final componentId = 'comp${camelCase.toLowerCase()}';
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
        final sourceId = _generateComponentId(sourceFile);
        final targetId = _generateComponentId(targetFile);

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

/// Generates a component ID from a file path.
String _generateComponentId(String filePath) {
  // Normalize to path relative to lib directory
  final parts = filePath.split('/');
  final libIndex = parts.indexOf('lib');
  final relativeFile =
      libIndex >= 0 ? parts.sublist(libIndex + 1).join('/') : filePath;
  final fileName = relativeFile; // relative path as label
  // Create a valid PlantUML component ID by replacing special characters
  final baseName = fileName
      .replaceAll('.dart', '')
      .replaceAll('/', '_')
      .replaceAll('_', ' ');
  final camelCase = baseName
      .split(' ')
      .map((part) =>
          part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
      .join('');
  return 'comp${camelCase.toLowerCase()}';
}

/// Generates an empty PlantUML for when there are no dependencies.
String _generateEmptyPlantUML() {
  return '''@startuml Architecture
!theme plain

package "No Dependencies" {
  component [No dependencies found] as Empty
}

@enduml''';
}
