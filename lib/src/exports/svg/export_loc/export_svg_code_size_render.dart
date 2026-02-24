part of 'export_svg_code_size.dart';

/// Renders the folder group as a recursive level-by-level treemap.
void _renderFolderGroup(
  StringBuffer buffer,
  _FolderTreeNode root,
  _Rect rect, {
  required Map<String, List<_ClassGroup>> classGroupsByFile,
}) {
  final usableRect = _Rect(
    x: rect.x,
    y: rect.y,
    width: math.max(0, rect.width),
    height: math.max(0, rect.height),
  );
  if (usableRect.width <= _minUsableDimension ||
      usableRect.height <= _minUsableDimension ||
      !root.hasEntries) {
    return;
  }

  _renderFolderLevel(
    buffer,
    node: root,
    rect: usableRect,
    depth: 0,
    classGroupsByFile: classGroupsByFile,
  );
}

/// Renders one folder level by treemapping its direct files/subfolders.
void _renderFolderLevel(
  StringBuffer buffer, {
  required _FolderTreeNode node,
  required _Rect rect,
  required int depth,
  required Map<String, List<_ClassGroup>> classGroupsByFile,
}) {
  final entries = _folderEntriesForNode(node);
  if (entries.isEmpty) {
    return;
  }

  final entryRects = _layoutTreemap(
    entries
        .map((entry) => _WeightedNode(id: entry.id, weight: entry.size))
        .toList(),
    rect,
  );

  for (final entry in entries) {
    final entryRect = entryRects[entry.id];
    if (entryRect == null ||
        entryRect.width <= _minUsableDimension ||
        entryRect.height <= _minUsableDimension) {
      continue;
    }

    final depthTint =
        (_folderDepthOpacityBase - (depth * _folderDepthOpacityStep)).clamp(
          _folderDepthOpacityMin,
          _folderDepthOpacityBase,
        );
    final fillOpacity = depthTint.toStringAsFixed(_opacityDecimalPlaces);
    final fillColor = entry.isFolder
        ? _folderTileFillColor
        : _fileTileFillColor;
    final cornerRadius = entry.isFolder ? 0.0 : _innerTileCornerRadius;
    final escapedLabel = escapeXml(entry.label);
    final escapedPath = escapeXml(entry.path);

    buffer.writeln('<g>');
    buffer.writeln(
      '  <rect x="${entryRect.x}" y="${entryRect.y}" width="${entryRect.width}" height="${entryRect.height}"${_cornerRadiusAttributes(cornerRadius)} fill="$fillColor" fill-opacity="$fillOpacity"/>',
    );
    _renderInnerTileGradientOverlay(
      buffer,
      entryRect,
      cornerRadius: cornerRadius,
    );
    _renderThinWhiteTileBorder(buffer, entryRect, cornerRadius: cornerRadius);
    buffer.writeln(
      '  <title>${entry.isFolder ? "folder" : "file"}: $escapedLabel | ${formatCount(entry.size)} LOC | $escapedPath</title>',
    );

    final fileClassGroups = entry.isFolder
        ? const <_ClassGroup>[]
        : (classGroupsByFile[entry.path] ?? const <_ClassGroup>[]);
    final fileHasNestedClasses = fileClassGroups.isNotEmpty;

    if (entry.isFolder || fileHasNestedClasses) {
      _renderFolderTopLeftLabel(
        buffer,
        rect: entryRect,
        label: escapedLabel,
        size: entry.size,
      );
    } else {
      _renderNameTopLeftLabel(buffer, rect: entryRect, label: escapedLabel);
      _renderLocBottomRightLabel(buffer, rect: entryRect, size: entry.size);
    }

    final folder = entry.folder;
    if (folder != null &&
        folder.hasEntries &&
        entryRect.width >= _folderNestedMinWidth &&
        entryRect.height >= _folderNestedMinHeight) {
      final nestedRect = _Rect(
        x: entryRect.x + _folderNestedInset,
        y: entryRect.y + _folderNestedHeaderHeight,
        width: entryRect.width - (_folderNestedInset * _doubleInsetMultiplier),
        height:
            entryRect.height - _folderNestedHeaderHeight - _folderNestedInset,
      );
      if (nestedRect.width > _minUsableDimension &&
          nestedRect.height > _minUsableDimension) {
        _renderFolderLevel(
          buffer,
          node: folder,
          rect: nestedRect,
          depth: depth + 1,
          classGroupsByFile: classGroupsByFile,
        );
      }
    }
    if (!entry.isFolder &&
        fileHasNestedClasses &&
        entryRect.width >= _classNestedMinWidth &&
        entryRect.height >= _classNestedMinHeight) {
      final classRect = _Rect(
        x: entryRect.x + _classNestedInset,
        y: entryRect.y + _classNestedHeaderHeight,
        width: entryRect.width - (_classNestedInset * _doubleInsetMultiplier),
        height: entryRect.height - _classNestedHeaderHeight - _classNestedInset,
      );
      _renderFileClasses(buffer, classGroups: fileClassGroups, rect: classRect);
    }
    buffer.writeln('</g>');
  }
}

