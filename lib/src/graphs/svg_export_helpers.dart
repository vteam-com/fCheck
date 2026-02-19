import 'dart:math';

import 'package:fcheck/src/graphs/svg_styles.dart';

/// Writes the standard SVG preamble and opening `<svg>` element.
void writeSvgDocumentStart(
  StringBuffer buffer, {
  required num width,
  required num height,
  num? viewBoxWidth,
  num? viewBoxHeight,
  String fontFamily = 'Arial, Helvetica, sans-serif',
  bool includeUnifiedDefs = true,
  bool includeUnifiedStyles = false,
  Iterable<String> leadingBlocks = const <String>[],
  String? backgroundFill,
}) {
  final effectiveViewBoxWidth = viewBoxWidth ?? width;
  final effectiveViewBoxHeight = viewBoxHeight ?? height;

  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
    '<svg width="$width" height="$height" viewBox="0 0 $effectiveViewBoxWidth $effectiveViewBoxHeight" xmlns="http://www.w3.org/2000/svg" font-family="$fontFamily">',
  );

  if (includeUnifiedDefs) {
    buffer.writeln(SvgDefinitions.generateUnifiedDefs());
  }
  if (includeUnifiedStyles) {
    buffer.writeln(SvgDefinitions.generateUnifiedStyles());
  }
  for (final block in leadingBlocks) {
    buffer.writeln(block);
  }
  if (backgroundFill != null) {
    buffer.writeln('<rect width="100%" height="100%" fill="$backgroundFill"/>');
  }
}

/// Writes the closing `</svg>` tag.
void writeSvgDocumentEnd(StringBuffer buffer) {
  buffer.writeln('</svg>');
}

/// Escapes reserved XML characters in text content and attribute values.
String escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Finds all strongly connected components in [graph] using Tarjan's algorithm.
List<List<String>> findStronglyConnectedComponents(
  Map<String, List<String>> graph,
) {
  final components = <List<String>>[];
  final indexByNode = <String, int>{};
  final lowLinkByNode = <String, int>{};
  final stack = <String>[];
  final onStack = <String>{};
  var currentIndex = 0;

  void strongConnect(String node) {
    indexByNode[node] = currentIndex;
    lowLinkByNode[node] = currentIndex;
    currentIndex++;
    stack.add(node);
    onStack.add(node);

    for (final neighbor in graph[node] ?? const <String>[]) {
      if (!indexByNode.containsKey(neighbor)) {
        strongConnect(neighbor);
        lowLinkByNode[node] = min(
          lowLinkByNode[node]!,
          lowLinkByNode[neighbor]!,
        );
      } else if (onStack.contains(neighbor)) {
        lowLinkByNode[node] = min(lowLinkByNode[node]!, indexByNode[neighbor]!);
      }
    }

    if (lowLinkByNode[node] == indexByNode[node]) {
      final component = <String>[];
      String currentNode;
      do {
        currentNode = stack.removeLast();
        onStack.remove(currentNode);
        component.add(currentNode);
      } while (currentNode != node);
      components.add(component);
    }
  }

  for (final node in graph.keys) {
    if (!indexByNode.containsKey(node)) {
      strongConnect(node);
    }
  }

  return components;
}

/// Detects all edges that belong to at least one cycle in [graph].
Set<String> findCycleEdges(
  Map<String, List<String>> graph, {
  String separator = '->',
}) {
  final cycleEdges = <String>{};
  final components = findStronglyConnectedComponents(graph);

  for (final component in components) {
    if (component.length > 1) {
      final componentNodes = component.toSet();
      for (final node in componentNodes) {
        for (final neighbor in graph[node] ?? const <String>[]) {
          if (componentNodes.contains(neighbor)) {
            cycleEdges.add('$node$separator$neighbor');
          }
        }
      }
      continue;
    }

    if (component.isNotEmpty) {
      final node = component.first;
      if (graph[node]?.contains(node) ?? false) {
        cycleEdges.add('$node$separator$node');
      }
    }
  }

  return cycleEdges;
}
