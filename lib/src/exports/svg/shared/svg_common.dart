import 'dart:math' as math;
import 'dart:math';

import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_styles.dart';
import 'package:path/path.dart' as p;

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

/// Character count for a leading `./` prefix.
const int _dotSlashPrefixLength = 2;

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
  String? pathStyle,
  String separator = '▶',
}) {
  final styleAttr = pathStyle == null ? '' : ' style="$pathStyle"';
  buffer.writeln('<g>');
  buffer.writeln('  <path d="$pathData" class="$cssClass"$styleAttr/>');
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

/// Resolves [rawPath] against [knownPaths], tolerating absolute/relative forms.
String? resolvePathToKnown(
  String rawPath,
  Set<String> knownPaths, {
  bool fallbackToNormalized = false,
}) {
  final normalizedRaw = p.normalize(rawPath).replaceAll('\\', '/');
  if (knownPaths.contains(normalizedRaw)) {
    return normalizedRaw;
  }

  final noDot = normalizedRaw.startsWith('./')
      ? normalizedRaw.substring(_dotSlashPrefixLength)
      : normalizedRaw;
  if (knownPaths.contains(noDot)) {
    return noDot;
  }

  String? bestMatch;
  for (final candidate in knownPaths) {
    if (candidate == normalizedRaw ||
        candidate.endsWith('/$normalizedRaw') ||
        normalizedRaw.endsWith('/$candidate') ||
        candidate == noDot ||
        candidate.endsWith('/$noDot') ||
        noDot.endsWith('/$candidate')) {
      if (bestMatch == null || candidate.length > bestMatch.length) {
        bestMatch = candidate;
      }
    }
  }

  if (bestMatch != null) {
    return bestMatch;
  }
  return fallbackToNormalized ? normalizedRaw : null;
}

/// Builds multiline warning tooltip content with sorted warning groups.
String buildWarningTooltipTitle(
  String heading,
  Map<String, int>? warningTypeCounts,
) {
  final lines = <String>[heading];
  if (warningTypeCounts != null && warningTypeCounts.isNotEmpty) {
    lines.add('');
    final sorted = warningTypeCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    for (final entry in sorted) {
      final suffix = entry.value == 1 ? 'warning' : 'warnings';
      lines.add('${entry.value} ${entry.key} $suffix');
    }
  }
  return escapeXml(lines.join('\n'));
}

/// Maps layer-analysis issue type to display severity.
String? severityForLayersIssueType(LayersIssueType type) {
  switch (type) {
    case LayersIssueType.cyclicDependency:
    case LayersIssueType.folderCycle:
      return 'error';
    case LayersIssueType.wrongLayer:
    case LayersIssueType.wrongFolderLayer:
      return 'warning';
  }
}

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

/// Vertical offset for Bezier curve "belly" creating smooth curved paths.
/// Used to route edges with a gentle arc, improving visual clarity and avoiding
/// sharp angles. Applied to both control points equally for symmetric curves.
const double bezierBellyHeight = 16.0;

/// Horizontal distance between adjacent stacked edge lanes.
const double stackedEdgeLaneStepWidth = 3.0;

/// Default horizontal offset from the node anchor to the first stacked lane.
const double stackedEdgeBaseOffset = 28.0;

/// Default elbow radius for stacked edge routing.
const double stackedEdgeCornerRadius = 6.0;

/// Builds a cubic Bezier path connecting two points with a smooth curve.
///
/// Creates a curved path from [startX], [startY] to [endX], [endY] by
/// interpolating control points that are offset by [bezierBellyHeight] from
/// the start and end Y positions. This produces a gentle arc that looks
/// natural and avoids overlapping with nearby elements.
///
/// The control point X coordinates are positioned at half the horizontal
/// distance to distribute the curve evenly across the path.
/// For left-exit edges (isLeftExit=true), the curve bulges outward to the left
/// first before curving down and toward the end point. For right-exit edges
/// (isLeftExit=false), the curve bulges outward to the right.
/// This directional routing makes left/right column edges visually distinct.
String buildBezierEdgePath(
  double startX,
  double startY,
  double endX,
  double endY, {
  required bool isLeftExit,
  bool isLeftArrival = true,
}) {
  const double controlPointFactor = 0.5;
  final dx = (endX - startX).abs();

  // First control point: extends outward based on exit direction
  final controlX1 = isLeftExit
      ? startX -
            dx *
                controlPointFactor // Left exits go further left
      : startX + dx * controlPointFactor; // Right exits go further right

  // Second control point: approaches end point from the selected side.
  final controlX2 = isLeftArrival
      ? endX - dx * controlPointFactor
      : endX + dx * controlPointFactor;

  final cy1 = startY + bezierBellyHeight;
  final cy2 = endY + bezierBellyHeight;
  return 'M $startX $startY C $controlX1 $cy1, $controlX2 $cy2, $endX $endY';
}

/// Builds a directional edge with stacked columns, handling both left and right lanes.
String buildStackedEdgePath(
  double startX,
  double startY,
  double endX,
  double endY,
  int laneIndex, {
  required bool isLeft,
  double? fixedColumnX,
  double baseOffset = stackedEdgeBaseOffset,
  double laneStepWidth = stackedEdgeLaneStepWidth,
  double cornerRadius = stackedEdgeCornerRadius,
}) {
  final dirY = endY >= startY ? 1.0 : -1.0;
  final dirX = isLeft ? -1.0 : 1.0;

  final columnX =
      fixedColumnX ??
      (startX + (dirX * baseOffset) + (dirX * laneIndex * laneStepWidth));

  final preCurveX = columnX - (dirX * cornerRadius);
  final postCurveX = columnX - (dirX * cornerRadius);
  final firstQx = columnX;
  final firstQy = startY + dirY * cornerRadius;

  final secondVy = endY - dirY * cornerRadius;
  final secondQy = endY;

  return 'M $startX $startY '
      'H $preCurveX '
      'Q $firstQx $startY $firstQx $firstQy '
      'V $secondVy '
      'Q $firstQx $secondQy $postCurveX $secondQy '
      'H $endX';
}

/// Computes the shared fixed X column used by stacked edge lanes.
double computeLaneColumnX({
  required double gutterX,
  required int laneIndex,
  required int laneCount,
  required bool isLeft,
  required double baseOffset,
  double laneStepWidth = stackedEdgeLaneStepWidth,
}) {
  final maxLaneIndex = laneCount - 1;
  final inwardFirstLaneIndex = maxLaneIndex - laneIndex;
  final laneDirection = isLeft ? -1.0 : 1.0;
  return gutterX +
      laneDirection * (baseOffset + inwardFirstLaneIndex * laneStepWidth);
}

/// Assigns stacked lane slots by vertical-span overlap.
///
/// Returned lane slots preserve the existing drawing convention where larger
/// slot values represent the visually inner lanes.
Map<String, int> buildVerticalSpanLaneSlots<T>(
  Iterable<T> items, {
  required String Function(T) keyOf,
  required double? Function(T) startYOf,
  required double? Function(T) endYOf,
}) {
  final innerLaneByKey = <String, int>{};
  final laneIntervals = <List<Point<double>>>[];

  final sortedItems = items.toList(growable: false)
    ..sort((a, b) {
      final aStartY = startYOf(a);
      final aEndY = endYOf(a);
      final bStartY = startYOf(b);
      final bEndY = endYOf(b);

      final aSpan = (aStartY == null || aEndY == null)
          ? double.infinity
          : (aStartY - aEndY).abs();
      final bSpan = (bStartY == null || bEndY == null)
          ? double.infinity
          : (bStartY - bEndY).abs();

      final spanCompare = aSpan.compareTo(bSpan);
      if (spanCompare != 0) {
        return spanCompare;
      }

      return keyOf(a).compareTo(keyOf(b));
    });

  bool overlaps(Point<double> a, Point<double> b) {
    return math.max(a.x, b.x) < math.min(a.y, b.y);
  }

  for (final item in sortedItems) {
    final startY = startYOf(item);
    final endY = endYOf(item);
    if (startY == null || endY == null) {
      continue;
    }

    final key = keyOf(item);
    final interval = Point(math.min(startY, endY), math.max(startY, endY));
    var assignedLane = -1;

    for (var lane = 0; lane < laneIntervals.length; lane++) {
      final intersectsExisting = laneIntervals[lane].any(
        (other) => overlaps(interval, other),
      );
      if (!intersectsExisting) {
        assignedLane = lane;
        laneIntervals[lane].add(interval);
        break;
      }
    }

    if (assignedLane == -1) {
      laneIntervals.add([interval]);
      assignedLane = laneIntervals.length - 1;
    }

    innerLaneByKey[key] = assignedLane;
  }

  final laneCount = laneIntervals.length;
  if (laneCount == 0) {
    return const <String, int>{};
  }

  final laneSlotByKey = <String, int>{};
  for (final entry in innerLaneByKey.entries) {
    laneSlotByKey[entry.key] = (laneCount - 1) - entry.value;
  }
  return laneSlotByKey;
}