/// Renders class containers and nested callables within a file tile.
void _renderFileClasses(
  StringBuffer buffer, {
  required List<_ClassGroup> classGroups,
  required _Rect rect,
}) {
  if (rect.width <= _minUsableDimension ||
      rect.height <= _minUsableDimension ||
      classGroups.isEmpty) {
    return;
  }

  final classRects = _layoutTreemap(
    classGroups
        .map(
          (group) =>
              _WeightedNode(id: 'class:${group.label}', weight: group.size),
        )
        .toList(growable: false),
    rect,
  );

  for (final classGroup in classGroups) {
    final classRect = classRects['class:${classGroup.label}'];
    if (classRect == null ||
        classRect.width <= _minUsableDimension ||
        classRect.height <= _minUsableDimension) {
      continue;
    }

    buffer.writeln('<g>');
    buffer.writeln(
      '  <rect x="${classRect.x}" y="${classRect.y}" width="${classRect.width}" height="${classRect.height}" fill="$_classTileFillColor" fill-opacity="0.78"/>',
    );
    _renderInnerTileGradientOverlay(buffer, classRect);
    _renderThinWhiteTileBorder(buffer, classRect);
    buffer.writeln(
      '  <title>class: ${escapeXml(classGroup.label)} | ${formatCount(classGroup.size)} LOC | ${escapeXml(classGroup.sourcePath)}</title>',
    );
    _renderFolderTopLeftLabel(
      buffer,
      rect: classRect,
      label: escapeXml(classGroup.label),
      size: classGroup.size,
    );

    if (classGroup.callables.isNotEmpty &&
        classRect.width >= _classNestedMinWidth &&
        classRect.height >= _classNestedMinHeight) {
      final nestedRect = _Rect(
        x: classRect.x + _classNestedInset,
        y: classRect.y + _classNestedHeaderHeight,
        width: classRect.width - (_classNestedInset * _doubleInsetMultiplier),
        height: classRect.height - _classNestedHeaderHeight - _classNestedInset,
      );
      if (nestedRect.width > _minUsableDimension &&
          nestedRect.height > _minUsableDimension) {
        final callableRects = _layoutTreemap(
          classGroup.callables
              .map(
                (callable) => _WeightedNode(
                  id: callable.stableId,
                  weight: callable.linesOfCode,
                ),
              )
              .toList(growable: false),
          nestedRect,
        );
        for (final callable in classGroup.callables) {
          final callableRect = callableRects[callable.stableId];
          if (callableRect == null ||
              callableRect.width <= _minUsableDimension ||
              callableRect.height <= _minUsableDimension) {
            continue;
          }

          final callableName = escapeXml(callable.name);
          final callablePath = escapeXml(callable.filePath);
          buffer.writeln('<g>');
          buffer.writeln(
            '  <rect x="${callableRect.x}" y="${callableRect.y}" width="${callableRect.width}" height="${callableRect.height}"${_cornerRadiusAttributes(_innerTileCornerRadius)} fill="$_methodTileFillColor" fill-opacity="0.72"/>',
          );
          _renderInnerTileGradientOverlay(
            buffer,
            callableRect,
            cornerRadius: _innerTileCornerRadius,
          );
          _renderThinWhiteTileBorder(
            buffer,
            callableRect,
            cornerRadius: _innerTileCornerRadius,
          );
          buffer.writeln(
            '  <title>callable: $callableName | ${formatCount(callable.linesOfCode)} LOC | $callablePath${callable.startLine > 0 ? ':${callable.startLine}' : ''}</title>',
          );
          _renderTileLabel(
            buffer,
            rect: callableRect,
            label: callableName,
            size: callable.linesOfCode,
          );
          buffer.writeln('</g>');
        }
      }
    }
    buffer.writeln('</g>');
  }
}

