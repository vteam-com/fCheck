part of 'export_svg_package_dependencies.dart';

const String _dartToolDirectoryName = '.dart_tool';
const String _packageConfigFileName = 'package_config.json';
const String _packageConfigPackagesKey = 'packages';
const String _packageConfigNameKey = 'name';
const String _packageConfigRootUriKey = 'rootUri';
const String _environmentKey = 'environment';
const String _sdkKey = 'sdk';
const String _platformsKey = 'platforms';
const String _flutterKey = 'flutter';
const String _pluginKey = 'plugin';
const String _defaultPackageKey = 'default_package';
const String _dartPluginClassKey = 'dartPluginClass';
const String _ffiPluginKey = 'ffiPlugin';
const String _pluginClassKey = 'pluginClass';
const String _androidPlatformKey = 'android';
const String _iosPlatformKey = 'ios';
const String _windowsPlatformKey = 'windows';
const String _macosPlatformKey = 'macos';
const String _linuxPlatformKey = 'linux';
const String _webPlatformKey = 'web';
const String _darwinPlatformFolder = 'darwin';

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

/// Supported platforms declared by a package.
class PackagePlatformSupport {
  /// Whether the package declares Android support.
  final bool supportsAndroid;

  /// Whether the package declares iOS support.
  final bool supportsIos;

  /// Whether the package falls back to a legacy CocoaPods iOS integration.
  final bool usesLegacyIosCocoaPods;

  /// Whether the package declares Windows support.
  final bool supportsWindows;

  /// Whether the package declares macOS support.
  final bool supportsMacos;

  /// Whether the package declares Linux support.
  final bool supportsLinux;

  /// Whether the package declares web/browser support.
  final bool supportsWeb;

  /// Whether the package is a pure Dart package that runs on any platform.
  final bool isPureDart;

  /// The declared Dart SDK constraint from `environment.sdk`, when present.
  final String dartSdkConstraint;

  /// The declared Flutter SDK constraint from `environment.flutter`, when present.
  final String flutterSdkConstraint;

  /// Creates a package platform support value.
  const PackagePlatformSupport({
    this.supportsAndroid = false,
    this.supportsIos = false,
    this.usesLegacyIosCocoaPods = false,
    this.supportsWindows = false,
    this.supportsMacos = false,
    this.supportsLinux = false,
    this.supportsWeb = false,
    this.isPureDart = false,
    this.dartSdkConstraint = '',
    this.flutterSdkConstraint = '',
  });

  /// Returns whether at least one explicit platform is declared.
  bool get hasAny =>
      supportsAndroid ||
      supportsIos ||
      supportsWindows ||
      supportsMacos ||
      supportsLinux ||
      supportsWeb;

  /// Returns whether this package should render a runtime badge.
  bool get hasBadge => hasAny || isPureDart || flutterSdkConstraint.isNotEmpty;

  /// Returns whether the package should render the legacy iOS warning state.
  bool get hasLegacyIosWarning => supportsIos && usesLegacyIosCocoaPods;

