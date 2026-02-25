part of 'export_svg_folders.dart';

/// Draw hierarchical edges between parent and child folders.
void _drawEdgeHorizontalCurve(
  StringBuffer buffer,
  List<FolderNode> folders,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions, {
  required double padding,
  required double childIndent,
}) {
  for (final folder in folders) {
    for (final child in folder.children) {
      if (!positions.containsKey(folder.fullPath) ||
          !positions.containsKey(child.fullPath)) {
        continue;
      }

      final parentPos = positions[folder.fullPath]!;
      final childPos = positions[child.fullPath]!;
      final childDim = dimensions[child.fullPath]!;

      /// Divisor for halving dimensions.
      const double halfDivisor = 2.0;

      /// Horizontal offset for the edge connection point.
      const double edgeHorizontalOffset = 8.0;

      final parentX = parentPos.x + padding + (childIndent / halfDivisor);
      final parentY = childPos.y + (childDim.height / halfDivisor);
      final childX = childPos.x - edgeHorizontalOffset;
      final childY = childPos.y + (childDim.height / halfDivisor);

      // Control points for a gentle left-to-right curve within the parent box
      final controlX1 = parentX + (childIndent / halfDivisor);
      final controlX2 = childX - (childIndent / halfDivisor);
      final pathData =
          'M $parentX $parentY '
          'C $controlX1 $parentY, $controlX2 $childY, $childX $childY';

      renderEdgeWithTooltip(
        buffer,
        pathData: pathData,
        source: folder.name,
        target: child.name,
        cssClass: 'edgeVertical',
      );
    }
  }
}

/// Determine the CSS class for an edge based on its properties.
String _getEdgeCssClass(
  String sourceFile,
  String targetFile,
  double startY,
  double endY,
  Set<String> cycleEdges,
  Set<String> violationEdges,
) {
  final edgeKey = '$sourceFile->$targetFile';

  // Priority rule: Red (cycle) > Orange (reported upward violation) > Default
  if (cycleEdges.contains(edgeKey)) {
    return 'cycleEdge';
  } else if (violationEdges.contains(edgeKey) && startY > endY) {
    return 'warningEdge';
  } else {
    return 'edgeVertical';
  }
}

