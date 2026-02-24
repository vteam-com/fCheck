import 'dart:math' as math;
import 'dart:math';

import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_styles.dart';

/// Default fitted label font size used by SVG text helpers.
const double _defaultFittedTextBaseFontSize = 14.0;

/// Minimum fitted label font size used by SVG text helpers.
const double _defaultFittedTextMinFontSize = 6.0;

/// Estimated width unit for whitespace characters.
const double _svgTextUnitForWhitespace = 0.35;

/// Estimated width unit for visually narrow glyphs.
const double _svgTextUnitForNarrowGlyph = 0.35;

/// Estimated width unit for visually wide glyphs.
const double _svgTextUnitForWideGlyph = 0.95;

/// ASCII code point range start for digits (`0`).
const int _asciiDigitStartRune = 48;

/// ASCII code point range end for digits (`9`).
const int _asciiDigitEndRune = 57;

/// Estimated width unit for digits.
const double _svgTextUnitForDigit = 0.60;

/// ASCII code point range start for uppercase letters (`A`).
const int _asciiUppercaseStartRune = 65;

/// ASCII code point range end for uppercase letters (`Z`).
const int _asciiUppercaseEndRune = 90;

/// Estimated width unit for uppercase letters.
const double _svgTextUnitForUppercase = 0.67;

/// ASCII code point range start for lowercase letters (`a`).
const int _asciiLowercaseStartRune = 97;

/// ASCII code point range end for lowercase letters (`z`).
const int _asciiLowercaseEndRune = 122;

/// Estimated width unit for lowercase letters.
const double _svgTextUnitForLowercase = 0.56;

/// Estimated width unit fallback for other glyph types.
const double _svgTextUnitForOtherGlyph = 0.70;

/// Renders a triangular directional badge using BadgeModel
void renderTriangularBadge(StringBuffer buffer, BadgeModel badge) {
  if (badge.count <= 0) return;

  buffer.write(badge.renderSvg());
}

/// Builds sorted incoming/outgoing peer lists for tooltip display.
/// Returns a record with `incoming` and `outgoing` maps keyed by item.
({Map<String, List<String>> incoming, Map<String, List<String>> outgoing})
buildPeerLists(
  Map<String, List<String>> graph, {
  String Function(String)? labelFor,
}) {
  final incoming = <String, Set<String>>{};
  final outgoing = <String, Set<String>>{};
  final label = labelFor ?? (p) => p.split('/').last;

  for (final entry in graph.entries) {
    final source = entry.key;
    final sourceLabel = label(source);
    for (final target in entry.value) {
      final targetLabel = label(target);
      outgoing.putIfAbsent(source, () => <String>{}).add(targetLabel);
      incoming.putIfAbsent(target, () => <String>{}).add(sourceLabel);
    }
  }

  List<String> sorted(Set<String> s) => (s.toList()..sort());

  return (
    incoming: incoming.map((k, v) => MapEntry(k, sorted(v))),
    outgoing: outgoing.map((k, v) => MapEntry(k, sorted(v))),
  );
}

/// Renders an SVG edge with a tooltip containing source and target.
void renderEdgeWithTooltip(
  StringBuffer buffer, {
  required String pathData,
  required String source,
  required String target,
  required String cssClass,
  String separator = '▶',
}) {
  buffer.writeln('<g>');
  buffer.writeln('  <path d="$pathData" class="$cssClass"/>');
  buffer.writeln('  <title>$source $separator $target</title>');
  buffer.writeln('</g>');
}

/// Generates an empty SVG with a custom message.
String generateEmptySvg(String message) {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="200" fill="#f8f9fa"/>
  <text x="200" y="100" text-anchor="middle" fill="#6c757d"
        font-family="Arial, sans-serif" font-size="16">$message</text>
</svg>''';
}

/// Computes a font size that keeps [text] within [maxWidth] in SVG labels.
///
/// The estimate is intentionally lightweight (character class weighted) so
/// exporters can quickly downscale text before rendering.
double fitTextFontSize(
  String text, {
  required double maxWidth,
  double baseFontSize = _defaultFittedTextBaseFontSize,
  double minFontSize = _defaultFittedTextMinFontSize,
}) {
  if (text.isEmpty || maxWidth <= 0) {
    return minFontSize;
  }

  final safeBase = baseFontSize > 0
      ? baseFontSize
      : _defaultFittedTextBaseFontSize;
  final safeMin = math.max(1.0, math.min(minFontSize, safeBase));
  final estimatedUnits = _estimateSvgTextUnits(text);
  if (estimatedUnits <= 0) {
    return safeBase;
  }

  final requiredFontSize = maxWidth / estimatedUnits;
  final fitted = math.min(safeBase, requiredFontSize);
  return fitted.clamp(safeMin, safeBase).toDouble();
}

/// Returns [smallClass] when [text] needs downsizing to fit [maxWidth].
String fittedTextClass(
  String text, {
  required double maxWidth,
  double baseFontSize = _defaultFittedTextBaseFontSize,
  double minFontSize = _defaultFittedTextMinFontSize,
  String normalClass = 'textNormal',
  String smallClass = 'textSmall',
}) {
  final fitted = fitTextFontSize(
    text,
    maxWidth: maxWidth,
    baseFontSize: baseFontSize,
    minFontSize: minFontSize,
  );

  /// Tolerance for floating-point comparison.
  const double epsilon = 0.01;
  return fitted < (baseFontSize - epsilon) ? smallClass : normalClass;
}

/// Estimates SVG width units for [text] based on coarse glyph categories.
double _estimateSvgTextUnits(String text) {
  var units = 0.0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);

    if (char == ' ' || char == '\t') {
      units += _svgTextUnitForWhitespace;
      continue;
    }

    if ("ilI1|.,:;!'`".contains(char)) {
      units += _svgTextUnitForNarrowGlyph;
      continue;
    }

    if ('MW@#%&'.contains(char)) {
      units += _svgTextUnitForWideGlyph;
      continue;
    }

    if (rune >= _asciiDigitStartRune && rune <= _asciiDigitEndRune) {
      units += _svgTextUnitForDigit;
      continue;
    }

    if (rune >= _asciiUppercaseStartRune && rune <= _asciiUppercaseEndRune) {
      units += _svgTextUnitForUppercase;
      continue;
    }

    if (rune >= _asciiLowercaseStartRune && rune <= _asciiLowercaseEndRune) {
      units += _svgTextUnitForLowercase;
      continue;
    }

    units += _svgTextUnitForOtherGlyph;
  }

  return units;
}

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
