library;

import 'dart:math' as math;

import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/graphs/svg_common.dart';
import 'package:fcheck/src/graphs/svg_styles.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:path/path.dart' as p;

const double _binarySplitHalfRatio = 2.0;
const double _headerTextInset = 2.0;
const double _headerTextBaseline = 18.0;
const double _groupTitleInsetX = 8.0;
const double _groupTitleBaselineY = 16.0;
const double _groupInset = 8.0;
const double _doubleInsetMultiplier = 2.0;
const double _minUsableDimension = 2.0;
const int _opacityDecimalPlaces = 2;
const double _labelHorizontalPadding = 10.0;
const double _nameLabelBaseFontSize = 14.0;
const double _locLabelBaseFontSize = 11.0;
const double _minFittedFontSize = 6.0;
const double _twoLineNameDy = -6.0;
const double _twoLineLocDy = 14.0;
const String _foldersGroupId = '__folders_group__';
const double _folderNestedInset = 4.0;
const double _folderNestedHeaderHeight = 16.0;
const double _folderNestedMinWidth = 120.0;
const double _folderNestedMinHeight = 80.0;
const double _folderTileLabelMinWidth = 80.0;
const double _folderTileLabelMinHeight = 20.0;
const double _folderLabelInsetX = 6.0;
const double _folderLabelInsetY = 4.0;
const double _folderLabelBaseFontSize = 9.0;
const double _locOnlyLabelHorizontalPadding = 6.0;
const double _locOnlyLabelBaseFontSize = 10.0;
const double _folderDepthOpacityBase = 0.78;
const double _folderDepthOpacityStep = 0.08;
const double _folderDepthOpacityMin = 0.30;
const String _folderTileFillColor = '#8fa4ba';
const String _classesGroupId = '__classes_group__';
const double _classNestedInset = 4.0;
const double _classNestedHeaderHeight = 16.0;
const double _classNestedMinWidth = 120.0;
const double _classNestedMinHeight = 80.0;
const double _classTileLabelMinWidth = 80.0;
const double _classTileLabelMinHeight = 20.0;
const String _classTileFillColor = '#9eb89a';
const String _methodTileFillColor = '#2e8b57';
const String _globalFunctionsClassLabel = '<...>';
const String _innerTileDiagonalGradientId = 'codeSizeInnerTileDiagonalGradient';