/// Draw edges between files based on dependency graph.
void _drawEdgeVerticalsFiles(
  StringBuffer buffer,
  Map<String, List<String>> graph,
  Map<String, Map<String, Point<double>>> anchors,
  Map<String, int> _, { // folderLevels
  double? rightLaneGutterX,
  Set<String> fileViolationEdges = const <String>{},
}) {
  final cycleEdges = findCycleEdges(graph);
  final drawableEdges = <_FileEdge>[];
  for (final entry in graph.entries) {
    final source = entry.key;
    final sourceAnchor = anchors[source]?['out'];
    if (sourceAnchor == null) continue;
    for (final target in entry.value) {
      final targetAnchor = anchors[target]?['in'];
      if (targetAnchor == null) continue;
      drawableEdges.add(_FileEdge(source, target));
    }
  }

  final laneSlotByEdgeKey = _buildFileLaneSlotByEdgeKey(drawableEdges, anchors);
  final fileLaneColumns = laneSlotByEdgeKey.isEmpty
      ? 0
      : laneSlotByEdgeKey.values.reduce(max) + 1;
  final sortedDrawableEdges = List<_FileEdge>.from(drawableEdges)
    ..sort((a, b) {
      final aKey = '${a.sourceFile}->${a.targetFile}';
      final bKey = '${b.sourceFile}->${b.targetFile}';
      final aLaneSlot = laneSlotByEdgeKey[aKey] ?? 0;
      final bLaneSlot = laneSlotByEdgeKey[bKey] ?? 0;

      // Draw inner lanes first so local file edges are painted under outer lanes.
      final laneCompare = bLaneSlot.compareTo(aLaneSlot);
      if (laneCompare != 0) return laneCompare;

      final aSourceY = anchors[a.sourceFile]?['out']?.y;
      final aTargetY = anchors[a.targetFile]?['in']?.y;
      final bSourceY = anchors[b.sourceFile]?['out']?.y;
      final bTargetY = anchors[b.targetFile]?['in']?.y;
      final aSpan = (aSourceY == null || aTargetY == null)
          ? double.negativeInfinity
          : (aSourceY - aTargetY).abs();
      final bSpan = (bSourceY == null || bTargetY == null)
          ? double.negativeInfinity
          : (bSourceY - bTargetY).abs();
      final spanCompare = bSpan.compareTo(aSpan);
      if (spanCompare != 0) return spanCompare;

      return aKey.compareTo(bKey);
    });

  for (final edge in sortedDrawableEdges) {
    final source = edge.sourceFile;
    final target = edge.targetFile;
    final sourceAnchor = anchors[source]!['out']!;
    final targetAnchor = anchors[target]!['in']!;
    final startX = sourceAnchor.x;
    final startY = sourceAnchor.y;
    final endX = targetAnchor.x;
    final endY = targetAnchor.y;
    final edgeKey = '$source->$target';
    final laneSlot = laneSlotByEdgeKey[edgeKey] ?? 0;

    // Calculate fixed vertical column X for the right lane gutter if reference is provided.
    final double? fixedColumnX = rightLaneGutterX != null
        ? _computeLaneColumnX(
            gutterX: rightLaneGutterX,
            laneIndex: laneSlot,
            laneCount: fileLaneColumns,
            isLeft: false,
            baseOffset: _fileLaneBaseOffset,
          )
        : null;

    final path = _buildStackedEdgePath(
      startX,
      startY,
      endX,
      endY,
      laneSlot,
      isLeft: false,
      fixedColumnX: fixedColumnX,
    );

    /// Vertical offset to recover the original file Y-coordinate (upward).
    const double fileYOffsetUp = 6.0;

    /// Vertical offset to recover the original file Y-coordinate (downward).
    const double fileYOffsetDown = 5.0;

    final cssClass = _getEdgeCssClass(
      source,
      target,
      startY - fileYOffsetUp, // fileY
      endY + fileYOffsetDown, // fileY
      cycleEdges,
      fileViolationEdges,
    );

    renderEdgeWithTooltip(
      buffer,
      pathData: path,
      source: source,
      target: target,
      cssClass: cssClass,
    );
  }
}

/// Assigns right-lane slots so short file edges stay inner and long spans go outer.
Map<String, int> _buildFileLaneSlotByEdgeKey(
  List<_FileEdge> edges,
  Map<String, Map<String, Point<double>>> anchors,
) {
  if (edges.isEmpty) return const {};

  final innerLaneByEdgeKey = <String, int>{};
  final laneIntervals = <List<Point<double>>>[];

  final bySpanAsc = List<_FileEdge>.from(edges)
    ..sort((a, b) {
      final aSourceY = anchors[a.sourceFile]?['out']?.y;
      final aTargetY = anchors[a.targetFile]?['in']?.y;
      final bSourceY = anchors[b.sourceFile]?['out']?.y;
      final bTargetY = anchors[b.targetFile]?['in']?.y;

      final aSpan = (aSourceY == null || aTargetY == null)
          ? double.infinity
          : (aSourceY - aTargetY).abs();
      final bSpan = (bSourceY == null || bTargetY == null)
          ? double.infinity
          : (bSourceY - bTargetY).abs();

      final spanCompare = aSpan.compareTo(bSpan);
      if (spanCompare != 0) return spanCompare;

      final aKey = '${a.sourceFile}->${a.targetFile}';
      final bKey = '${b.sourceFile}->${b.targetFile}';
      return aKey.compareTo(bKey);
    });

  bool overlaps(Point<double> a, Point<double> b) {
    return max(a.x, b.x) < min(a.y, b.y);
  }

  for (final edge in bySpanAsc) {
    final sourceY = anchors[edge.sourceFile]?['out']?.y;
    final targetY = anchors[edge.targetFile]?['in']?.y;
    if (sourceY == null || targetY == null) continue;

    final key = '${edge.sourceFile}->${edge.targetFile}';
    final interval = Point(min(sourceY, targetY), max(sourceY, targetY));
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

    innerLaneByEdgeKey[key] = assignedLane;
  }

  final laneCount = laneIntervals.length;
  if (laneCount == 0) return const {};

  // Preserve current convention: higher slot index = inner lane.
  final laneSlotByEdgeKey = <String, int>{};
  for (final entry in innerLaneByEdgeKey.entries) {
    laneSlotByEdgeKey[entry.key] = (laneCount - 1) - entry.value;
  }
  return laneSlotByEdgeKey;
}