  /// Returns a merged support set containing every supported platform from both values.
  PackagePlatformSupport merge(PackagePlatformSupport other) {
    final mergedSupport = PackagePlatformSupport(
      supportsAndroid: supportsAndroid || other.supportsAndroid,
      supportsIos: supportsIos || other.supportsIos,
      usesLegacyIosCocoaPods:
          usesLegacyIosCocoaPods || other.usesLegacyIosCocoaPods,
      supportsWindows: supportsWindows || other.supportsWindows,
      supportsMacos: supportsMacos || other.supportsMacos,
      supportsLinux: supportsLinux || other.supportsLinux,
      supportsWeb: supportsWeb || other.supportsWeb,
      dartSdkConstraint: dartSdkConstraint.isNotEmpty
          ? dartSdkConstraint
          : other.dartSdkConstraint,
      flutterSdkConstraint: flutterSdkConstraint.isNotEmpty
          ? flutterSdkConstraint
          : other.flutterSdkConstraint,
    );
    return PackagePlatformSupport(
      supportsAndroid: mergedSupport.supportsAndroid,
      supportsIos: mergedSupport.supportsIos,
      usesLegacyIosCocoaPods: mergedSupport.usesLegacyIosCocoaPods,
      supportsWindows: mergedSupport.supportsWindows,
      supportsMacos: mergedSupport.supportsMacos,
      supportsLinux: mergedSupport.supportsLinux,
      supportsWeb: mergedSupport.supportsWeb,
      isPureDart: !mergedSupport.hasAny && (isPureDart || other.isPureDart),
      dartSdkConstraint: mergedSupport.dartSdkConstraint,
      flutterSdkConstraint: mergedSupport.flutterSdkConstraint,
    );
  }
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

/// Collects every package name that can render as a node in the package SVG.
Set<String> collectVisiblePackageNames({
  required List<PackageDependencyNode> dependencies,
  required List<PackageDependencyNode> devDependencies,
  required Map<String, List<PackageDependencyNode>>
  derivedDependenciesByPackage,
  required Map<String, List<PackageDependencyNode>>
  nestedDerivedDependenciesByPackage,
}) {
  return <String>{
    ...dependencies.map((node) => node.name),
    ...devDependencies.map((node) => node.name),
    ...derivedDependenciesByPackage.values.expand(
      (nodes) => nodes.map((node) => node.name),
    ),
    ...nestedDerivedDependenciesByPackage.values.expand(
      (nodes) => nodes.map((node) => node.name),
    ),
  };
}

/// Reads runtime badge metadata for visible packages from package pubspecs.
Map<String, PackagePlatformSupport> readPackagePlatformSupportByPackage(
  Directory directory,
  Set<String> packageNames,
) {
  if (packageNames.isEmpty) {
    return const <String, PackagePlatformSupport>{};
  }

  final packageRootsByName = _readPackageRootsFromPackageConfig(directory);
  if (packageRootsByName.isEmpty) {
    return const <String, PackagePlatformSupport>{};
  }

  final sortedPackageNames = packageNames.toList()..sort();
  final supportByPackage = <String, PackagePlatformSupport>{};
  for (final packageName in sortedPackageNames) {
    final packageRoot = packageRootsByName[packageName];
    if (packageRoot == null) {
      continue;
    }

    final pubspecFile = File(p.join(packageRoot.path, _pubspecFileName));
    if (!pubspecFile.existsSync()) {
      continue;
    }

    final platformSupport = readPackagePlatformSupportFromPubspec(pubspecFile);
    if (platformSupport.hasBadge) {
      supportByPackage[packageName] = platformSupport;
    }
  }
  return supportByPackage;
}

/// Resolves package root directories from `.dart_tool/package_config.json`.
///
/// The package config can contain both file URIs and relative root URIs, so
/// roots are resolved against the config file location before checking for a
/// readable package directory.
Map<String, Directory> _readPackageRootsFromPackageConfig(Directory directory) {
  final packageConfigFile = File(
    p.join(directory.path, _dartToolDirectoryName, _packageConfigFileName),
  );
  if (!packageConfigFile.existsSync()) {
    return const <String, Directory>{};
  }

  try {
    final parsed = jsonDecode(packageConfigFile.readAsStringSync());
    if (parsed is! Map<String, dynamic>) {
      return const <String, Directory>{};
    }

    final packages = parsed[_packageConfigPackagesKey];
    if (packages is! List<dynamic>) {
      return const <String, Directory>{};
    }

    final packageConfigDirectoryUri = packageConfigFile.parent.uri;
    final packageRootsByName = <String, Directory>{};
    for (final packageEntry in packages) {
      if (packageEntry is! Map<String, dynamic>) {
        continue;
      }
      final packageName = packageEntry[_packageConfigNameKey];
      final rootUri = packageEntry[_packageConfigRootUriKey];
      if (packageName is! String || packageName.trim().isEmpty) {
        continue;
      }
      if (rootUri is! String || rootUri.trim().isEmpty) {
        continue;
      }

      final resolvedRootUri = packageConfigDirectoryUri.resolve(rootUri);
      if (resolvedRootUri.scheme != 'file') {
        continue;
      }

      final packageRoot = Directory.fromUri(resolvedRootUri);
      if (!packageRoot.existsSync()) {
        continue;
      }
      packageRootsByName[packageName] = packageRoot;
    }
    return packageRootsByName;
  } catch (_) {
    return const <String, Directory>{};
  }
}

/// Reads supported-platform declarations from a package `pubspec.yaml`.
///
/// This merges both top-level `platforms:` metadata and Flutter plugin
/// declarations under `flutter.plugin.platforms`.
PackagePlatformSupport readPackagePlatformSupportFromPubspec(File pubspecFile) {
  try {
    final yaml = loadYaml(pubspecFile.readAsStringSync());
    if (yaml is! YamlMap) {
      return const PackagePlatformSupport();
    }

    final dartSdkConstraint = _readDartSdkConstraint(yaml);
    final flutterSdkConstraint = _readFlutterSdkConstraint(yaml);
    final declaredPlatforms = _parsePackagePlatformSupport(yaml[_platformsKey]);
    final flutterPlatforms = _parseFlutterPluginPlatformSupport(
      yaml[_flutterKey],
      packageRoot: pubspecFile.parent,
      packageName: _readPackageName(yaml),
    );
    final mergedPlatformSupport = declaredPlatforms.merge(flutterPlatforms);
    if (mergedPlatformSupport.hasAny) {
      return PackagePlatformSupport(
        supportsAndroid: mergedPlatformSupport.supportsAndroid,
        supportsIos: mergedPlatformSupport.supportsIos,
        usesLegacyIosCocoaPods: mergedPlatformSupport.usesLegacyIosCocoaPods,
        supportsWindows: mergedPlatformSupport.supportsWindows,
        supportsMacos: mergedPlatformSupport.supportsMacos,
        supportsLinux: mergedPlatformSupport.supportsLinux,
        supportsWeb: mergedPlatformSupport.supportsWeb,
        dartSdkConstraint: dartSdkConstraint,
        flutterSdkConstraint: flutterSdkConstraint,
      );
    }
    if (flutterSdkConstraint.isNotEmpty) {
      return PackagePlatformSupport(
        dartSdkConstraint: dartSdkConstraint,
        flutterSdkConstraint: flutterSdkConstraint,
      );
    }
    if (_isPureDartPackage(yaml)) {
      return PackagePlatformSupport(
        isPureDart: true,
        dartSdkConstraint: dartSdkConstraint,
      );
    }
    return const PackagePlatformSupport();
  } catch (_) {
    return const PackagePlatformSupport();
  }
}

/// Returns a normalized string constraint from the `environment` section.
///
/// Package SVG metadata reuses this helper for both Dart and Flutter SDK
/// constraints so the rendered `D:` and `F:` values stay consistent.
String _readEnvironmentConstraint(YamlMap yaml, String key) {
  final environmentValue = yaml[_environmentKey];
  if (environmentValue is! YamlMap) {
    return '';
  }

  final value = environmentValue[key];
  if (value is! String) {
    return '';
  }

  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Returns the normalized `environment.sdk` constraint from a package pubspec.
///
/// Pure Dart package nodes render this value in the metadata row using the
/// `D:` prefix so the SVG can show which Dart SDK range the package supports.
String _readDartSdkConstraint(YamlMap yaml) =>
    _readEnvironmentConstraint(yaml, _sdkKey);

/// Returns the normalized `environment.flutter` constraint from a package pubspec.
///
/// Flutter package nodes render this value in the metadata row using the `F:`
/// prefix below the supported platform badges.
String _readFlutterSdkConstraint(YamlMap yaml) =>
    _readEnvironmentConstraint(yaml, _flutterKey);

String _readPackageName(YamlMap yaml) {
  final packageName = yaml[_packageConfigNameKey];
  if (packageName is! String) {
    return '';
  }
  return packageName.trim();
}

/// Returns whether a package pubspec represents a runtime-agnostic Dart package.
///
/// Pure Dart packages do not declare Flutter plugin platforms and do not depend
/// on the Flutter SDK in their runtime dependencies.
bool _isPureDartPackage(YamlMap yaml) {
  if (yaml[_flutterKey] is YamlMap) {
    return false;
  }
  if (_readFlutterSdkConstraint(yaml).isNotEmpty) {
    return false;
  }
  return !_hasDependencyKey(yaml[_dependenciesKey], _flutterKey);
}

/// Checks whether a dependency map contains the requested package name.
bool _hasDependencyKey(Object? dependenciesValue, String packageName) {
  if (dependenciesValue is! YamlMap) {
    return false;
  }
  return dependenciesValue.keys
      .map((key) => key.toString().trim())
      .contains(packageName);
}

/// Extracts supported platforms from the Flutter plugin section, when present.
PackagePlatformSupport _parseFlutterPluginPlatformSupport(
  Object? flutterValue, {
  required Directory packageRoot,
  required String packageName,
}) {
  if (flutterValue is! YamlMap) {
    return const PackagePlatformSupport();
  }

  final pluginValue = flutterValue[_pluginKey];
  if (pluginValue is! YamlMap) {
    return const PackagePlatformSupport();
  }

  final platformSupport = _parsePackagePlatformSupport(
    pluginValue[_platformsKey],
  );
  if (!platformSupport.supportsIos) {
    return platformSupport;
  }

  return PackagePlatformSupport(
    supportsAndroid: platformSupport.supportsAndroid,
    supportsIos: platformSupport.supportsIos,
    usesLegacyIosCocoaPods: _usesLegacyIosCocoaPods(
      pluginValue[_platformsKey],
      packageRoot: packageRoot,
      packageName: packageName,
    ),
    supportsWindows: platformSupport.supportsWindows,
    supportsMacos: platformSupport.supportsMacos,
    supportsLinux: platformSupport.supportsLinux,
    supportsWeb: platformSupport.supportsWeb,
  );
}

/// Returns whether an iOS plugin declaration still falls back to CocoaPods.
///
/// A package is considered legacy only when it owns a native iOS plugin
/// implementation in the current package and does not expose a Swift Package
/// Manager manifest under its iOS or shared Darwin sources.
bool _usesLegacyIosCocoaPods(
  Object? platformsValue, {
  required Directory packageRoot,
  required String packageName,
}) {
  final iosPlatformValue = _readPlatformConfigValue(
    platformsValue,
    _iosPlatformKey,
  );
  if (iosPlatformValue is! YamlMap &&
      iosPlatformValue is! Map<dynamic, dynamic>) {
    return false;
  }

  final iosConfig = _normalizePlatformConfig(iosPlatformValue!);
  if (_hasNonEmptyString(iosConfig[_defaultPackageKey])) {
    return false;
  }
  if (_hasNativeIosSwiftPackageManifest(
    packageRoot,
    packageName: packageName,
  )) {
    return false;
  }
  if (_hasNonEmptyString(iosConfig[_pluginClassKey])) {
    return true;
  }
  if (_hasNonEmptyString(iosConfig[_dartPluginClassKey])) {
    return false;
  }
  if (iosConfig[_ffiPluginKey] == true) {
    return true;
  }

  return false;
}

Object? _readPlatformConfigValue(Object? platformsValue, String platformKey) {
  if (platformsValue is YamlMap) {
    return platformsValue[platformKey];
  }
  if (platformsValue is Map<dynamic, dynamic>) {
    return platformsValue[platformKey];
  }
  return null;
}

Map<dynamic, dynamic> _normalizePlatformConfig(Object platformValue) {
  if (platformValue is YamlMap) {
    return Map<dynamic, dynamic>.fromEntries(platformValue.entries);
  }
  if (platformValue is Map<dynamic, dynamic>) {
    return platformValue;
  }
  return const <dynamic, dynamic>{};
}

bool _hasNonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

/// Returns whether the package exposes an iOS or shared-Darwin SwiftPM manifest.
///
/// Flutter plugin packages place Swift Package Manager support under either
/// `ios/<package>/Package.swift` or `darwin/<package>/Package.swift`, while a
/// small number of packages keep the manifest directly under the platform root.
bool _hasNativeIosSwiftPackageManifest(
  Directory packageRoot, {
  required String packageName,
}) {
  if (packageName.isEmpty) {
    return false;
  }

  final manifestPaths = <String>{
    p.join(packageRoot.path, _iosPlatformKey, _packageManifestFileName),
    p.join(
      packageRoot.path,
      _iosPlatformKey,
      packageName,
      _packageManifestFileName,
    ),
    p.join(packageRoot.path, _darwinPlatformFolder, _packageManifestFileName),
    p.join(
      packageRoot.path,
      _darwinPlatformFolder,
      packageName,
      _packageManifestFileName,
    ),
  };
  return manifestPaths.any((path) => File(path).existsSync());
}

const String _packageManifestFileName = 'Package.swift';

/// Converts a `platforms` declaration into a normalized support value.
PackagePlatformSupport _parsePackagePlatformSupport(Object? platformsValue) {
  final supportedPlatformKeys = _extractSupportedPlatformKeys(platformsValue);
  return PackagePlatformSupport(
    supportsAndroid: supportedPlatformKeys.contains(_androidPlatformKey),
    supportsIos: supportedPlatformKeys.contains(_iosPlatformKey),
    supportsWindows: supportedPlatformKeys.contains(_windowsPlatformKey),
    supportsMacos: supportedPlatformKeys.contains(_macosPlatformKey),
    supportsLinux: supportedPlatformKeys.contains(_linuxPlatformKey),
    supportsWeb: supportedPlatformKeys.contains(_webPlatformKey),
  );
}

/// Normalizes platform keys from either map-style or list-style pubspec data.
Set<String> _extractSupportedPlatformKeys(Object? platformsValue) {
  if (platformsValue is YamlMap) {
    return platformsValue.keys
        .map((key) => key.toString().trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  if (platformsValue is Map<dynamic, dynamic>) {
    return platformsValue.keys
        .map((key) => key.toString().trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  if (platformsValue is Iterable<dynamic>) {
    return platformsValue
        .map((entry) => entry.toString().trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  return const <String>{};
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
