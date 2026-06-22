part of 'export_svg_package_dependencies.dart';

const double _platformBadgeMinimumWidth = 13;
const int _platformBadgeBaseLabelLength = 1;
const double _platformBadgeWidthPerExtraCharacter = 5;
const double _platformBadgeHeight = 13;
const double _platformBadgeGap = 4;
const double _platformBadgeCornerRadius = 6.5;
const double _platformBadgeFontSize = 7;
const double _platformBadgeStrokeWidth = 0.6;
const double _platformBadgeSingleLetterLabelYOffset = 1;
const double _platformMetadataGap = 3;
const double _platformMetadataFontSize = 7;
const double _platformMetadataBottomInset = 4;
const double _platformMetadataPillHeight = 9;
const double _platformMetadataPillGap = 6;
const double _platformMetadataPillHorizontalPadding = 6;
const double _platformMetadataPillCornerRadius = 4.5;
const double _platformMetadataPillStrokeWidth = 0.8;
const double _platformMetadataPillWidthPerCharacter = 4.1;
const double _platformMetadataPillPaddingSideCount = 2;

const String _platformBadgeTextColor = '#ffffff';
const String _platformMetadataTextColor = '#000000';
const String _platformMetadataPillFillColor = '#ffffff';
const String _platformMetadataPillStrokeColor = '#000000';
const String _platformDartFillColor = '#0175c2';
const String _platformDartStrokeColor = '#0369a1';
const String _warningNodeGradientFill = 'url(#warningNodeGradient)';
const String _warningNodeBaseFillColor = '#fff6e8';
const String _warningNodeStrokeColor = 'gray';
const String _platformIosFillColor = '#111827';
const String _platformIosStrokeColor = '#0f172a';
const String _platformIosLegacyFillColor = '#e05545';
const String _platformIosLegacyStrokeColor = '#b91c1c';
const String _platformAndroidFillColor = '#16a34a';
const String _platformAndroidStrokeColor = '#15803d';
const String _platformWindowsFillColor = '#2563eb';
const String _platformWindowsStrokeColor = '#1d4ed8';
const String _platformMacosFillColor = '#475569';
const String _platformMacosStrokeColor = '#334155';
const String _platformLinuxFillColor = '#7c3aed';
const String _platformLinuxStrokeColor = '#6d28d9';
const String _platformWebFillColor = '#0891b2';
const String _platformWebStrokeColor = '#0e7490';
const double _warningNodeFillOpacity = 0.68;
const double _warningNodeStrokeWidth = 0.5;
const String _warningCaptionFilter = 'url(#outlineWhite)';
const String _packageTitleLabelClass = 'packageLabelTitle';
const String _packageSectionLabelClass = 'packageLabelSection';
const String _packageDerivedSectionLabelClass = 'packageLabelDerivedSection';
const String _packageCaptionLabelClass = 'packageLabelCaption';
const String _packageNodeNameLabelClass = 'packageLabelNodeName';
const String _packageNodeVersionLabelClass = 'packageLabelNodeVersion';
const String _packageDerivedNameLabelClass = 'packageLabelDerivedName';
const String _packageDerivedVersionLabelClass = 'packageLabelDerivedVersion';
const String _packageMetadataLabelClass = 'packageLabelMetadata';
const String _packageMetadataPillGroupClass = 'packageMetadataPill';
const String _packageMetadataPillShapeClass = 'packageMetadataPillShape';
const String _packagePlatformBadgeLabelClass = 'packageLabelPlatformBadge';
const String _packageWarningLabelClass = 'packageLabelWarning';

/// Builds package-specific label classes, adding the warning modifier when set.
String _buildPackageLabelClasses(String roleClass, {bool warning = false}) {
  return warning ? '$roleClass $_packageWarningLabelClass' : roleClass;
}