/// Draw folder-level dependency edges routed on the left side of folders.
void _drawEdgeVerticalFolders(
  StringBuffer buffer,
  List<_FolderEdge> edges,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions, {
  required double globalGutterX,
  required String rootPath,
  Set<String> folderCycles = const {},
  Map<String, Set<String>> layerViolationEdges = const {},
}) {
  if (edges.isEmpty) return;

  // Only use analyzer-reported issues to determine cycles and violations
  // Don't do our own cycle detection which may differ from analyzer logic
  final Set<String> cycleEdges = <String>{};
  final Set<String> violationEdges = <String>{};
  for (final edge in edges) {
    final edgeKey = '${edge.sourceFolder}->${edge.targetFolder}';
    // Mark as cycle edge only if analyzer reported a folderCycle for this folder
    if (folderCycles.contains(edge.sourceFolder) ||
        folderCycles.contains(edge.targetFolder)) {
      cycleEdges.add(edgeKey);
    }
    // Mark as violation edge ONLY if this specific edge is in the layerViolationEdges map
    final violatingTargets = layerViolationEdges[edge.sourceFolder];
    if (violatingTargets != null &&
        violatingTargets.contains(edge.targetFolder)) {
      violationEdges.add(edgeKey);
    }
  }

  // Group edges by their common parent path to create local gutters
  final edgesByParent = <String, List<_FolderEdge>>{};
  for (final edge in edges) {
    // Both folders are siblings due to hierarchical roll-up, so they share a parent
    final parentPath = _getFolderPath(edge.sourceFolder, rootPath);
    edgesByParent.putIfAbsent(parentPath, () => []).add(edge);
  }

  final sortedParentPaths = edgesByParent.keys.toList()
    ..sort((a, b) {
      final depthCompare = _folderDepthFromRoot(
        b,
        rootPath,
      ).compareTo(_folderDepthFromRoot(a, rootPath));
      if (depthCompare != 0) return depthCompare;
      return a.compareTo(b);
    });

  for (final parentPath in sortedParentPaths) {
    final parentEdges = List<_FolderEdge>.from(edgesByParent[parentPath]!)
      ..sort((a, b) {
        final virtualCompare = _folderEdgeVirtualRank(
          a,
        ).compareTo(_folderEdgeVirtualRank(b));
        if (virtualCompare != 0) return virtualCompare;

        final aDepth = max(
          _folderDepthFromRoot(a.sourceFolder, rootPath),
          _folderDepthFromRoot(a.targetFolder, rootPath),
        );
        final bDepth = max(
          _folderDepthFromRoot(b.sourceFolder, rootPath),
          _folderDepthFromRoot(b.targetFolder, rootPath),
        );
        final depthCompare = bDepth.compareTo(aDepth);
        if (depthCompare != 0) return depthCompare;

        final spanCompare = _folderEdgeVerticalSpan(
          a,
          positions,
        ).compareTo(_folderEdgeVerticalSpan(b, positions));
        if (spanCompare != 0) return spanCompare;

        final aKey = '${a.sourceFolder}->${a.targetFolder}';
        final bKey = '${b.sourceFolder}->${b.targetFolder}';
        return aKey.compareTo(bKey);
      });

    final parentPos = positions[parentPath];
    final laneIndexByEdgeKey = _buildLaneIndexByEdgeKey(parentEdges, positions);

    for (final edge in parentEdges) {
      final edgeKey = '${edge.sourceFolder}->${edge.targetFolder}';
      final laneIndex = laneIndexByEdgeKey[edgeKey] ?? 0;
      final sourcePos = positions[edge.sourceFolder];
      final targetPos = positions[edge.targetFolder];
      final sourceDim = dimensions[edge.sourceFolder];
      final targetDim = dimensions[edge.targetFolder];

      if (sourcePos == null ||
          targetPos == null ||
          sourceDim == null ||
          targetDim == null) {
        continue;
      }

      // Start/end at badge centers.
      const double sourceBadgeOffsetX = 6.0;
      const double sourceBadgeOffsetY = 24.0;
      const double targetBadgeOffsetX = 10.0;
      const double targetBadgeOffsetY = 13.0;

      final startX = sourcePos.x + sourceBadgeOffsetX;
      final startY = sourcePos.y + sourceBadgeOffsetY;
      final endX = targetPos.x + targetBadgeOffsetX;
      final endY = targetPos.y + targetBadgeOffsetY;

      // Calculate fixed vertical column X
      // If parent exists, use its internal lane (indentation area)
      // If root, use the global lane (outside root)
      double fixedColumnX;
      if (parentPos != null) {
        /// Offset where child content begins inside a parent folder.
        const double childStartOffset = 64.0;

        /// Keep the innermost lane away from file panels/badges.
        const double laneInnerPaddingFromChildStart = 18.0;

        // Anchor the innermost lane to a fixed boundary near children.
        // Additional lanes extend leftward only, avoiding drift into components.
        final laneRightmostX =
            parentPos.x + childStartOffset - laneInnerPaddingFromChildStart;
        fixedColumnX = _computeLaneColumnX(
          gutterX: laneRightmostX,
          laneIndex: laneIndex,
          laneCount: parentEdges.length,
          isLeft: true,
          baseOffset: _folderLaneBaseOffset,
        );
      } else {
        fixedColumnX = _computeLaneColumnX(
          gutterX: globalGutterX,
          laneIndex: laneIndex,
          laneCount: parentEdges.length,
          isLeft: true,
          baseOffset: _folderLaneBaseOffset,
        );
      }

      // Folder edges use the LEFT lane (relative to the badges)
      final pathData = _buildStackedEdgePath(
        startX,
        startY,
        endX,
        endY,
        laneIndex,
        isLeft: true,
        fixedColumnX: fixedColumnX,
      );

      // Determine CSS class: cycle (red) > violation (orange) > default (gradient)
      String cssClass;
      if (cycleEdges.contains(edgeKey)) {
        cssClass = 'cycleEdge';
      } else if (violationEdges.contains(edgeKey) &&
          sourcePos.y > targetPos.y) {
        cssClass = 'warningEdge';
      } else {
        cssClass = 'edgeVertical';
      }

      renderEdgeWithTooltip(
        buffer,
        pathData: pathData,
        source: edge.sourceFolder,
        target: edge.targetFolder,
        cssClass: cssClass,
      );
    }
  }
}

