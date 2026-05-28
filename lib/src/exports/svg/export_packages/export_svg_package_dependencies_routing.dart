part of 'export_svg_package_dependencies.dart';

const double _packageLaneGutterOffset = 18;
const double _packageLaneBaseOffset = 0;

typedef _PackageColumnEdge = ({
  String sourcePackage,
  String targetPackage,
  String targetVersion,
  double startX,
  double startY,
  double endX,
  double endY,
});

typedef _DerivedLevelEdge = ({
  String sourcePackage,
  String targetPackage,
  String targetVersion,
  double startX,
  double startY,
  double endX,
  double endY,
});

/// Draws edges from each direct package node to its derived package nodes.
/// For left column, edges exit from the left edge; for right column, from the right edge.
void writeColumnEdges(
  StringBuffer buffer, {
  required double x,
  required List<PackageDependencyNode> packages,
  required Map<String, List<PackageDependencyNode>> derivedMap,
  required Map<String, ({double x, double y})> derivedPositions,
  required double columnsTopY,
  required bool isLeftColumn,
}) {
  final edges = <_PackageColumnEdge>[];
  for (var i = 0; i < packages.length; i++) {
    final pkg = packages[i];
    final pkgStartX = isLeftColumn ? x : x + _nodeWidth;
    final pkgCenterY =
        columnsTopY +
        i * (_nodeHeight + _packageSlotSpacing) +
        (_nodeHeight / _halfDivisor);
    final derived = derivedMap[pkg.name] ?? const <PackageDependencyNode>[];
    for (final derivedPkg in derived) {
      final pos = derivedPositions[derivedPkg.name];
      if (pos == null) {
        continue;
      }
      edges.add((
        sourcePackage: pkg.name,
        targetPackage: derivedPkg.name,
        targetVersion: derivedPkg.version,
        startX: pkgStartX,
        startY: pkgCenterY,
        endX: isLeftColumn ? pos.x : pos.x + _derivedNodeWidth,
        endY: pos.y + (_derivedNodeHeight / _halfDivisor),
      ));
    }
  }

  if (edges.isEmpty) {
    return;
  }

  final laneSlotByEdgeKey = buildVerticalSpanLaneSlots<_PackageColumnEdge>(
    edges,
    keyOf: (edge) => '${edge.sourcePackage}->${edge.targetPackage}',
    startYOf: (edge) => edge.startY,
    endYOf: (edge) => edge.endY,
  );
  final laneCount = laneSlotByEdgeKey.isEmpty
      ? 0
      : laneSlotByEdgeKey.values.reduce(max) + 1;
  final laneGutterX = isLeftColumn
      ? x - _packageLaneGutterOffset
      : x + _nodeWidth + _packageLaneGutterOffset;

  final sortedEdges = List<_PackageColumnEdge>.from(edges)
    ..sort((a, b) {
      final aKey = '${a.sourcePackage}->${a.targetPackage}';
      final bKey = '${b.sourcePackage}->${b.targetPackage}';
      final aLaneSlot = laneSlotByEdgeKey[aKey] ?? 0;
      final bLaneSlot = laneSlotByEdgeKey[bKey] ?? 0;
      final laneCompare = bLaneSlot.compareTo(aLaneSlot);
      if (laneCompare != 0) {
        return laneCompare;
      }

      final aSpan = (a.startY - a.endY).abs();
      final bSpan = (b.startY - b.endY).abs();
      final spanCompare = bSpan.compareTo(aSpan);
      if (spanCompare != 0) {
        return spanCompare;
      }

      return aKey.compareTo(bKey);
    });

  for (final edge in sortedEdges) {
    final edgeKey = '${edge.sourcePackage}->${edge.targetPackage}';
    final laneSlot = laneSlotByEdgeKey[edgeKey] ?? 0;
    final fixedColumnX = computeLaneColumnX(
      gutterX: laneGutterX,
      laneIndex: laneSlot,
      laneCount: laneCount,
      isLeft: isLeftColumn,
      baseOffset: _packageLaneBaseOffset,
    );
    final pathData = buildStackedEdgePath(
      edge.startX,
      edge.startY,
      edge.endX,
      edge.endY,
      laneSlot,
      isLeft: isLeftColumn,
      fixedColumnX: fixedColumnX,
      baseOffset: _packageLaneBaseOffset,
    );
    writeEdge(
      buffer,
      pathData: pathData,
      title:
          '${escapeXml(edge.sourcePackage)} -> ${escapeXml(edge.targetPackage)} v${escapeXml(edge.targetVersion)}',
    );
  }
}

