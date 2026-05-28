part of 'export_svg_package_dependencies.dart';

String _sdkMetadataLabel(String sdkName, String constraint) =>
    '$sdkName $constraint';

double _platformMetadataPillWidthForLabel(String label) =>
    (label.length * _platformMetadataPillWidthPerCharacter) +
    (_platformMetadataPillHorizontalPadding *
        _platformMetadataPillPaddingSideCount);

/// Renders centered SDK metadata pills for package nodes and the root header.
void _writeMetadataPills(
  StringBuffer buffer, {
  required double centerX,
  required double topY,
  required List<String> labels,
  bool highlightCaptions = false,
}) {
  if (labels.isEmpty) {
    return;
  }

  final pillWidths = labels
      .map(_platformMetadataPillWidthForLabel)
      .toList(growable: false);
  final totalWidth =
      pillWidths.fold<double>(0, (sum, width) => sum + width) +
      ((labels.length - 1) * _platformMetadataPillGap);
  final labelClass = _buildPackageLabelClasses(
    _packageMetadataLabelClass,
    warning: highlightCaptions,
  );
  var currentX = centerX - (totalWidth / _halfDivisor);

  for (var index = 0; index < labels.length; index++) {
    final label = labels[index];
    final pillWidth = pillWidths[index];
    final pillCenterX = currentX + (pillWidth / _halfDivisor);
    final pillCenterY = (topY + (_platformMetadataPillHeight / _halfDivisor))
        .ceil();
    buffer.writeln(
      '<g class="$_packageMetadataPillGroupClass"><title>${escapeXml(label)}</title><rect x="$currentX" y="$topY" width="$pillWidth" height="$_platformMetadataPillHeight" rx="$_platformMetadataPillCornerRadius" ry="$_platformMetadataPillCornerRadius" class="$_packageMetadataPillShapeClass"/><text x="$pillCenterX" y="$pillCenterY" class="$labelClass" text-anchor="middle" dominant-baseline="middle">${escapeXml(label)}</text></g>',
    );
    currentX += pillWidth + _platformMetadataPillGap;
  }
}