/// Computes depth relative to [rootPath] so deeper groups can be prioritized.
int _folderDepthFromRoot(String folderPath, String rootPath) {
  if (folderPath == rootPath) return 0;
  if (folderPath == '.') return 0;

  if (rootPath != '.' && folderPath.startsWith('$rootPath/')) {
    final relative = folderPath.substring(rootPath.length + 1);
    if (relative.isEmpty) return 0;
    return relative.split('/').length;
  }

  return folderPath.split('/').where((segment) => segment.isNotEmpty).length;
}

/// Returns vertical span between edge endpoints to stabilize tie-breaking.
double _folderEdgeVerticalSpan(
  _FolderEdge edge,
  Map<String, Point<double>> positions,
) {
  final sourceY = positions[edge.sourceFolder]?.y;
  final targetY = positions[edge.targetFolder]?.y;
  if (sourceY == null || targetY == null) return double.infinity;
  return (sourceY - targetY).abs();
}

/// Ranks edges by virtual-folder involvement (fewer virtual endpoints first).
int _folderEdgeVirtualRank(_FolderEdge edge) {
  var rank = 0;
  if (_isVirtualFolderPath(edge.sourceFolder)) rank++;
  if (_isVirtualFolderPath(edge.targetFolder)) rank++;
  return rank;
}

bool _isVirtualFolderPath(String folderPath) {
  return p.basename(folderPath) == '...';
}

/// Assigns lane indices so longer edges use outer lanes and short edges stay close.
Map<String, int> _buildLaneIndexByEdgeKey(
  List<_FolderEdge> edges,
  Map<String, Point<double>> positions,
) {
  final lanes = <String, int>{};
  final bySpanDesc = List<_FolderEdge>.from(edges)
    ..sort((a, b) {
      final spanCompare = _folderEdgeVerticalSpan(
        b,
        positions,
      ).compareTo(_folderEdgeVerticalSpan(a, positions));
      if (spanCompare != 0) return spanCompare;
      final aKey = '${a.sourceFolder}->${a.targetFolder}';
      final bKey = '${b.sourceFolder}->${b.targetFolder}';
      return aKey.compareTo(bKey);
    });

  for (var i = 0; i < bySpanDesc.length; i++) {
    final edge = bySpanDesc[i];
    lanes['${edge.sourceFolder}->${edge.targetFolder}'] = i;
  }
  return lanes;
}

