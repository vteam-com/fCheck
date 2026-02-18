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
const double _shadeClampMin = 0.15;
const double _shadeClampMax = 1.0;
const double _fillOpacityBase = 0.25;
const double _fillOpacityScale = 0.55;
const int _opacityDecimalPlaces = 2;
const double _labelHorizontalPadding = 10.0;
const double _nameLabelBaseFontSize = 14.0;
const double _locLabelBaseFontSize = 11.0;
const double _minFittedFontSize = 6.0;
const double _twoLineLabelMinHeight = 36.0;
const double _twoLineNameDy = -6.0;
const double _twoLineLocDy = 14.0;

/// Exports a code-size treemap as SVG.
///
/// The treemap is segmented into:
/// - Files
/// - Classes
/// - Functions + Methods
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
  final folderItems = _buildFolderItems(fileItems);

  final groups = <_GroupNode>[
    _GroupNode('Folders', folderItems, '#5d6d7e', itemTypeLabel: 'folder'),
    _GroupNode('Files', fileItems, '#1f6f8b', itemTypeLabel: 'file'),
    _GroupNode('Classes', classItems, '#2e8b57', itemTypeLabel: 'class'),
    _GroupNode(
      'Functions/Methods',
      callableItems,
      '#c97a00',
      itemTypeLabel: 'callable',
    ),
  ].where((group) => group.totalSize > 0).toList(growable: false);

  if (groups.isEmpty) {
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

  final groupRects = _layoutTreemap(
    groups.map((g) => _WeightedNode(id: g.label, weight: g.totalSize)).toList(),
    contentRect,
  );

  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">',
    )
    ..writeln(SvgDefinitions.generateUnifiedDefs())
    ..writeln('<rect width="100%" height="100%" fill="#fbfbfd"/>')
    ..writeln(
      '<text x="${padding + _headerTextInset}" y="${padding + _headerTextBaseline}" font-size="22" font-weight="700" fill="#222" filter="url(#outlineWhite)">${_xml(title)}</text>',
    )
    ..writeln(
      '<text x="${width - padding - _headerTextInset}" y="${padding + _headerTextBaseline}" text-anchor="end" font-size="13" fill="#666" filter="url(#outlineWhite)">Sized by non-empty LOC.</text>',
    );

  for (final group in groups) {
    final groupRect = groupRects[group.label];
    if (groupRect == null) {
      continue;
    }
    _renderGroup(buffer, group, groupRect);
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

class _GroupNode {
  final String label;
  final List<CodeSizeArtifact> artifacts;
  final String baseColor;
  final String itemTypeLabel;

  _GroupNode(
    this.label,
    this.artifacts,
    this.baseColor, {
    required this.itemTypeLabel,
  });

  /// Total LOC represented by this group across all child artifacts.
  int get totalSize =>
      artifacts.fold<int>(0, (sum, artifact) => sum + artifact.linesOfCode);
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

/// Renders one top-level group box and its nested artifact rectangles.
///
/// Group content is rendered as a secondary treemap using the already
/// normalized artifact LOC values.
void _renderGroup(StringBuffer buffer, _GroupNode group, _Rect rect) {
  const groupInset = _groupInset;
  const groupHeaderHeight = 22.0;
  const itemLabelMinWidth = 90.0;
  const itemLabelMinHeight = 22.0;

  buffer.writeln(
    '<rect x="${rect.x}" y="${rect.y}" width="${rect.width}" height="${rect.height}" fill="#ffffff" stroke="#d9dce3" stroke-width="1.2"/>',
  );
  buffer.writeln(
    '<text x="${rect.x + _groupTitleInsetX}" y="${rect.y + _groupTitleBaselineY}" font-size="13" font-weight="700" fill="#111" filter="url(#outlineWhite)">${_xml(group.label)} (${formatCount(group.totalSize)} LOC)</text>',
  );

  final items = List<CodeSizeArtifact>.from(group.artifacts)
    ..sort((a, b) => b.linesOfCode.compareTo(a.linesOfCode));

  final usableRect = _Rect(
    x: rect.x + groupInset,
    y: rect.y + groupHeaderHeight,
    width: math.max(0, rect.width - (groupInset * _doubleInsetMultiplier)),
    height: math.max(0, rect.height - groupHeaderHeight - groupInset),
  );

  if (usableRect.width <= _minUsableDimension ||
      usableRect.height <= _minUsableDimension ||
      items.isEmpty) {
    return;
  }

  final nodeRects = _layoutTreemap(
    items
        .map(
          (item) => _WeightedNode(
            id: item.stableId,
            weight: math.max(1, item.linesOfCode),
          ),
        )
        .toList(),
    usableRect,
  );

  final maxSize = items.first.linesOfCode <= 0 ? 1 : items.first.linesOfCode;
  for (final item in items) {
    final itemRect = nodeRects[item.stableId];
    if (itemRect == null ||
        itemRect.width < _minUsableDimension ||
        itemRect.height < _minUsableDimension) {
      continue;
    }
    final shadeFactor = (item.linesOfCode / maxSize).clamp(
      _shadeClampMin,
      _shadeClampMax,
    );
    final fillOpacity = (_fillOpacityBase + (shadeFactor * _fillOpacityScale))
        .toStringAsFixed(_opacityDecimalPlaces);
    final escapedLabel = _xml(item.qualifiedName);
    final escapedPath = _xml(item.filePath);

    buffer.writeln('<g>');
    buffer.writeln(
      '  <rect x="${itemRect.x}" y="${itemRect.y}" width="${itemRect.width}" height="${itemRect.height}" fill="${group.baseColor}" fill-opacity="$fillOpacity" stroke="#ffffff" stroke-width="1"/>',
    );
    buffer.writeln(
      '  <title>${group.itemTypeLabel}: $escapedLabel | ${formatCount(item.linesOfCode)} LOC | $escapedPath${item.startLine > 0 ? ':${item.startLine}' : ''}</title>',
    );
    if (itemRect.width >= itemLabelMinWidth &&
        itemRect.height >= itemLabelMinHeight) {
      final centerX = itemRect.x + (itemRect.width / _binarySplitHalfRatio);
      final centerY = itemRect.y + (itemRect.height / _binarySplitHalfRatio);
      final labelFontSize = fitTextFontSize(
        item.qualifiedName,
        maxWidth: itemRect.width - _labelHorizontalPadding,
        baseFontSize: _nameLabelBaseFontSize,
        minFontSize: _minFittedFontSize,
      );
      final locLabel = '${formatCount(item.linesOfCode)} LOC';
      final locFontSize = fitTextFontSize(
        locLabel,
        maxWidth: itemRect.width - _labelHorizontalPadding,
        baseFontSize: _locLabelBaseFontSize,
        minFontSize: _minFittedFontSize,
      );
      if (itemRect.height >= _twoLineLabelMinHeight) {
        buffer.writeln(
          '  <text x="$centerX" y="$centerY" text-anchor="middle" dominant-baseline="middle" fill="#000" filter="url(#outlineWhite)" font-weight="700">',
        );
        buffer.writeln(
          '    <tspan x="$centerX" dy="$_twoLineNameDy" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}" font-weight="700">$escapedLabel</tspan>',
        );
        buffer.writeln(
          '    <tspan x="$centerX" dy="$_twoLineLocDy" font-size="${locFontSize.toStringAsFixed(_opacityDecimalPlaces)}" font-weight="700">$locLabel</tspan>',
        );
        buffer.writeln('  </text>');
      } else {
        buffer.writeln(
          '  <text x="$centerX" y="$centerY" text-anchor="middle" dominant-baseline="middle" font-size="${labelFontSize.toStringAsFixed(_opacityDecimalPlaces)}" fill="#000" filter="url(#outlineWhite)" font-weight="700">$escapedLabel</text>',
        );
      }
    }
    buffer.writeln('</g>');
  }
}

/// Aggregates file artifacts by folder path and returns synthetic folder nodes.
///
/// Folder artifacts reuse the shared data model so they can be laid out and
/// rendered by the same pipeline as file/class/function artifacts.
List<CodeSizeArtifact> _buildFolderItems(List<CodeSizeArtifact> fileItems) {
  final byFolder = <String, int>{};
  for (final file in fileItems) {
    final folderPath = p.dirname(file.filePath);
    final normalizedFolder = (folderPath.isEmpty || folderPath == '.')
        ? '.'
        : p.normalize(folderPath);
    byFolder[normalizedFolder] =
        (byFolder[normalizedFolder] ?? 0) + file.linesOfCode;
  }

  return byFolder.entries
      .map(
        (entry) => CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: entry.key,
          filePath: entry.key,
          linesOfCode: entry.value,
          startLine: 0,
          endLine: 0,
        ),
      )
      .toList(growable: false);
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
