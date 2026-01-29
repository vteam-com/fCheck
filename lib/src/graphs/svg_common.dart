import 'badge_model.dart';

/// Renders a circular badge with optional tooltip.
void renderBadge(
  StringBuffer buffer, {
  required double cx,
  required double cy,
  required double radius,
  required int count,
  required String color,
  required String cssClass,
  String tooltip = '',
}) {
  if (count <= 0) {
    return;
  }

  buffer.writeln('<g class="$cssClass">');
  buffer.writeln(
      '<circle cx="$cx" cy="$cy" r="$radius" fill="$color" opacity="0.85"/>');
  buffer.writeln('<text x="$cx" y="${cy + 1}">$count</text>');
  if (tooltip.isNotEmpty) {
    buffer.writeln('<title>$tooltip</title>');
  }
  buffer.writeln('</g>');
}

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
  String Function(String path)? labelFor,
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