/// Exports a code-size treemap as SVG.
///
/// The treemap is segmented into folders and classes.
String exportSvgCodeSize(
  List<CodeSizeArtifact> artifacts, {
  String title = 'Code Size',
  String? relativeTo,
}) {
  if (artifacts.isEmpty) {
    return generateEmptySvg('No code-size artifacts found');
  }
  final normalizedBase = (relativeTo == null || relativeTo.isEmpty)
      ? null
      : p.normalize(relativeTo);

  final fileItems = artifacts
      .where((a) => a.kind == CodeSizeArtifactKind.file)
      .map((artifact) => _rebaseArtifactPath(artifact, normalizedBase))
      .toList(growable: false);
  final classItems = artifacts
      .where((a) => a.kind == CodeSizeArtifactKind.classDeclaration)
      .map((artifact) => _rebaseArtifactPath(artifact, normalizedBase))
      .toList(growable: false);
  final callableItems = artifacts
      .where((a) => a.isCallable)
      .map((artifact) => _rebaseArtifactPath(artifact, normalizedBase))
      .toList(growable: false);
  final folderRoot = _buildFolderTree(fileItems);
  final folderTotalSize = folderRoot.totalSize;
  final classGroups = _buildClassGroups(classItems, callableItems);
  final classesTotalSize = classGroups.fold<int>(
    0,
    (sum, group) => sum + group.size,
  );

  if (classesTotalSize <= 0 && folderTotalSize <= 0) {
    return generateEmptySvg('No code-size artifacts found');
  }

  const width = 1600.0;
  const height = 980.0;
  const padding = 16.0;
  const headerHeight = 40.0;

  final contentRect = _Rect(
    x: padding,
    y: padding + headerHeight,
    width: width - (padding * _doubleInsetMultiplier),
    height: height - headerHeight - (padding * _doubleInsetMultiplier),
  );

  final groupRects = _layoutTreemap([
    if (folderTotalSize > 0)
      _WeightedNode(id: _foldersGroupId, weight: folderTotalSize),
    if (classesTotalSize > 0)
      _WeightedNode(id: _classesGroupId, weight: classesTotalSize),
  ], contentRect);

  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">',
    )
    ..writeln(SvgDefinitions.generateUnifiedDefs())
    ..writeln(
      '<defs><linearGradient id="$_innerTileDiagonalGradientId" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#ffffff" stop-opacity="0.38"/><stop offset="55%" stop-color="#ffffff" stop-opacity="0.08"/><stop offset="100%" stop-color="#000000" stop-opacity="0.12"/></linearGradient></defs>',
    )
    ..writeln('<rect width="100%" height="100%" fill="#fbfbfd"/>')
    ..writeln(
      '<text x="${padding + _headerTextInset}" y="${padding + _headerTextBaseline}" font-size="22" font-weight="700" fill="#222" filter="url(#outlineWhite)">${_xml(title)}</text>',
    )
    ..writeln(
      '<text x="${width - padding - _headerTextInset}" y="${padding + _headerTextBaseline}" text-anchor="end" font-size="13" fill="#666" filter="url(#outlineWhite)">Sized by non-empty LOC.</text>',
    );

  final foldersRect = groupRects[_foldersGroupId];
  if (foldersRect != null) {
    _renderFolderGroup(buffer, folderRoot, foldersRect);
  }

  final classesRect = groupRects[_classesGroupId];
  if (classesRect != null) {
    _renderClassesGroup(buffer, classGroups, classesRect);
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

class _ClassGroup {
  final String label;
  final String sourcePath;
  final int size;
  final List<CodeSizeArtifact> callables;

  const _ClassGroup({
    required this.label,
    required this.sourcePath,
    required this.size,
    required this.callables,
  });
}

class _WeightedNode {
  final String id;
  final int weight;

  _WeightedNode({required this.id, required this.weight});
}

class _Rect {
  final double x;
  final double y;
  final double width;
  final double height;

  const _Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class _FolderTreeNode {
  final String name;
  final String path;
  final Map<String, _FolderTreeNode> children = <String, _FolderTreeNode>{};
  final List<CodeSizeArtifact> files = <CodeSizeArtifact>[];

  _FolderTreeNode({required this.name, required this.path});

  /// Returns the sum of LOC for files directly inside this folder node.
  int get directFileSize =>
      files.fold<int>(0, (sum, file) => sum + file.linesOfCode);

  /// Returns recursive LOC for this folder including descendants.
  int get totalSize =>
      directFileSize +
      children.values.fold<int>(0, (sum, child) => sum + child.totalSize);

  /// Indicates whether this folder contains files or child folders.
  bool get hasEntries => files.isNotEmpty || children.isNotEmpty;
}

class _FolderEntry {
  final String id;
  final String label;
  final String path;
  final int size;
  final _FolderTreeNode? folder;

  const _FolderEntry.folder({
    required this.id,
    required this.label,
    required this.path,
    required this.size,
    required this.folder,
  });

  const _FolderEntry.file({
    required this.id,
    required this.label,
    required this.path,
    required this.size,
  }) : folder = null;

  /// Whether this entry represents a folder rather than a file.
  bool get isFolder => folder != null;
}

/// Renders the folder group as a recursive level-by-level treemap.
void _renderFolderGroup(StringBuffer buffer, _FolderTreeNode root, _Rect rect) {
  const groupInset = _groupInset;
  const groupHeaderHeight = 22.0;

  buffer.writeln(
    '<rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}" fill="#ffffff" stroke="#d9dce3" stroke-width="1.2"/>',
  );
  buffer.writeln(
    '<text x="${rect.x + _groupTitleInsetX}" y="${rect.y + _groupTitleBaselineY}" font-size="13" font-weight="700" fill="#111" filter="url(#outlineWhite)">Folders (${formatCount(root.totalSize)} LOC)</text>',
  );

  final usableRect = _Rect(
    x: rect.x + groupInset,
    y: rect.y + groupHeaderHeight,
    width: math.max(0, rect.width - (groupInset * _doubleInsetMultiplier)),
    height: math.max(0, rect.height - groupHeaderHeight - groupInset),
  );
  if (usableRect.width <= _minUsableDimension ||
      usableRect.height <= _minUsableDimension ||
      !root.hasEntries) {
    return;
  }

  _renderFolderLevel(buffer, node: root, rect: usableRect, depth: 0);
}

/// Renders one folder level by treemapping its direct files/subfolders.
void _renderFolderLevel(
  StringBuffer buffer, {
  required _FolderTreeNode node,
  required _Rect rect,
  required int depth,
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
    final fillColor = entry.isFolder ? _folderTileFillColor : '#1f6f8b';
    final escapedLabel = _xml(entry.label);
    final escapedPath = _xml(entry.path);

    buffer.writeln('<g>');
    buffer.writeln(
      '  <rect x="${entryRect.x}" y="${entryRect.y}" width="${entryRect.width}" height="${entryRect.height}" fill="$fillColor" fill-opacity="$fillOpacity"/>',
    );
    _renderInnerTileGradientOverlay(buffer, entryRect);
    buffer.writeln(
      '  <title>${entry.isFolder ? "folder" : "file"}: $escapedLabel | ${formatCount(entry.size)} LOC | $escapedPath</title>',
    );

    if (entryRect.width >= _folderTileLabelMinWidth &&
        entryRect.height >= _folderTileLabelMinHeight) {
      if (entry.isFolder) {
        _renderFolderTopLeftLabel(
          buffer,
          rect: entryRect,
          label: escapedLabel,
          size: entry.size,
        );
      } else {
        _renderTileLabel(
          buffer,
          rect: entryRect,
          label: escapedLabel,
          size: entry.size,
        );
      }
    } else {
      _renderLocOnlyLabel(buffer, rect: entryRect, size: entry.size);
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
        );
      }
    }
    buffer.writeln('</g>');
  }
}