/// Renders folder names in the top-left corner of folder containers.
void _renderFolderTopLeftLabel(
  StringBuffer buffer, {
  required _Rect rect,
  required String label,
  required int size,
}) {
  final locLabel = '${formatCount(size)} LOC';
  final leftX = rect.x + _folderLabelInsetX;
  final rightX = rect.x + rect.width - _folderLabelInsetX;
  final y = rect.y + _folderLabelInsetY + _folderLabelBaseFontSize;
  final maxWidth = rect.width - (_folderLabelInsetX * _doubleInsetMultiplier);
  final locMaxWidth = maxWidth * _folderLabelLocWidthRatio;
  final labelMaxWidth = math.max(0.0, maxWidth - locMaxWidth - _folderLabelGap);
  final labelFontSize = fitTextFontSize(
    label,
    maxWidth: labelMaxWidth,
    baseFontSize: _folderLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );
  buffer.writeln(
    '  <text x="$leftX" y="$y" text-anchor="start" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" font-weight="700">$label</text>',
  );
  buffer.writeln(
    '  <text x="$rightX" y="$y" text-anchor="end" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" font-weight="700">$locLabel</text>',
  );
}

/// Renders centered two-line tile text (label and LOC).
void _renderTileLabel(
  StringBuffer buffer, {
  required _Rect rect,
  required String label,
  required int size,
}) {
  final centerX = rect.x + (rect.width / _binarySplitHalfRatio);
  final centerY = rect.y + (rect.height / _binarySplitHalfRatio);
  final labelFontSize = fitTextFontSize(
    label,
    maxWidth: rect.width - _labelHorizontalPadding,
    baseFontSize: _nameLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );
  final locLabel = formatCount(size);
  buffer.writeln(
    '  <text x="$centerX" y="$centerY" text-anchor="middle" dominant-baseline="middle" fill="#000" font-weight="700">',
  );
  buffer.writeln(
    '    <tspan x="$centerX" dy="$_twoLineNameDy" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}">$label</tspan>',
  );
  buffer.writeln(
    '    <tspan x="$centerX" dy="$_twoLineLocDy" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}">$locLabel</tspan>',
  );
  buffer.writeln('  </text>');
}

/// Renders top-left aligned name-only text.
void _renderNameTopLeftLabel(
  StringBuffer buffer, {
  required _Rect rect,
  required String label,
}) {
  final x = rect.x + _folderLabelInsetX;
  final y = rect.y + _folderLabelInsetY + _folderLabelBaseFontSize;
  final maxWidth = math.max(
    0.0,
    rect.width - (_folderLabelInsetX * _doubleInsetMultiplier),
  );
  final fontSize = fitTextFontSize(
    label,
    maxWidth: maxWidth,
    baseFontSize: _folderLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );
  buffer.writeln(
    '  <text x="$x" y="$y" text-anchor="start" font-size="${fontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" font-weight="700">$label</text>',
  );
}

/// Renders LOC in bottom-right corner.
void _renderLocBottomRightLabel(
  StringBuffer buffer, {
  required _Rect rect,
  required int size,
}) {
  final locLabel = '${formatCount(size)} LOC';
  final maxWidth = math.max(
    0.0,
    rect.width - (_folderLabelInsetX * _doubleInsetMultiplier),
  );
  final fontSize = fitTextFontSize(
    locLabel,
    maxWidth: maxWidth,
    baseFontSize: _folderLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );
  final x = rect.x + rect.width - _folderLabelInsetX;
  final y = rect.y + rect.height - _folderLabelInsetY;
  buffer.writeln(
    '  <text x="$x" y="$y" text-anchor="end" dominant-baseline="ideographic" font-size="${fontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" font-weight="700">$locLabel</text>',
  );
}

/// Adds diagonal light-to-shadow texture for inner tiles.
void _renderInnerTileGradientOverlay(
  StringBuffer buffer,
  _Rect rect, {
  double cornerRadius = 0.0,
}) {
  buffer.writeln(
    '  <rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}"${_cornerRadiusAttributes(cornerRadius)} fill="url(#$_innerTileDiagonalGradientId)"/>',
  );
}

/// Returns rounded-corner SVG attributes for the provided radius.
///
/// Produces an empty string when `radius` is not positive.
String _cornerRadiusAttributes(double radius) {
  if (radius <= 0) {
    return '';
  }
  final radiusText = radius.toStringAsFixed(_opacityDecimalPlaces);
  return ' rx="$radiusText" ry="$radiusText"';
}

void _renderThinWhiteTileBorder(
  StringBuffer buffer,
  _Rect rect, {
  double cornerRadius = 0.0,
}) {
  buffer.writeln(
    '  <rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}"${_cornerRadiusAttributes(cornerRadius)} fill="none" stroke="$_tileBorderColor" stroke-opacity="$_tileBorderOpacity" stroke-width="$_tileBorderWidth"/>',
  );
}
