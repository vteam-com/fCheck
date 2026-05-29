part of 'export_svg_package_dependencies.dart';

/// Renders all direct package nodes in a single column.
void writeDirectColumn(
  StringBuffer buffer, {
  required double x,
  required List<PackageDependencyNode> packages,
  required String fillColor,
  required String strokeColor,
  required double startY,
  required Map<String, int> outgoingCounts,
  required Map<String, List<String>> outgoingPeers,
  required double nodeWidth,
  required bool isLeftColumn,
  required Map<String, PackagePlatformSupport> platformSupportByPackage,
}) {
  for (var i = 0; i < packages.length; i++) {
    final y = startY + i * (_nodeHeight + _packageSlotSpacing);
    final package = packages[i];

    writePackageNodeSvg(
      buffer,
      x: x,
      y: y,
      nodeWidth: nodeWidth,
      nodeHeight: _nodeHeight,
      nameYOffset: _nodeNameYOffset,
      versionYOffset: _nodeVersionYOffset,
      node: package,
      fillColor: fillColor,
      strokeColor: strokeColor,
      platformSupport: platformSupportByPackage[package.name],
    );

    // Render badges
    final packageOutgoingPeers =
        outgoingPeers[package.name] ?? const <String>[];
    final outCount =
        outgoingCounts[package.name] ?? packageOutgoingPeers.length;

    if (outCount > 0) {
      final badgeCx = isLeftColumn ? x : x + nodeWidth;
      final badgeDirection = isLeftColumn
          ? BadgeDirection.west
          : BadgeDirection.east;
      final outgoingBadge = BadgeModel.outgoing(
        cx: badgeCx,
        cy: y + _nodeHeight / _halfDivisor,
        count: outCount,
        peers: packageOutgoingPeers,
        direction: badgeDirection,
      );
      renderTriangularBadge(buffer, outgoingBadge);
    }
  }
}

/// Renders the derived package section header without a surrounding container.
void writeDerivedSectionHeader(
  StringBuffer buffer, {
  required double sectionX,
  required double sectionY,
  required double sectionWidth,
  required String title,
  required int count,
}) {
  final plural = count == _singleEntryCount ? '' : 's';
  buffer.writeln(
    '<text x="${sectionX + (sectionWidth / _halfDivisor)}" y="${sectionY + _derivedGroupLabelY}" class="$_packageDerivedSectionLabelClass" text-anchor="middle">$title ($count item$plural)</text>',
  );
  buffer.writeln(
    '<line x1="$sectionX" y1="${sectionY + _sectionHeaderHeight}" x2="${sectionX + sectionWidth}" y2="${sectionY + _sectionHeaderHeight}" stroke="$_derivedNodeStrokeColor" stroke-width="1" opacity="0.35"/>',
  );
}

/// Renders the derived package nodes inside the group container.
void writeDerivedNodes(
  StringBuffer buffer, {
  required List<PackageDependencyNode> uniqueDerived,
  required Map<String, ({double x, double y})> derivedPositions,
  required Map<String, int> leftIncomingCounts,
  required Map<String, List<String>> leftIncomingPeers,
  required Map<String, int> rightIncomingCounts,
  required Map<String, List<String>> rightIncomingPeers,
  required Map<String, int> outgoingCounts,
  required Map<String, List<String>> outgoingPeers,
  required double nodeWidth,
  required Map<String, PackagePlatformSupport> platformSupportByPackage,
}) {
  for (final node in uniqueDerived) {
    final pos = derivedPositions[node.name];
    if (pos == null) {
      continue;
    }
    writePackageNodeSvg(
      buffer,
      x: pos.x,
      y: pos.y,
      nodeWidth: nodeWidth,
      nodeHeight: _derivedNodeHeight,
      nameYOffset: _derivedNameYOffset,
      versionYOffset: 0,
      node: node,
      fillColor: _derivedNodeFillColor,
      strokeColor: _derivedNodeStrokeColor,
      strokeDashArray: _derivedNodeDashArray,
      inlineVersion: true,
      platformSupport: platformSupportByPackage[node.name],
    );

    // Render badges
    final nodeLeftIncomingPeers =
        leftIncomingPeers[node.name] ?? const <String>[];
    final nodeRightIncomingPeers =
        rightIncomingPeers[node.name] ?? const <String>[];
    final nodeOutgoingPeers = outgoingPeers[node.name] ?? const <String>[];
    final leftInCount =
        leftIncomingCounts[node.name] ?? nodeLeftIncomingPeers.length;
    final rightInCount =
        rightIncomingCounts[node.name] ?? nodeRightIncomingPeers.length;
    final outCount = outgoingCounts[node.name] ?? nodeOutgoingPeers.length;
    final badgeCenterY = pos.y + _derivedNodeHeight / _halfDivisor;
    final rightBadgeAnchors = _computeDerivedRightBadgeAnchors(
      nodeCenterY: badgeCenterY,
      rightIncomingCount: rightInCount,
      outgoingCount: outCount,
    );

    if (leftInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x,
        cy: badgeCenterY,
        count: leftInCount,
        peers: nodeLeftIncomingPeers,
        direction: BadgeDirection.east,
      );
      renderTriangularBadge(buffer, incomingBadge);
    }

    // Right badge (incoming count) - use west to point RIGHT
    if (rightInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x + nodeWidth,
        cy: rightBadgeAnchors.incomingY,
        count: rightInCount,
        peers: nodeRightIncomingPeers,
        direction: BadgeDirection.west,
      );
      renderTriangularBadge(buffer, incomingBadge);
    }

    if (outCount > 0) {
      final outgoingBadge = BadgeModel.outgoing(
        cx: pos.x + nodeWidth,
        cy: rightBadgeAnchors.outgoingY,
        count: outCount,
        peers: nodeOutgoingPeers,
        direction: BadgeDirection.east,
      );
      renderTriangularBadge(buffer, outgoingBadge);
    }
  }
}

/// Writes a section header to [buffer] at position ([x], [y]).
///
/// Renders a title with item count and an underline in the specified [color].
void writeSectionHeader(
  StringBuffer buffer, {
  required double x,
  required double y,
  required String title,
  required String color,
  required int count,
}) {
  final plural = count == _singleEntryCount ? '' : 's';
  buffer.writeln(
    '<text x="$x" y="$y" class="$_packageSectionLabelClass">$title ($count item$plural)</text>',
  );
  buffer.writeln(
    '<line x1="$x" y1="${y + _sectionUnderlineOffset}" x2="${x + _nodeWidth}" y2="${y + _sectionUnderlineOffset}" stroke="$color" stroke-width="$_edgeStrokeWidth" opacity="$_edgeOpacity"/>',
  );
}

/// Renders an SVG edge with Bezier curve routing and tooltip.
///
/// Uses the unified `.edgeVertical` CSS class for consistent gradient and
/// hover effects across all SVG diagrams. The edge path is routed with a
/// smooth cubic Bezier curve (see [buildBezierEdgePath]) to create visual
/// clarity and improve readability.
void writeEdge(
  StringBuffer buffer, {
  required String pathData,
  required String tooltipTitle,
  String cssClass = 'edgeVertical',
}) {
  renderEdgeWithTooltip(
    buffer,
    pathData: pathData,
    cssClass: cssClass,
    tooltipTitle: tooltipTitle,
  );
}