/// Renders class containers and nested callables.
void _renderClassesGroup(
  StringBuffer buffer,
  List<_ClassGroup> classGroups,
  _Rect rect,
) {
  const groupInset = _groupInset;
  const groupHeaderHeight = 22.0;
  final totalSize = classGroups.fold<int>(0, (sum, group) => sum + group.size);

  buffer.writeln(
    '<rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}" fill="#ffffff" stroke="#d9dce3" stroke-width="1.2"/>',
  );
  buffer.writeln(
    '<text x="${rect.x + _groupTitleInsetX}" y="${rect.y + _groupTitleBaselineY}" font-size="13" font-weight="700" fill="#111" filter="url(#outlineWhite)">Classes (${formatCount(totalSize)} LOC)</text>',
  );

  final usableRect = _Rect(
    x: rect.x + groupInset,
    y: rect.y + groupHeaderHeight,
    width: math.max(0, rect.width - (groupInset * _doubleInsetMultiplier)),
    height: math.max(0, rect.height - groupHeaderHeight - groupInset),
  );
  if (usableRect.width <= _minUsableDimension ||
      usableRect.height <= _minUsableDimension ||
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
    usableRect,
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
    buffer.writeln(
      '  <title>class: ${_xml(classGroup.label)} | ${formatCount(classGroup.size)} LOC | ${_xml(classGroup.sourcePath)}</title>',
    );
    if (classRect.width >= _classTileLabelMinWidth &&
        classRect.height >= _classTileLabelMinHeight) {
      _renderFolderTopLeftLabel(
        buffer,
        rect: classRect,
        label: _xml(classGroup.label),
        size: classGroup.size,
      );
    } else {
      _renderLocOnlyLabel(buffer, rect: classRect, size: classGroup.size);
    }

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

          final callableName = _xml(callable.name);
          final callablePath = _xml(callable.filePath);
          buffer.writeln('<g>');
          buffer.writeln(
            '  <rect x="${callableRect.x}" y="${callableRect.y}" width="${callableRect.width}" height="${callableRect.height}" fill="$_methodTileFillColor" fill-opacity="0.72"/>',
          );
          _renderInnerTileGradientOverlay(buffer, callableRect);
          buffer.writeln(
            '  <title>callable: $callableName | ${formatCount(callable.linesOfCode)} LOC | $callablePath${callable.startLine > 0 ? ':${callable.startLine}' : ''}</title>',
          );
          if (callableRect.width >= _folderTileLabelMinWidth &&
              callableRect.height >= _folderTileLabelMinHeight) {
            _renderTileLabel(
              buffer,
              rect: callableRect,
              label: callableName,
              size: callable.linesOfCode,
            );
          } else {
            _renderLocOnlyLabel(
              buffer,
              rect: callableRect,
              size: callable.linesOfCode,
            );
          }
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
  final folderLabel = '$label (${formatCount(size)} LOC)';
  final x = rect.x + _folderLabelInsetX;
  final y = rect.y + _folderLabelInsetY + _folderLabelBaseFontSize;
  final maxWidth = rect.width - (_folderLabelInsetX * _doubleInsetMultiplier);
  final labelFontSize = fitTextFontSize(
    folderLabel,
    maxWidth: maxWidth,
    baseFontSize: _folderLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );
  buffer.writeln(
    '  <text x="$x" y="$y" text-anchor="start" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" filter="url(#outlineWhite)" font-weight="700">$folderLabel</text>',
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
  final locFontSize = fitTextFontSize(
    locLabel,
    maxWidth: rect.width - _labelHorizontalPadding,
    baseFontSize: _locLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );

  buffer.writeln(
    '  <text x="$centerX" y="$centerY" text-anchor="middle" dominant-baseline="middle" fill="#000" filter="url(#outlineWhite)" font-weight="700">',
  );
  buffer.writeln(
    '    <tspan x="$centerX" dy="$_twoLineNameDy" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}">$label</tspan>',
  );
  buffer.writeln(
    '    <tspan x="$centerX" dy="$_twoLineLocDy" font-size="${locFontSize.toStringAsFixed(_opacityDecimalPlaces)}">$locLabel</tspan>',
  );
  buffer.writeln('  </text>');
}

/// Renders centered LOC-only text for tiles where full labels do not fit.
void _renderLocOnlyLabel(
  StringBuffer buffer, {
  required _Rect rect,
  required int size,
}) {
  final centerX = rect.x + (rect.width / _binarySplitHalfRatio);
  final centerY = rect.y + (rect.height / _binarySplitHalfRatio);
  final locLabel = formatCount(size);
  final locFontSize = fitTextFontSize(
    locLabel,
    maxWidth: rect.width - _locOnlyLabelHorizontalPadding,
    baseFontSize: _locOnlyLabelBaseFontSize,
    minFontSize: _minFittedFontSize,
  );

  buffer.writeln(
    '  <text x="$centerX" y="$centerY" text-anchor="middle" dominant-baseline="middle" font-size="${locFontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" filter="url(#outlineWhite)" font-weight="700">$locLabel</text>',
  );
}

/// Adds diagonal light-to-shadow texture for inner tiles.
void _renderInnerTileGradientOverlay(StringBuffer buffer, _Rect rect) {
  buffer.writeln(
    '  <rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}" fill="url(#$_innerTileDiagonalGradientId)"/>',
  );
}

/// Returns direct folder/file entries sorted by descending LOC.
List<_FolderEntry> _folderEntriesForNode(_FolderTreeNode node) {
  final entries = <_FolderEntry>[
    for (final child in node.children.values)
      _FolderEntry.folder(
        id: 'folder:${child.path}',
        label: child.name,
        path: child.path,
        size: child.totalSize,
        folder: child,
      ),
    for (final file in node.files)
      _FolderEntry.file(
        id: 'file:${file.stableId}',
        label: p.basename(file.filePath),
        path: file.filePath,
        size: file.linesOfCode,
      ),
  ];
  entries.sort((left, right) => right.size.compareTo(left.size));
  return entries;
}

/// Builds class groups and maps global functions to a synthetic class `<...>`.
List<_ClassGroup> _buildClassGroups(
  List<CodeSizeArtifact> classItems,
  List<CodeSizeArtifact> callableItems,
) {
  final methodsByOwner = <String, List<CodeSizeArtifact>>{};
  final globals = <CodeSizeArtifact>[];
  for (final callable in callableItems) {
    if (callable.kind == CodeSizeArtifactKind.function &&
        (callable.ownerName == null || callable.ownerName!.isEmpty)) {
      globals.add(callable);
      continue;
    }
    final owner = callable.ownerName;
    if (owner == null || owner.isEmpty) {
      globals.add(callable);
      continue;
    }
    methodsByOwner.putIfAbsent(owner, () => <CodeSizeArtifact>[]).add(callable);
  }

  final groups = <_ClassGroup>[];
  final declaredClassNames = <String>{};
  for (final classArtifact in classItems) {
    final className = classArtifact.name;
    declaredClassNames.add(className);
    final methods = methodsByOwner[className] ?? const <CodeSizeArtifact>[];
    final methodsSize = methods.fold<int>(
      0,
      (sum, method) => sum + method.linesOfCode,
    );
    final size = math.max(classArtifact.linesOfCode, methodsSize);
    groups.add(
      _ClassGroup(
        label: className,
        sourcePath: classArtifact.filePath,
        size: size,
        callables: methods,
      ),
    );
  }

  for (final entry in methodsByOwner.entries) {
    if (declaredClassNames.contains(entry.key)) {
      continue;
    }
    final methodsSize = entry.value.fold<int>(
      0,
      (sum, method) => sum + method.linesOfCode,
    );
    groups.add(
      _ClassGroup(
        label: entry.key,
        sourcePath: entry.value.first.filePath,
        size: methodsSize,
        callables: entry.value,
      ),
    );
  }

  if (globals.isNotEmpty) {
    final globalSize = globals.fold<int>(
      0,
      (sum, function) => sum + function.linesOfCode,
    );
    groups.add(
      _ClassGroup(
        label: _globalFunctionsClassLabel,
        sourcePath: '.',
        size: globalSize,
        callables: globals,
      ),
    );
  }

  groups.sort((left, right) => right.size.compareTo(left.size));
  return groups;
}

/// Builds a folder tree from file artifacts.
///
/// Files are stored at their direct folder node and folder totals are derived
/// recursively from children + local files.
_FolderTreeNode _buildFolderTree(List<CodeSizeArtifact> fileItems) {
  final root = _FolderTreeNode(name: '.', path: '.');
  for (final file in fileItems) {
    final directory = p.normalize(p.dirname(file.filePath));
    final segments = directory == '.' || directory.isEmpty
        ? const <String>[]
        : p.split(directory).where((segment) => segment.isNotEmpty).toList();
    var current = root;
    for (final segment in segments) {
      final childPath = current.path == '.'
          ? segment
          : p.join(current.path, segment);
      current = current.children.putIfAbsent(
        segment,
        () => _FolderTreeNode(name: segment, path: childPath),
      );
    }
    current.files.add(file);
  }
  return root;
}

/// Converts absolute artifact paths to project-relative paths when [base]
/// is provided.
///
/// Relative input paths are preserved unchanged.
CodeSizeArtifact _rebaseArtifactPath(CodeSizeArtifact artifact, String? base) {
  if (base == null) {
    return artifact;
  }
  final filePath = artifact.filePath;
  final normalizedPath = p.normalize(filePath);
  if (!p.isAbsolute(normalizedPath)) {
    return artifact;
  }

  final relativePath = p.relative(normalizedPath, from: base);
  return CodeSizeArtifact(
    kind: artifact.kind,
    name: artifact.name,
    filePath: relativePath,
    linesOfCode: artifact.linesOfCode,
    startLine: artifact.startLine,
    endLine: artifact.endLine,
    ownerName: artifact.ownerName,
  );
}

/// Produces a binary treemap layout for [nodes] within [bounds].
///
/// Nodes are sorted by descending weight and recursively partitioned.
Map<String, _Rect> _layoutTreemap(List<_WeightedNode> nodes, _Rect bounds) {
  if (nodes.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const <String, _Rect>{};
  }

  final normalized =
      nodes.where((node) => node.weight > 0).toList(growable: false)
        ..sort((a, b) => b.weight.compareTo(a.weight));
  if (normalized.isEmpty) {
    return const <String, _Rect>{};
  }

  final output = <String, _Rect>{};
  _binaryTreemap(normalized, bounds, output);
  return output;
}

/// Recursively assigns rectangles to [nodes] using weighted binary splits.
///
/// The larger side of [rect] is chosen as split axis to keep rectangles less
/// skewed and improve label readability.
void _binaryTreemap(
  List<_WeightedNode> nodes,
  _Rect rect,
  Map<String, _Rect> output,
) {
  if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) {
    return;
  }
  if (nodes.length == 1) {
    output[nodes.first.id] = rect;
    return;
  }

  final total = nodes.fold<int>(0, (sum, node) => sum + node.weight);
  if (total <= 0) {
    return;
  }

  final half = total / _binarySplitHalfRatio;
  var prefix = 0;
  var splitIndex = 1;
  for (var i = 0; i < nodes.length - 1; i++) {
    prefix += nodes[i].weight;
    splitIndex = i + 1;
    if (prefix >= half) {
      break;
    }
  }

  final left = nodes.sublist(0, splitIndex);
  final right = nodes.sublist(splitIndex);
  final leftWeight = left.fold<int>(0, (sum, node) => sum + node.weight);
  final ratio = (leftWeight / total).clamp(0.0, 1.0);

  if (rect.width >= rect.height) {
    final splitWidth = rect.width * ratio;
    _binaryTreemap(
      left,
      _Rect(x: rect.x, y: rect.y, width: splitWidth, height: rect.height),
      output,
    );
    _binaryTreemap(
      right,
      _Rect(
        x: rect.x + splitWidth,
        y: rect.y,
        width: rect.width - splitWidth,
        height: rect.height,
      ),
      output,
    );
    return;
  }

  final splitHeight = rect.height * ratio;
  _binaryTreemap(
    left,
    _Rect(x: rect.x, y: rect.y, width: rect.width, height: splitHeight),
    output,
  );
  _binaryTreemap(
    right,
    _Rect(
      x: rect.x,
      y: rect.y + splitHeight,
      width: rect.width,
      height: rect.height - splitHeight,
    ),
    output,
  );
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
