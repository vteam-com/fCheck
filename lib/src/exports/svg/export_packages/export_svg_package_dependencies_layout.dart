part of 'export_svg_package_dependencies.dart';

/// Collects all unique derived packages across all direct packages, sorted by name.
List<PackageDependencyNode> collectUniqueDerived(
  Map<String, List<PackageDependencyNode>> derivedMap,
) {
  final seen = <String>{};
  final result = <PackageDependencyNode>[];
  for (final nodeList in derivedMap.values) {
    for (final node in nodeList) {
      if (seen.add(node.name)) {
        result.add(node);
      }
    }
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

/// Counts visible outgoing edges for each rendered source package.
Map<String, int> buildVisibleOutgoingCounts(
  Map<String, List<PackageDependencyNode>> derivedMap,
) {
  final counts = <String, int>{};
  derivedMap.forEach((packageName, derivedPackages) {
    counts[packageName] = derivedPackages.length;
  });
  return counts;
}

/// Counts visible incoming edges for each derived package.
Map<String, int> buildVisibleDerivedIncomingCounts(
  Map<String, List<PackageDependencyNode>> derivedMap, {
  required Set<String> sourcePackageNames,
}) {
  final counts = <String, int>{};
  derivedMap.forEach((packageName, derivedPackages) {
    if (!sourcePackageNames.contains(packageName)) {
      return;
    }
    for (final derivedPackage in derivedPackages) {
      counts[derivedPackage.name] = (counts[derivedPackage.name] ?? 0) + 1;
    }
  });
  return counts;
}

/// Computes how many derived nodes fit in a row.
///
/// Package levels are intentionally rendered as a single vertical column.
int computeDerivedNodesPerRow(double _) {
  return _singleDerivedColumnCount;
}

/// Computes how many rows are needed for a package level section.
int computePackageLevelRowCount(int nodeCount, int nodesPerRow) {
  if (nodeCount == 0) {
    return 0;
  }
  return (nodeCount + nodesPerRow - _singleEntryCount) ~/ nodesPerRow;
}

/// Computes the total height for a package level section.
double computePackageLevelSectionHeight(int rowCount) {
  if (rowCount == 0) {
    return 0.0;
  }
  final gridHeight =
      rowCount * _derivedNodeHeight +
      (rowCount - _singleEntryCount) * _derivedRowSpacing;
  return _sectionHeaderHeight + _sectionToNodesGap + gridHeight;
}

/// Computes the pixel position of each derived package node, centred in rows.
Map<String, ({double x, double y})> computeDerivedPositions(
  List<PackageDependencyNode> uniqueDerived,
  int nodesPerRow, {
  required double startX,
  required double startY,
  required double innerWidth,
}) {
  final result = <String, ({double x, double y})>{};
  for (var i = 0; i < uniqueDerived.length; i++) {
    final row = i ~/ nodesPerRow;
    final col = i % nodesPerRow;
    final remaining = uniqueDerived.length - row * nodesPerRow;
    final rowNodes = remaining > nodesPerRow ? nodesPerRow : remaining;
    final rowWidth =
        rowNodes * _derivedNodeWidth + (rowNodes - 1) * _derivedColumnSpacing;
    final rowStartX = startX + (innerWidth - rowWidth) / _halfDivisor;
    final x = rowStartX + col * (_derivedNodeWidth + _derivedColumnSpacing);
    final y = startY + row * (_derivedNodeHeight + _derivedRowSpacing);
    result[uniqueDerived[i].name] = (x: x, y: y);
  }
  return result;
}