/// Returns package SVG label styles so font settings stay centralized.
String _buildPackageLabelStyles() =>
    '''
<style>
  .$_packageTitleLabelClass {
    fill: $_titleTextColor;
    font-size: ${_titleFontSize}px;
    font-weight: 700;
  }

  .$_packageSectionLabelClass {
    fill: $_sectionTextColor;
    font-size: ${_sectionFontSize}px;
    font-weight: 700;
  }

  .$_packageDerivedSectionLabelClass {
    fill: $_derivedGroupLabelColor;
    font-size: ${_derivedGroupLabelFontSize}px;
    font-weight: 700;
  }

  .$_packageCaptionLabelClass {
    filter: $_warningCaptionFilter;
    font-weight: 900;
  }

  .$_packageNodeNameLabelClass {
    fill: $_titleTextColor;
    font-size: ${_nodeTextFontSize}px;
  }

  .$_packageNodeVersionLabelClass {
    fill: $_versionTextColor;
    font-size: ${_nodeVersionFontSize}px;
  }

  .$_packageDerivedNameLabelClass {
    fill: $_titleTextColor;
    font-size: ${_derivedNodeNameFontSize}px;
  }

  .$_packageDerivedVersionLabelClass {
    fill: $_versionTextColor;
    font-size: ${_derivedNodeNameFontSize}px;
  }

  .$_packageMetadataLabelClass {
    fill: $_platformMetadataTextColor;
    font-size: ${_platformMetadataFontSize}px;
    font-weight: 600;
  }

  .$_packageMetadataPillShapeClass {
    fill: $_platformMetadataPillFillColor;
    stroke: $_platformMetadataPillStrokeColor;
    stroke-width: $_platformMetadataPillStrokeWidth;
  }

  .$_packagePlatformBadgeLabelClass {
    fill: $_platformBadgeTextColor;
    font-size: ${_platformBadgeFontSize}px;
    font-weight: 700;
  }

  .$_packageWarningLabelClass {
    filter: $_warningCaptionFilter;
    font-weight: 900;
  }
</style>''';