/// Render folder badges after edges so they sit on top.
void _drawFolderBadges(StringBuffer buffer, List<BadgeModel> badges) {
  for (final b in badges) {
    renderTriangularBadge(buffer, b);
  }
}

/// Draw hierarchical folder containers.
void _drawHierarchicalFolders(
  StringBuffer buffer,
  List<FolderNode> folders,
  Map<String, Point<double>> positions,
  Map<String, Rect> dimensions,
  Map<String, Map<String, int>> metrics,
  Map<String, Map<String, int>> fileMetrics,
  Map<String, List<String>> dependencyGraph,
  Map<String, Map<String, Point<double>>> fileAnchors,
  List<_TitleVisual> titleVisuals,
  List<_FileVisual> fileVisuals,
  List<BadgeModel> folderBadges,
  Map<String, List<String>> folderIncomingPeers,
  Map<String, List<String>> folderOutgoingPeers,
  Map<String, List<String>> fileIncomingPeers,
  Map<String, List<String>> fileOutgoingPeers,
  Map<String, int> depths, {
  required Map<String, String> folderSeverityByPath,
  required Map<String, String> fileSeverityByPath,
  required Map<String, Map<String, int>> folderWarningsByPath,
  required Map<String, Map<String, int>> fileWarningsByPath,
  required double headerHeight,
  required double fileItemHeight,
  required double fileItemSpacing,
  required double fileTopPadding,
  required String projectName,
  required String projectVersion,
  required String inputFolderName,
}) {
  void drawFolder(FolderNode folder) {
    final pos = positions[folder.fullPath]!;
    final dim = dimensions[folder.fullPath]!;
    final folderMetrics =
        metrics[folder.fullPath] ?? {'incoming': 0, 'outgoing': 0};
    final incoming = folderMetrics['incoming'] ?? 0;
    final outgoing = folderMetrics['outgoing'] ?? 0;
    final depth = depths[folder.fullPath] ?? 0;

    /// Corner radius for folder rectangles.
    const double folderCornerRadius = 12.0;

    /// Divisor for halving dimensions.
    const double halfDivisor = 2.0;

    /// Vertical offset for the folder title text.
    const double titleVerticalOffset = 25.0;

    buffer.writeln('<g class="folderLayer">');
    final folderSeveritySuffix = _severityClassSuffix(
      folderSeverityByPath[folder.fullPath],
    );
    final folderTitle = _buildWarningTitle(
      'Folder: ${folder.fullPath}',
      folderWarningsByPath[folder.fullPath],
    );
    if (folder.isVirtual) {
      /// Dash array for virtual folder borders.
      const String virtualFolderDashArray = '4 2';

      // Render virtual folder with dash-dot border
      final folderClass = folderSeveritySuffix == null
          ? 'layerBackgroundVirtualFolder'
          : 'layerBackgroundVirtualFolder layerBackgroundVirtualFolder$folderSeveritySuffix';
      buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="$folderCornerRadius" ry="$folderCornerRadius" class="$folderClass" stroke-dasharray="$virtualFolderDashArray"><title>$folderTitle</title></rect>',
      );
    } else {
      // Render regular folder with solid border
      final folderClass = folderSeveritySuffix == null
          ? 'layerBackground'
          : 'layerBackground layerBackground$folderSeveritySuffix';
      buffer.writeln(
        '<rect x="${pos.x}" y="${pos.y}" width="${dim.width}" height="${dim.height}" rx="$folderCornerRadius" ry="$folderCornerRadius" class="$folderClass"><title>$folderTitle</title></rect>',
      );
    }

    final indentLevels = depth > 0 ? depth : 0;
    final indent = List.filled(indentLevels, '  ').join();

    // For root folder (depth 0), show project info instead of folder name
    String titleText;
    if (depth == 0 && folder.name == '.') {
      // Show project name and version, omit folder name if it matches project name
      if (inputFolderName.toLowerCase() == projectName.toLowerCase()) {
        titleText = '$projectName v$projectVersion';
      } else {
        titleText = '$inputFolderName ($projectName v$projectVersion)';
      }
    } else {
      titleText = '$indent${folder.name}';
    }

    /// Horizontal padding reserved for folder title labels.
    const double folderTitleHorizontalPadding = 24.0;
    final titleMaxWidth = max(
      1.0,
      dim.width - (folderTitleHorizontalPadding * halfDivisor),
    );
    titleVisuals.add(
      _TitleVisual(
        pos.x + dim.width / halfDivisor,
        pos.y + titleVerticalOffset,
        titleText,
        titleMaxWidth,
      ),
    );
    buffer.writeln('</g>');

    /// Horizontal offset for the target (incoming) badge.
    const double targetBadgeOffsetX = 10.0;

    /// Vertical offset for the target (incoming) badge.
    const double targetBadgeOffsetY = 13.0;

    /// Horizontal offset for the source (outgoing) badge.
    const double sourceBadgeOffsetX = 6.0;

    /// Vertical offset for the source (outgoing) badge.
    const double sourceBadgeOffsetY = 24.0;

    folderBadges.add(
      BadgeModel.incoming(
        cx: pos.x + targetBadgeOffsetX,
        cy: pos.y + targetBadgeOffsetY,
        count: incoming,
        peers: folderIncomingPeers[folder.fullPath] ?? const [],
        direction: BadgeDirection.east, // ▶
      ),
    );
    folderBadges.add(
      BadgeModel.outgoing(
        cx: pos.x + sourceBadgeOffsetX,
        cy: pos.y + sourceBadgeOffsetY,
        count: outgoing,
        peers: folderOutgoingPeers[folder.fullPath] ?? const [],
        direction: BadgeDirection.west, // ◀
      ),
    );

    final sortedFiles = _sortFiles(
      folder.files,
      folder.fullPath,
      fileMetrics,
      dependencyGraph,
    );
    final List<Point<double>> filePositions = _calculateFilePositions(
      sortedFiles.length,
      0, // compute positions relative to folder top
      headerHeight: headerHeight,
      topPadding: fileTopPadding,
      itemHeight: fileItemHeight,
      itemSpacing: fileItemSpacing,
      startX: 0.0,
    );

    // Draw children after this folder so they appear on top
    for (final child in folder.children) {
      drawFolder(child);
    }

    // Collect file visuals; badges/text drawn later after edges
    // Process files for all folders (including virtual folders)
    if (folder.files.isNotEmpty) {
      for (var j = 0; j < sortedFiles.length; j++) {
        final file = sortedFiles[j];
        final filePos = filePositions[j];

        final fileY = pos.y + filePos.y;
        final filePath = file; // Already the original relative path
        final fileName = file.split('/').last;

        final fIncoming = fileMetrics[filePath]?['incoming'] ?? 0;
        final fOutgoing = fileMetrics[filePath]?['outgoing'] ?? 0;

        /// Horizontal margin for the file panel inside the folder.
        const double panelMarginX = 8.0;

        /// Multiplier to calculate total horizontal padding for the panel.
        const double panelPaddingMultiplier = 2.0;

        /// Vertical offset to recover the original file Y-coordinate (upward).
        const double fileYOffsetUp = 5.0;

        /// Vertical offset to recover the original file Y-coordinate (downward).
        const double fileYOffsetDown = 6.0;

        /// Offset for the outgoing badge anchor.
        const double outgoingAnchorOffset = 4.0;

        final panelX = pos.x + panelMarginX;
        final panelWidth =
            dim.width -
            (panelMarginX * panelPaddingMultiplier); // flush within folder
        final textX = pos.x + (panelWidth / halfDivisor);
        // Use panel-based coordinates for badges and edge anchors.
        final badgeX =
            panelX + panelWidth - panelMarginX; // align with folder badges
        fileAnchors[filePath] = {
          'in': Point(badgeX, fileY - fileYOffsetUp), // Incoming badge position
          'out': Point(
            badgeX + outgoingAnchorOffset,
            fileY + fileYOffsetDown,
          ), // Outgoing
        };

        final incomingPeers = fileIncomingPeers[filePath] ?? const [];
        final outgoingPeers = fileOutgoingPeers[filePath] ?? const [];

        fileVisuals.add(
          _FileVisual(
            path: filePath,
            name: fileName,
            textX: textX,
            textY: fileY,
            badgeX: badgeX,
            badgeY: fileY,
            panelX: panelX,
            panelWidth: panelWidth,
            incoming: fIncoming,
            outgoing: fOutgoing,
            incomingPeers: incomingPeers,
            outgoingPeers: outgoingPeers,
            severityClassSuffix: _severityClassSuffix(
              fileSeverityByPath[filePath],
            ),
            tooltipTitle: _buildWarningTitle(
              'File: $filePath',
              fileWarningsByPath[filePath],
            ),
          ),
        );
      }
    }
  }

  // Start recursive draw from root (first element is root)
  if (folders.isNotEmpty) {
    drawFolder(folders.first);
  }
}

