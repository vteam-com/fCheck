import 'package:fcheck/src/analyzers/layers/layers_results.dart';

/// Shared helpers for preparing dependency graphs for text/diagram renderers.
///
/// These helpers are intentionally renderer-agnostic so generators can share
/// the same normalization of file labels, IDs, and edge counts.
class GraphFormattingData {
  /// Files grouped by their assigned layer.
  final Map<int, List<String>> layerGroups;

  /// Number of incoming dependencies per file.
  final Map<String, int> incomingCounts;

  /// Number of outgoing dependencies per file.
  final Map<String, int> outgoingCounts;

  /// Constructor
  GraphFormattingData({
    required this.layerGroups,
    required this.incomingCounts,
    required this.outgoingCounts,
  });
}

/// Prepares layer groupings and edge counters for diagram generators.
///
/// Counts are only tallied when both the source and target are present in the
/// [`layersResult.layers`] map, mirroring the analyzer's notion of what belongs
/// in the rendered architecture view.
GraphFormattingData prepareGraphFormatting(LayersAnalysisResult layersResult) {
  final dependencyGraph = layersResult.dependencyGraph;
  final layers = layersResult.layers;

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

  // Count edges only when both ends are in the known layers map
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

  return GraphFormattingData(
    layerGroups: layerGroups,
    incomingCounts: incomingCounts,
    outgoingCounts: outgoingCounts,
  );
}

/// Returns a label path relative to the lib directory when possible.
///
/// This keeps diagram labels short while still being unambiguous across the
/// project tree.
String relativeFileLabel(String filePath) {
  final parts = filePath.split('/');
  final libIndex = parts.indexOf('lib');
  return libIndex >= 0 ? parts.sublist(libIndex + 1).join('/') : filePath;
}

/// Mermaid-compatible node id from a file path.
///
/// The id must be URL-safe and unique within the graph; we strip extensions and
/// replace path separators to satisfy Mermaid constraints.
String mermaidNodeId(String filePath) {
  return relativeFileLabel(
    filePath,
  ).replaceAll('/', '_').replaceAll('.dart', '');
}

/// PlantUML component id from a file path.
///
/// Produces predictable, collision-resistant component names that match the
/// displayed label while staying within PlantUML's identifier rules.
String plantUmlComponentId(String filePath) {
  final fileName = relativeFileLabel(filePath);
  final baseName = fileName
      .replaceAll('.dart', '')
      .replaceAll('/', '_')
      .replaceAll('_', ' ');

  final camelCase = baseName
      .split(' ')
      .map(
        (part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
      )
      .join('');

  return 'comp${camelCase.toLowerCase()}';
}

/// Standard empty Mermaid output for no dependencies.
///
/// Keeping this here avoids slight textual drift between generators.
String emptyMermaidGraph() {
  return '''graph TD
  Empty["No dependencies found"]''';
}

/// Standard empty PlantUML output for no dependencies.
///
/// Keeping this here avoids slight textual drift between generators.
String emptyPlantUml() {
  return '''@startuml Architecture
!theme plain

package "No Dependencies" {
  component [No dependencies found] as Empty
}

@enduml''';
}
