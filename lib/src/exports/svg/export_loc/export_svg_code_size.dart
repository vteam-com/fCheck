import 'dart:math' as math;

import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:path/path.dart' as p;

part 'export_svg_code_size_models.dart';
part 'export_svg_code_size_header.dart';
part 'export_svg_code_size_render.dart';
part 'export_svg_code_size_builders.dart';
part 'export_svg_code_size_treemap.dart';

const double _binarySplitHalfRatio = 2.0;
const double _headerTextInset = 2.0;
const double _headerTextBaseline = 18.0;
const double _headerChipHeight = 20.0;
const double _headerChipTextInsetX = 8.0;
const double _headerChipGap = 8.0;
const double _headerTitleFontSize = 20.0;
const double _headerMetaFontSize = 18.0;
const double _headerChipFontSize = 14.0;
const double _headerTitleGapAfterText = 18.0;
const double _headerMetaGapAfterText = 16.0;
const double _headerChipYAdjustment = 3.0;
const double _headerChipRoundedRadius = 5.0;
const double _headerSeparatorAdvanceX = 16.0;
const double _headerChipHorizontalInsetMultiplier = 2.0;
const double _headerChipVerticalCenterDivisor = 2.0;
const double _headerChipBaselineDivisor = 2.8;
const double _legendTextWidthFactor = 0.62;
const String _fileTileFillColor = '#1f6f8b';
const double _doubleInsetMultiplier = 2.0;
const double _minUsableDimension = 2.0;
const int _opacityDecimalPlaces = 2;
const double _labelHorizontalPadding = 10.0;
const double _nameLabelBaseFontSize = 14.0;
const double _minFittedFontSize = 3.0;
const double _twoLineNameDy = -6.0;
const double _twoLineLocDy = 14.0;
const double _folderNestedInset = 4.0;
const double _folderNestedHeaderHeight = 16.0;
const double _folderNestedMinWidth = 1.0;
const double _folderNestedMinHeight = 1.0;
const double _folderLabelInsetX = 6.0;
const double _folderLabelInsetY = 4.0;
const double _folderLabelBaseFontSize = 9.0;
const double _folderLabelGap = 8.0;
const double _folderLabelLocWidthRatio = 0.45;
const double _folderDepthOpacityBase = 0.78;
const double _folderDepthOpacityStep = 0.08;
const double _folderDepthOpacityMin = 0.30;
const String _folderTileFillColor = '#8fa4ba';
const double _classNestedInset = 4.0;
const double _classNestedHeaderHeight = 16.0;
const double _classNestedMinWidth = 1.0;
const double _classNestedMinHeight = 1.0;
const String _classTileFillColor = '#9eb89a';
const String _methodTileFillColor = '#2e8b57';
const String _globalFunctionsClassLabel = '<...>';
const String _innerTileDiagonalGradientId = 'codeSizeInnerTileDiagonalGradient';
const double _innerTileCornerRadius = 5.0;
const String _tileBorderColor = '#ffffff';
const double _tileBorderOpacity = 0.45;
const double _tileBorderWidth = 0.8;

/// Exports a code-size treemap as SVG.
///
/// The treemap hierarchy is folders -> files -> classes -> functions/methods.
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
  final rawCallableItems = artifacts
      .where((a) => a.isCallable)
      .map((artifact) => _rebaseArtifactPath(artifact, normalizedBase))
      .toList(growable: false);
  final fileLocByPath = <String, int>{
    for (final file in fileItems) file.filePath: file.linesOfCode,
  };
  final callableItems = _filterNestedCallables(rawCallableItems);
  final classGroupsByFile = _buildClassGroupsByFile(
    classItems,
    callableItems,
    fileLocByPath: fileLocByPath,
  );
  final rolledUpFileItems = _buildRolledUpFileItems(
    fileItems,
    classGroupsByFile,
  );
  final folderRoot = _buildFolderTree(rolledUpFileItems);
  final folderTotalSize = folderRoot.totalSize;
  final folderCount = _countFolders(folderRoot);
  final rolledClassCount = classGroupsByFile.values.fold<int>(
    0,
    (sum, groups) => sum + groups.length,
  );
  final rolledCallableCount = classGroupsByFile.values.fold<int>(
    0,
    (sum, groups) =>
        sum +
        groups.fold<int>(0, (inner, group) => inner + group.callables.length),
  );

  if (folderTotalSize <= 0) {
    return generateEmptySvg('No code-size artifacts found');
  }

  const width = 3200.0;
  const height = 1960.0;
  const padding = 16.0;
  const headerHeight = 40.0;

  final contentRect = _Rect(
    x: padding,
    y: padding + headerHeight,
    width: width - (padding * _doubleInsetMultiplier),
    height: height - headerHeight - (padding * _doubleInsetMultiplier),
  );

  final buffer = StringBuffer();
  writeSvgDocumentStart(
    buffer,
    width: width,
    height: height,
    leadingBlocks: const [
      '<defs><linearGradient xmlns="http://www.w3.org/2000/svg" id="$_innerTileDiagonalGradientId" x1="20%" y1="0%" x2="80%" y2="100%"><stop offset="0%" stop-color="#ffffff" stop-opacity="0.5"/><stop offset="50%" stop-color="#ffffff" stop-opacity="0.1"/><stop offset="100%" stop-color="#aaa" stop-opacity="0.1"/></linearGradient></defs>',
    ],
    backgroundFill: '#fbfbfd',
  );
  _renderHeaderTitleLine(
    buffer,
    x: padding + _headerTextInset,
    y: padding + _headerTextBaseline,
    title: title,
    totalLoc: folderTotalSize,
    folderCount: folderCount,
    fileCount: rolledUpFileItems.length,
    classCount: rolledClassCount,
    functionCount: rolledCallableCount,
  );

  _renderFolderGroup(
    buffer,
    folderRoot,
    contentRect,
    classGroupsByFile: classGroupsByFile,
  );

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}