/// Build a directional edge with stacked columns, handling both left and right lanes.
String _buildStackedEdgePath(
  double startX,
  double startY,
  double endX,
  double endY,
  int edgeIndex, {
  required bool isLeft,
  double? fixedColumnX,
}) {
  const double baseOffset = 28.0;
  const double radius = 6.0;
  final dirY = endY >= startY ? 1.0 : -1.0;
  final dirX = isLeft ? -1.0 : 1.0;

  // Each edge gets a slightly larger offset to avoid overlapping runs.
  // Folder edges (isLeft=true) route to the left lane, File edges to the right.
  final columnX =
      fixedColumnX ??
      (startX + (dirX * baseOffset) + (dirX * edgeIndex * _edgeLaneStepWidth));

  final preCurveX = columnX - (dirX * radius);
  final postCurveX = columnX - (dirX * radius);
  final firstQx = columnX;
  final firstQy = startY + dirY * radius;

  final secondVy = endY - dirY * radius;
  final secondQy = endY;

  return 'M $startX $startY '
      'H $preCurveX '
      'Q $firstQx $startY $firstQx $firstQy '
      'V $secondVy '
      'Q $firstQx $secondQy $postCurveX $secondQy '
      'H $endX';
}

/// Computes the shared fixed X column used by stacked edge lanes.
double _computeLaneColumnX({
  required double gutterX,
  required int laneIndex,
  required int laneCount,
  required bool isLeft,
  required double baseOffset,
}) {
  final maxLaneIndex = laneCount - 1;
  final inwardFirstLaneIndex = maxLaneIndex - laneIndex;
  final laneDirection = isLeft ? -1.0 : 1.0;
  return gutterX +
      laneDirection * (baseOffset + inwardFirstLaneIndex * _edgeLaneStepWidth);
}

