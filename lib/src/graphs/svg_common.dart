import 'dart:math' as math;

import 'badge_model.dart';

/// Renders a triangular directional badge using BadgeModel
void renderTriangularBadge(
  StringBuffer buffer,
  BadgeModel badge,
) {
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
  double baseFontSize = 14.0,
  double minFontSize = 6.0,
}) {
  if (text.isEmpty || maxWidth <= 0) {
    return minFontSize;
  }

  final safeBase = baseFontSize > 0 ? baseFontSize : 14.0;
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
  double baseFontSize = 14.0,
  double minFontSize = 6.0,
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

double _estimateSvgTextUnits(String text) {
  var units = 0.0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);

    if (char == ' ' || char == '\t') {
      units += 0.35;
      continue;
    }

    if ("ilI1|.,:;!'`".contains(char)) {
      units += 0.35;
      continue;
    }

    if ('MW@#%&'.contains(char)) {
      units += 0.95;
      continue;
    }

    if (rune >= 48 && rune <= 57) {
      units += 0.60;
      continue;
    }

    if (rune >= 65 && rune <= 90) {
      units += 0.67;
      continue;
    }

    if (rune >= 97 && rune <= 122) {
      units += 0.56;
      continue;
    }

    units += 0.70;
  }

  return units;
}