/// Draws edges from first derived packages to the next dependency hop.
void writeDerivedLevelEdges(
  StringBuffer buffer, {
  required Map<String, List<PackageDependencyNode>> derivedMap,
  required Map<String, ({double x, double y})> sourcePositions,
  required Map<String, ({double x, double y})> targetPositions,
  required Map<String, int> rightIncomingCounts,
  required double sourceNodeWidth,
}) {
  final edges = <_DerivedLevelEdge>[];
  derivedMap.forEach((sourcePackage, targetPackages) {
    final sourcePos = sourcePositions[sourcePackage];
    if (sourcePos == null) {
      return;
    }

    final outgoingCount = targetPackages.length;
    final badgeCenterY = sourcePos.y + (_derivedNodeHeight / _halfDivisor);
    final rightBadgeAnchors = _computeDerivedRightBadgeAnchors(
      nodeCenterY: badgeCenterY,
      rightIncomingCount: rightIncomingCounts[sourcePackage] ?? 0,
      outgoingCount: outgoingCount,
    );
    final startX = sourcePos.x + sourceNodeWidth;
    final startY = rightBadgeAnchors.outgoingY;
    for (final targetPackage in targetPackages) {
      final targetPos = targetPositions[targetPackage.name];
      if (targetPos == null) {
        continue;
      }

      edges.add((
        sourcePackage: sourcePackage,
        targetPackage: targetPackage.name,
        targetVersion: targetPackage.version,
        startX: startX,
        startY: startY,
        endX: targetPos.x,
        endY: targetPos.y + (_derivedNodeHeight / _halfDivisor),
      ));
    }
  });

  if (edges.isEmpty) {
    return;
  }

  final laneSlotByEdgeKey = buildVerticalSpanLaneSlots<_DerivedLevelEdge>(
    edges,
    keyOf: (edge) => '${edge.sourcePackage}->${edge.targetPackage}',
    startYOf: (edge) => edge.startY,
    endYOf: (edge) => edge.endY,
  );
  final laneCount = laneSlotByEdgeKey.isEmpty
      ? 0
      : laneSlotByEdgeKey.values.reduce(max) + 1;
  final laneGutterX = edges.first.startX + _packageLaneGutterOffset;

  final sortedEdges = List<_DerivedLevelEdge>.from(edges)
    ..sort((a, b) {
      final aKey = '${a.sourcePackage}->${a.targetPackage}';
      final bKey = '${b.sourcePackage}->${b.targetPackage}';
      final aLaneSlot = laneSlotByEdgeKey[aKey] ?? 0;
      final bLaneSlot = laneSlotByEdgeKey[bKey] ?? 0;
      final laneCompare = bLaneSlot.compareTo(aLaneSlot);
      if (laneCompare != 0) {
        return laneCompare;
      }

      final aSpan = (a.startY - a.endY).abs();
      final bSpan = (b.startY - b.endY).abs();
      final spanCompare = bSpan.compareTo(aSpan);
      if (spanCompare != 0) {
        return spanCompare;
      }

      return aKey.compareTo(bKey);
    });

  for (final edge in sortedEdges) {
    final edgeKey = '${edge.sourcePackage}->${edge.targetPackage}';
    final laneSlot = laneSlotByEdgeKey[edgeKey] ?? 0;
    final fixedColumnX = computeLaneColumnX(
      gutterX: laneGutterX,
      laneIndex: laneSlot,
      laneCount: laneCount,
      isLeft: false,
      baseOffset: _packageLaneBaseOffset,
    );
    final pathData = buildStackedEdgePath(
      edge.startX,
      edge.startY,
      edge.endX,
      edge.endY,
      laneSlot,
      isLeft: false,
      fixedColumnX: fixedColumnX,
      baseOffset: _packageLaneBaseOffset,
    );
    writeEdge(
      buffer,
      pathData: pathData,
      title:
          '${escapeXml(edge.sourcePackage)} -> ${escapeXml(edge.targetPackage)} v${escapeXml(edge.targetVersion)}',
    );
  }
}