/// Render file badges and labels (after edges).
void _drawFileVisuals(StringBuffer buffer, List<_FileVisual> visuals) {
  const double fileLabelBaseFontSize = 14.0;
  const double fileLabelMinFontSize = 6.0;
  const double fileLabelHorizontalPadding = 16.0;

  for (final v in visuals) {
    /// Half-height offset of the file panel.
    const double filePanelHalfHeight = 14.0;

    /// Height of the file panel.
    const double filePanelHeight = 28.0;

    /// Divisor for halving dimensions.
    const double halfDivisor = 2.0;

    final top = v.textY - filePanelHalfHeight;

    /// Vertical offset to recover the original file Y-coordinate (upward).
    const double incomingBadgeOffsetY = 5.0;

    // Create incoming badge (pointing west)
    final incomingBadge = BadgeModel.incoming(
      cx: v.badgeX,
      cy: v.badgeY - incomingBadgeOffsetY,
      count: v.incoming,
      peers: v.incomingPeers,
      direction: BadgeDirection.west,
    );
    renderTriangularBadge(buffer, incomingBadge);

    /// Horizontal offset for the outgoing badge.
    const double outgoingBadgeOffsetX = 4.0;

    /// Vertical offset to recover the original file Y-coordinate (downward).
    const double outgoingBadgeOffsetY = 6.0;

    // Create outgoing badge (pointing east)
    final outgoingBadge = BadgeModel.outgoing(
      cx: v.badgeX + outgoingBadgeOffsetX,
      cy: v.badgeY + outgoingBadgeOffsetY,
      count: v.outgoing,
      peers: v.outgoingPeers,
      direction: BadgeDirection.east,
    );
    renderTriangularBadge(buffer, outgoingBadge);
    final labelMaxWidth = max(
      1.0,
      v.panelWidth - (fileLabelHorizontalPadding * halfDivisor),
    );
    final textClass = fittedTextClass(
      v.name,
      maxWidth: labelMaxWidth,
      baseFontSize: fileLabelBaseFontSize,
      minFontSize: fileLabelMinFontSize,
    );

    buffer.writeln(
      '<text x="${v.textX}" y="${top + filePanelHeight / halfDivisor}" text-anchor="middle" dominant-baseline="middle" class="$textClass">${v.name}</text>',
    );
  }
}

