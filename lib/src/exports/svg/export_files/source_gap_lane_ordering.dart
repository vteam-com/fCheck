import 'dart:math';

const double _halfDivisor = 2.0;

/// Orders source-gap edges into contiguous source blocks.
///
/// The returned list is used to assign contiguous lane indices in a single
/// source gap. Sources are ordered by source Y (top-to-bottom), and each
/// source block is ordered by absolute vertical distance from source
/// **descending** so the longest-reach edge gets the leftmost (lowest index)
/// lane and shorter-reach edges nest inside it.
List<(String, String)> orderSourceGapEdgesByCrossingCost(
  List<(String, String)> edges, {
  required Map<String, Point<double>> nodePositions,
  required int nodeHeight,
  required Map<String, int> colIndexByFile,
}) {
  final edgesBySource = <String, List<(String, String)>>{};
  for (final edge in edges) {
    edgesBySource.putIfAbsent(edge.$1, () => []).add(edge);
  }

  final orderedSources = edgesBySource.keys.toList()
    ..sort((a, b) {
      final aSourceY = (nodePositions[a]?.y ?? 0) + nodeHeight / _halfDivisor;
      final bSourceY = (nodePositions[b]?.y ?? 0) + nodeHeight / _halfDivisor;
      final yCompare = aSourceY.compareTo(bSourceY);
      return yCompare != 0 ? yCompare : a.compareTo(b);
    });

  final ordered = <(String, String)>[];
  for (final source in orderedSources) {
    final sourceCenterY =
        (nodePositions[source]?.y ?? 0) + nodeHeight / _halfDivisor;
    final sourceEdges =
        List<(String, String)>.from(edgesBySource[source] ?? const [])
          ..sort((a, b) {
            final aTargetY =
                (nodePositions[a.$2]?.y ?? 0) + nodeHeight / _halfDivisor;
            final bTargetY =
                (nodePositions[b.$2]?.y ?? 0) + nodeHeight / _halfDivisor;
            final aAbsDelta = (aTargetY - sourceCenterY).abs();
            final bAbsDelta = (bTargetY - sourceCenterY).abs();
            // Largest absolute delta first (leftmost lane).
            final absCompare = bAbsDelta.compareTo(aAbsDelta);
            if (absCompare != 0) return absCompare;

            // Smaller colDiff first (leftmost lane) so adjacent edges that
            // stay vertical longer get the inner lane, while skip edges that
            // exit the vertical bundle earlier get the outer lane.
            final aColDiff =
                (colIndexByFile[a.$2] ?? 0) - (colIndexByFile[a.$1] ?? 0);
            final bColDiff =
                (colIndexByFile[b.$2] ?? 0) - (colIndexByFile[b.$1] ?? 0);
            final colCompare = aColDiff.compareTo(bColDiff);
            if (colCompare != 0) return colCompare;

            return '${a.$1}|${a.$2}'.compareTo('${b.$1}|${b.$2}');
          });
    ordered.addAll(sourceEdges);
  }

  return ordered;
}