String _buildLegacyIosPlatformBadgePath({
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final centerX = x + (width / _halfDivisor);
  final right = x + width;
  final bottom = y + height;
  return 'M $centerX $y L $right $bottom L $x $bottom Z';
}

class _PlatformBadgeDefinition {
  final String cssSuffix;
  final String label;
  final String title;
  final String fillColor;
  final String strokeColor;
  final bool Function(PackagePlatformSupport support) isEnabled;

  const _PlatformBadgeDefinition({
    required this.cssSuffix,
    required this.label,
    required this.title,
    required this.fillColor,
    required this.strokeColor,
    required this.isEnabled,
  });
}

const List<_PlatformBadgeDefinition> _platformBadgeDefinitions =
    <_PlatformBadgeDefinition>[
      _PlatformBadgeDefinition(
        cssSuffix: 'dart',
        label: 'Dart',
        title: 'Dart',
        fillColor: _platformDartFillColor,
        strokeColor: _platformDartStrokeColor,
        isEnabled: _supportsDart,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'android',
        label: 'A',
        title: 'Android',
        fillColor: _platformAndroidFillColor,
        strokeColor: _platformAndroidStrokeColor,
        isEnabled: _supportsAndroid,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'ios',
        label: 'I',
        title: 'iOS',
        fillColor: _platformIosFillColor,
        strokeColor: _platformIosStrokeColor,
        isEnabled: _supportsIos,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'linux',
        label: 'L',
        title: 'Linux',
        fillColor: _platformLinuxFillColor,
        strokeColor: _platformLinuxStrokeColor,
        isEnabled: _supportsLinux,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'macos',
        label: 'M',
        title: 'macOS',
        fillColor: _platformMacosFillColor,
        strokeColor: _platformMacosStrokeColor,
        isEnabled: _supportsMacos,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'windows',
        label: 'W',
        title: 'Windows',
        fillColor: _platformWindowsFillColor,
        strokeColor: _platformWindowsStrokeColor,
        isEnabled: _supportsWindows,
      ),
      _PlatformBadgeDefinition(
        cssSuffix: 'web',
        label: 'B',
        title: 'Browser',
        fillColor: _platformWebFillColor,
        strokeColor: _platformWebStrokeColor,
        isEnabled: _supportsWeb,
      ),
    ];

bool _supportsAndroid(PackagePlatformSupport support) =>
    support.supportsAndroid;

bool _supportsIos(PackagePlatformSupport support) => support.supportsIos;

bool _supportsWindows(PackagePlatformSupport support) =>
    support.supportsWindows;

bool _supportsMacos(PackagePlatformSupport support) => support.supportsMacos;

bool _supportsLinux(PackagePlatformSupport support) => support.supportsLinux;

bool _supportsWeb(PackagePlatformSupport support) => support.supportsWeb;

bool _supportsDart(PackagePlatformSupport support) => support.isPureDart;

String _badgeLabel(_PlatformBadgeDefinition badge) => badge.label;

double _platformBadgeLabelYOffset(String badgeLabel) =>
    badgeLabel.length == _platformBadgeBaseLabelLength
    ? _platformBadgeSingleLetterLabelYOffset
    : 0;

String _badgeTitle(
  _PlatformBadgeDefinition badge,
  PackagePlatformSupport support,
) {
  if (badge.cssSuffix == 'dart' && support.dartSdkConstraint.isNotEmpty) {
    return 'Dart SDK ${support.dartSdkConstraint}';
  }
  return badge.title;
}

/// Builds the optional SDK metadata labels rendered below platform badges.
List<String> _platformMetadataLabels(PackagePlatformSupport support) {
  final labels = <String>[];
  if (support.isPureDart && support.dartSdkConstraint.isNotEmpty) {
    labels.add(_sdkMetadataLabel('Dart', support.dartSdkConstraint));
  }
  if (support.flutterSdkConstraint.isNotEmpty) {
    labels.add(_sdkMetadataLabel('Flutter', support.flutterSdkConstraint));
  }
  return labels;
}

/// Builds the SDK metadata labels rendered below the root project title.
///
/// The project header should show both Dart and Flutter constraints when they
/// are declared, even when the project is not a pure Dart package.
List<String> projectSdkMetadataLabels(PackagePlatformSupport support) {
  final labels = <String>[];
  if (support.dartSdkConstraint.isNotEmpty) {
    labels.add(_sdkMetadataLabel('Dart', support.dartSdkConstraint));
  }
  if (support.flutterSdkConstraint.isNotEmpty) {
    labels.add(_sdkMetadataLabel('Flutter', support.flutterSdkConstraint));
  }
  return labels;
}

/// Renders compact platform badges inside a package node when metadata exists.
void writePlatformBadges(
  StringBuffer buffer, {
  required double x,
  required double y,
  required double nodeWidth,
  required double nodeHeight,
  required PackagePlatformSupport? platformSupport,
  bool highlightCaptions = false,
}) {
  if (platformSupport == null || !platformSupport.hasBadge) {
    return;
  }

  final List<_PlatformBadgeDefinition> enabledBadges = _platformBadgeDefinitions
      .where((definition) => definition.isEnabled(platformSupport))
      .toList(growable: false);
  final List<String> metadataLabels = _platformMetadataLabels(platformSupport);
  if (enabledBadges.isEmpty && metadataLabels.isEmpty) {
    return;
  }

  final badgeLabels = enabledBadges.map(_badgeLabel).toList(growable: false);
  final badgeTitles = enabledBadges
      .map((badge) => _badgeTitle(badge, platformSupport))
      .toList(growable: false);

  final badgeWidths = badgeLabels
      .map(_platformBadgeWidthForLabel)
      .toList(growable: false);
  final badgesWidth = badgeWidths.fold<double>(0, (sum, width) => sum + width);
  final totalWidth =
      badgesWidth + ((enabledBadges.length - 1) * _platformBadgeGap);
  final startX = x + ((nodeWidth - totalWidth) / _halfDivisor);
  final metadataPillY =
      y +
      nodeHeight -
      _platformMetadataBottomInset -
      _platformMetadataPillHeight;
  final badgeY = metadataLabels.isEmpty
      ? y + nodeHeight - _platformMetadataBottomInset - _platformBadgeHeight
      : metadataPillY - _platformMetadataGap - _platformBadgeHeight;

  if (metadataLabels.isNotEmpty) {
    _writeMetadataPills(
      buffer,
      centerX: x + (nodeWidth / _halfDivisor),
      topY: metadataPillY,
      labels: metadataLabels,
      highlightCaptions: highlightCaptions,
    );
  }

  if (enabledBadges.isEmpty) {
    return;
  }

  var currentX = startX;

  for (var index = 0; index < enabledBadges.length; index++) {
    final badge = enabledBadges[index];
    final badgeLabel = badgeLabels[index];
    final badgeTitle = badgeTitles[index];
    final badgeWidth = badgeWidths[index];
    final badgeX = currentX;
    final badgeCenterX = badgeX + (badgeWidth / _halfDivisor);
    final badgeCenterY =
        badgeY +
        (_platformBadgeHeight / _halfDivisor) +
        _platformBadgeLabelYOffset(badgeLabel);
    final isLegacyIosBadge =
        badge.cssSuffix == _iosPlatformKey &&
        platformSupport.hasLegacyIosWarning;
    final resolvedBadgeTitle = isLegacyIosBadge
        ? AppStrings.legacyIosCocoaPods
        : badge.title;
    final badgeFillColor = isLegacyIosBadge
        ? _platformIosLegacyFillColor
        : badge.fillColor;
    final badgeStrokeColor = isLegacyIosBadge
        ? _platformIosLegacyStrokeColor
        : badge.strokeColor;
    final badgeShapeSvg = isLegacyIosBadge
        ? '<path d="${_buildLegacyIosPlatformBadgePath(x: badgeX, y: badgeY, width: badgeWidth, height: _platformBadgeHeight)}" fill="$badgeFillColor" stroke="$badgeStrokeColor" stroke-width="$_platformBadgeStrokeWidth"/>'
        : '<rect x="$badgeX" y="$badgeY" width="$badgeWidth" height="$_platformBadgeHeight" rx="$_platformBadgeCornerRadius" ry="$_platformBadgeCornerRadius" fill="$badgeFillColor" stroke="$badgeStrokeColor" stroke-width="$_platformBadgeStrokeWidth"/>';
    buffer.writeln(
      '<g class="platformBadge platformBadge--${badge.cssSuffix}"><title>${escapeXml(isLegacyIosBadge ? resolvedBadgeTitle : badgeTitle)}</title>$badgeShapeSvg<text x="$badgeCenterX" y="$badgeCenterY" class="$_packagePlatformBadgeLabelClass" text-anchor="middle" dominant-baseline="middle">${escapeXml(badgeLabel)}</text></g>',
    );
    currentX += badgeWidth + _platformBadgeGap;
  }
}

/// Renders a package node rectangle with name and version text labels.
///
/// Pass [strokeDashArray] to render a dashed border (e.g. for derived nodes).
void writePackageNodeSvg(
  StringBuffer buffer, {
  required double x,
  required double y,
  required double nodeWidth,
  required double nodeHeight,
  required double nameYOffset,
  required double versionYOffset,
  required PackageDependencyNode node,
  required String fillColor,
  required String strokeColor,
  String strokeDashArray = '',
  bool inlineVersion = false,
  PackagePlatformSupport? platformSupport,
}) {
  final hasLegacyIosWarning = platformSupport?.hasLegacyIosWarning == true;
  final effectiveFillColor = hasLegacyIosWarning
      ? _warningNodeGradientFill
      : fillColor;
  final effectiveStrokeColor = hasLegacyIosWarning
      ? _warningNodeStrokeColor
      : strokeColor;
  final effectiveStrokeWidth = hasLegacyIosWarning
      ? _warningNodeStrokeWidth
      : 1;
  final nodeClass = hasLegacyIosWarning
      ? 'packageNode packageNode--legacyIos'
      : 'packageNode';
  final dashAttr = strokeDashArray.isNotEmpty
      ? ' stroke-dasharray="$strokeDashArray"'
      : '';
  final warningFillOpacityAttr = hasLegacyIosWarning
      ? ' fill-opacity="$_warningNodeFillOpacity"'
      : '';
  final baseNameClass = inlineVersion
      ? _packageDerivedNameLabelClass
      : _packageNodeNameLabelClass;
  final nameClass = '$baseNameClass $_packageCaptionLabelClass';
  final versionClass = _buildPackageLabelClasses(
    inlineVersion
        ? _packageDerivedVersionLabelClass
        : _packageNodeVersionLabelClass,
    warning: hasLegacyIosWarning,
  );
  buffer.writeln('<g class="$nodeClass">');
  if (hasLegacyIosWarning) {
    buffer.writeln(
      '<title>${escapeXml(AppStrings.legacyIosCocoaPods)}</title>',
    );
    buffer.writeln(
      '<rect x="$x" y="$y" width="$nodeWidth" height="$nodeHeight" rx="$_cornerRadius" ry="$_cornerRadius" fill="$_warningNodeBaseFillColor"/>',
    );
  }
  buffer.writeln(
    '<rect x="$x" y="$y" width="$nodeWidth" height="$nodeHeight" rx="$_cornerRadius" ry="$_cornerRadius" fill="$effectiveFillColor"$warningFillOpacityAttr stroke="$effectiveStrokeColor" stroke-width="$effectiveStrokeWidth"$dashAttr/>',
  );
  writePlatformBadges(
    buffer,
    x: x,
    y: y,
    nodeWidth: nodeWidth,
    nodeHeight: nodeHeight,
    platformSupport: platformSupport,
    highlightCaptions: hasLegacyIosWarning,
  );
  if (inlineVersion) {
    final escapedName = escapeXml(node.name);
    final escapedVersion = escapeXml(node.version);
    final versionDisplay = escapedVersion.startsWith(RegExp(r'[0-9]'))
        ? '^$escapedVersion'
        : escapedVersion;

    buffer.writeln(
      '<text x="${x + _derivedNodeTextPadding}" y="${y + nameYOffset}" class="$nameClass" text-anchor="start">$escapedName</text>',
    );
    buffer.writeln(
      '<text x="${x + nodeWidth - _derivedNodeTextPadding}" y="${y + nameYOffset}" class="$versionClass" text-anchor="end">$versionDisplay</text>',
    );
  } else {
    buffer.writeln(
      '<text x="${x + (nodeWidth / _halfDivisor)}" y="${y + nameYOffset}" class="$nameClass" text-anchor="middle">${escapeXml(node.name)}</text>',
    );
    buffer.writeln(
      '<text x="${x + (nodeWidth / _halfDivisor)}" y="${y + versionYOffset}" class="$versionClass" text-anchor="middle">v${escapeXml(node.version)}</text>',
    );
  }
  buffer.writeln('</g>');
}

double _platformBadgeWidthForLabel(String label) {
  final extraCharacterCount = max(
    0,
    label.length - _platformBadgeBaseLabelLength,
  );
  return _platformBadgeMinimumWidth +
      (extraCharacterCount * _platformBadgeWidthPerExtraCharacter);
}