/// Render file background pills before edges.
void _drawFilePanels(StringBuffer buffer, List<_FileVisual> visuals) {
  for (final v in visuals) {
    /// Half-height offset of the file panel.
    const double filePanelHalfHeight = 14.0;

    /// Height of the file panel.
    const double filePanelHeight = 28.0;

    /// Corner radius for file panel rectangles.
    const double filePanelCornerRadius = 5.0;

    final left = v.panelX;
    final width = v.panelWidth;
    final top = v.textY - filePanelHalfHeight;

    buffer.writeln(
      '<rect x="$left" y="$top" width="$width" height="$filePanelHeight" rx="$filePanelCornerRadius" ry="$filePanelCornerRadius" class="${v.severityClassSuffix == null ? 'fileNode' : 'fileNode fileNode${v.severityClassSuffix}'}"><title>${v.tooltipTitle}</title></rect>',
    );
  }
}

/// Render folder titles above all edges/items.
void _drawTitleVisuals(StringBuffer buffer, List<_TitleVisual> visuals) {
  const double titleBaseFontSize = 16.0;
  const double titleMinFontSize = 8.0;

  buffer.writeln('<g class="folderTitleLayer">');
  for (final v in visuals) {
    if (v.text.contains('|')) {
      // Multi-line text for root folder (legacy format)
      final parts = v.text.split('|');
      final longestLine = parts.reduce(
        (current, line) => line.length > current.length ? line : current,
      );
      final titleClass = fittedTextClass(
        longestLine,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );
      buffer.writeln(
        '<text x="${v.x}" y="${v.y}" class="$titleClass" text-anchor="middle">',
      );
      for (int i = 0; i < parts.length; i++) {
        final yOffset = i * _titleLineHeight; // Line height spacing
        buffer.writeln(
          '  <tspan x="${v.x}" dy="${i == 0 ? 0 : yOffset}">${parts[i]}</tspan>',
        );
      }
      buffer.writeln('</text>');
    } else if (v.text.contains('(') && v.text.contains(')')) {
      // Multi-line text for root folder: folder (project v version)
      final openParen = v.text.indexOf('(');
      final closeParen = v.text.indexOf(')');
      final firstLine = v.text.substring(0, openParen).trim();
      final secondLine = v.text.substring(openParen + 1, closeParen).trim();
      final longestLine = firstLine.length >= secondLine.length
          ? firstLine
          : secondLine;
      final titleClass = fittedTextClass(
        longestLine,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );

      buffer.writeln(
        '<text x="${v.x}" y="${v.y}" class="$titleClass" text-anchor="middle">',
      );
      buffer.writeln('  <tspan x="${v.x}" dy="0">$firstLine</tspan>');
      buffer.writeln(
        '  <tspan x="${v.x}" dy="$_titleLineHeight">$secondLine</tspan>',
      );
      buffer.writeln('</text>');
    } else {
      // Single line text for regular folders or when folder name matches project name
      final titleClass = fittedTextClass(
        v.text,
        maxWidth: v.maxWidth,
        baseFontSize: titleBaseFontSize,
        minFontSize: titleMinFontSize,
        normalClass: 'layerTitle',
        smallClass: 'layerTitleSmall',
      );
      buffer.writeln(
        '<text x="${v.x}" y="${v.y}" class="$titleClass">${v.text}</text>',
      );
    }
  }
  buffer.writeln('</g>');
}
