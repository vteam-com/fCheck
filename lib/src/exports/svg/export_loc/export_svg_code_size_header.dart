part of 'export_svg_code_size.dart';

/// Renders the top SVG header line with project title, total LOC, and
/// domain chips for folders/files/classes/functions counts.
void _renderHeaderTitleLine(
  StringBuffer buffer, {
  required double x,
  required double y,
  required double rightX,
  required String title,
  required int totalLoc,
  required int folderCount,
  required int fileCount,
  required int classCount,
  required int functionCount,
  required bool hasWarningArtifacts,
  required bool hasErrorArtifacts,
  required int warningArtifactCount,
  required int errorArtifactCount,
}) {
  var cursorX = x;

  final titleText = escapeXml(title);
  final titleY = y;
  buffer.writeln(
    '<text x="$cursorX" y="$titleY" font-size="$_headerTitleFontSize" font-weight="700" fill="#222">$titleText</text>',
  );
  cursorX +=
      _estimateLegendTextWidth(title, _headerTitleFontSize) +
      _headerTitleGapAfterText;

  final metaText = '${formatCount(totalLoc)} LOC';
  buffer.writeln(
    '<text x="$cursorX" y="$titleY" font-size="$_headerMetaFontSize" font-weight="700" fill="#222">$metaText</text>',
  );
  cursorX +=
      _estimateLegendTextWidth(metaText, _headerMetaFontSize) +
      _headerMetaGapAfterText;

  cursorX = _renderHeaderChip(
    buffer,
    x: cursorX,
    y: y - _headerChipHeight + _headerChipYAdjustment,
    text: '${formatCount(folderCount)} Folders',
    fillColor: _folderTileFillColor,
    cornerRadius: 0.0,
  );
  cursorX = _renderHeaderSeparator(buffer, x: cursorX, y: y);
  cursorX = _renderHeaderChip(
    buffer,
    x: cursorX,
    y: y - _headerChipHeight + _headerChipYAdjustment,
    text: '${formatCount(fileCount)} Files',
    fillColor: _fileTileFillColor,
    cornerRadius: _headerChipRoundedRadius,
  );
  cursorX = _renderHeaderSeparator(buffer, x: cursorX, y: y);
  cursorX = _renderHeaderChip(
    buffer,
    x: cursorX,
    y: y - _headerChipHeight + _headerChipYAdjustment,
    text: '${formatCount(classCount)} Classes',
    fillColor: _classTileFillColor,
    cornerRadius: 0.0,
  );
  cursorX = _renderHeaderSeparator(buffer, x: cursorX, y: y);
  _renderHeaderChip(
    buffer,
    x: cursorX,
    y: y - _headerChipHeight + _headerChipYAdjustment,
    text: '${formatCount(functionCount)} Functions/Methods',
    fillColor: _methodTileFillColor,
    cornerRadius: _headerChipRoundedRadius,
  );

  if (hasWarningArtifacts || hasErrorArtifacts) {
    _renderRightAlignedSeverityChips(
      buffer,
      y: y - _headerChipHeight + _headerChipYAdjustment,
      rightX: rightX,
      hasWarningArtifacts: hasWarningArtifacts,
      hasErrorArtifacts: hasErrorArtifacts,
      warningArtifactCount: warningArtifactCount,
      errorArtifactCount: errorArtifactCount,
    );
  }
}

void _renderRightAlignedSeverityChips(
  StringBuffer buffer, {
  required double y,
  required double rightX,
  required bool hasWarningArtifacts,
  required bool hasErrorArtifacts,
  required int warningArtifactCount,
  required int errorArtifactCount,
}) {
  final chips = <({String text, String fillColor})>[
    if (hasWarningArtifacts)
      (
        text:
            '${formatCount(warningArtifactCount)} ${warningArtifactCount == 1 ? 'Warning' : 'Warnings'}',
        fillColor: _warningTintFillColor,
      ),
    if (hasErrorArtifacts)
      (
        text:
            '${formatCount(errorArtifactCount)} ${errorArtifactCount == 1 ? 'Error' : 'Errors'}',
        fillColor: _hardErrorTintFillColor,
      ),
  ];
  if (chips.isEmpty) {
    return;
  }

  final widths = chips
      .map(
        (chip) =>
            _estimateLegendTextWidth(chip.text, _headerChipFontSize) +
            (_headerChipTextInsetX * _headerChipHorizontalInsetMultiplier),
      )
      .toList(growable: false);
  final totalWidth =
      widths.fold<double>(0, (sum, width) => sum + width) +
      (_headerChipGap * (chips.length - 1));
  var cursorX = rightX - totalWidth;

  for (var i = 0; i < chips.length; i++) {
    final chip = chips[i];
    final width = widths[i];
    final textY =
        y +
        (_headerChipHeight / _headerChipVerticalCenterDivisor) +
        (_headerChipFontSize / _headerChipBaselineDivisor);
    final textX = cursorX + _headerChipTextInsetX;
    buffer.writeln(
      '<rect x="$cursorX" y="$y" width="$width" height="$_headerChipHeight"${_cornerRadiusAttributes(_headerChipRoundedRadius)} fill="${chip.fillColor}" fill-opacity="0.85"/>',
    );
    buffer.writeln(
      '<text x="$textX" y="$textY" font-size="$_headerChipFontSize" font-weight="700" fill="#fff">${escapeXml(chip.text)}</text>',
    );
    cursorX += width + _headerChipGap;
  }
}

double _renderHeaderSeparator(
  StringBuffer buffer, {
  required double x,
  required double y,
}) {
  buffer.writeln(
    '<text x="$x" y="$y" font-size="$_headerMetaFontSize" font-weight="700" fill="#666">&gt;</text>',
  );
  return x + _headerSeparatorAdvanceX;
}

/// Renders one colored count chip and returns the next horizontal cursor
/// position after the chip plus standard spacing.
double _renderHeaderChip(
  StringBuffer buffer, {
  required double x,
  required double y,
  required String text,
  required String fillColor,
  required double cornerRadius,
}) {
  final width =
      _estimateLegendTextWidth(text, _headerChipFontSize) +
      (_headerChipTextInsetX * _headerChipHorizontalInsetMultiplier);
  final textY =
      y +
      (_headerChipHeight / _headerChipVerticalCenterDivisor) +
      (_headerChipFontSize / _headerChipBaselineDivisor);
  final textX = x + _headerChipTextInsetX;
  buffer.writeln(
    '<rect x="$x" y="$y" width="$width" height="$_headerChipHeight"${_cornerRadiusAttributes(cornerRadius)} fill="$fillColor" fill-opacity="0.85"/>',
  );
  buffer.writeln(
    '<text x="$textX" y="$textY" font-size="$_headerChipFontSize" font-weight="700" fill="#fff">${escapeXml(text)}</text>',
  );
  return x + width + _headerChipGap;
}

double _estimateLegendTextWidth(String text, double fontSize) {
  return text.length * fontSize * _legendTextWidthFactor;
}
