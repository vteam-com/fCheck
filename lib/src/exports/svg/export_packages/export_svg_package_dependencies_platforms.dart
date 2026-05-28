part of 'export_svg_package_dependencies.dart';

const String _dartToolDirectoryName = '.dart_tool';
const String _packageConfigFileName = 'package_config.json';
const String _packageConfigPackagesKey = 'packages';
const String _packageConfigNameKey = 'name';
const String _packageConfigRootUriKey = 'rootUri';
const String _platformsKey = 'platforms';
const String _flutterKey = 'flutter';
const String _pluginKey = 'plugin';
const String _androidPlatformKey = 'android';
const String _iosPlatformKey = 'ios';
const String _windowsPlatformKey = 'windows';
const String _macosPlatformKey = 'macos';
const String _linuxPlatformKey = 'linux';
const String _webPlatformKey = 'web';

const double _platformBadgeMinimumWidth = 13;
const int _platformBadgeBaseLabelLength = 1;
const double _platformBadgeWidthPerExtraCharacter = 5;
const double _platformBadgeHeight = 13;
const double _platformBadgeGap = 4;
const double _platformBadgeBottomInset = 5;
const double _platformBadgeCornerRadius = 6.5;
const double _platformBadgeFontSize = 7;
const double _platformBadgeStrokeWidth = 0.6;

const String _platformBadgeTextColor = '#ffffff';
const String _platformDartFillColor = '#0175c2';
const String _platformDartStrokeColor = '#0369a1';
const String _platformIosFillColor = '#111827';
const String _platformIosStrokeColor = '#0f172a';
const String _platformAndroidFillColor = '#16a34a';
const String _platformAndroidStrokeColor = '#15803d';
const String _platformWindowsFillColor = '#2563eb';
const String _platformWindowsStrokeColor = '#1d4ed8';
const String _platformMacosFillColor = '#475569';
const String _platformMacosStrokeColor = '#334155';
const String _platformLinuxFillColor = '#ca8a04';
const String _platformLinuxStrokeColor = '#a16207';
const String _platformWebFillColor = '#0891b2';
const String _platformWebStrokeColor = '#0e7490';

/// Supported platforms declared by a package.
class PackagePlatformSupport {
  /// Whether the package declares Android support.
  final bool supportsAndroid;

  /// Whether the package declares iOS support.
  final bool supportsIos;

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

  /// Creates a package platform support value.
  const PackagePlatformSupport({
    this.supportsAndroid = false,
    this.supportsIos = false,
    this.supportsWindows = false,
    this.supportsMacos = false,
    this.supportsLinux = false,
    this.supportsWeb = false,
    this.isPureDart = false,
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
  bool get hasBadge => hasAny || isPureDart;

  /// Returns a merged support set containing every supported platform from both values.
  PackagePlatformSupport merge(PackagePlatformSupport other) {
    final mergedSupport = PackagePlatformSupport(
      supportsAndroid: supportsAndroid || other.supportsAndroid,
      supportsIos: supportsIos || other.supportsIos,
      supportsWindows: supportsWindows || other.supportsWindows,
      supportsMacos: supportsMacos || other.supportsMacos,
      supportsLinux: supportsLinux || other.supportsLinux,
      supportsWeb: supportsWeb || other.supportsWeb,
    );
    return PackagePlatformSupport(
      supportsAndroid: mergedSupport.supportsAndroid,
      supportsIos: mergedSupport.supportsIos,
      supportsWindows: mergedSupport.supportsWindows,
      supportsMacos: mergedSupport.supportsMacos,
      supportsLinux: mergedSupport.supportsLinux,
      supportsWeb: mergedSupport.supportsWeb,
      isPureDart: !mergedSupport.hasAny && (isPureDart || other.isPureDart),
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
        cssSuffix: 'ios',
        label: 'I',
        title: 'iOS',
        fillColor: _platformIosFillColor,
        strokeColor: _platformIosStrokeColor,
        isEnabled: _supportsIos,
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
        cssSuffix: 'windows',
        label: 'W',
        title: 'Windows',
        fillColor: _platformWindowsFillColor,
        strokeColor: _platformWindowsStrokeColor,
        isEnabled: _supportsWindows,
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
        cssSuffix: 'linux',
        label: 'L',
        title: 'Linux',
        fillColor: _platformLinuxFillColor,
        strokeColor: _platformLinuxStrokeColor,
        isEnabled: _supportsLinux,
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

    final declaredPlatforms = _parsePackagePlatformSupport(yaml[_platformsKey]);
    final flutterPlatforms = _parseFlutterPluginPlatformSupport(
      yaml[_flutterKey],
    );
    final mergedPlatformSupport = declaredPlatforms.merge(flutterPlatforms);
    if (mergedPlatformSupport.hasAny) {
      return mergedPlatformSupport;
    }
    if (_isPureDartPackage(yaml)) {
      return const PackagePlatformSupport(isPureDart: true);
    }
    return const PackagePlatformSupport();
  } catch (_) {
    return const PackagePlatformSupport();
  }
}

/// Returns whether a package pubspec represents a runtime-agnostic Dart package.
///
/// Pure Dart packages do not declare Flutter plugin platforms and do not depend
/// on the Flutter SDK in their runtime dependencies.
bool _isPureDartPackage(YamlMap yaml) {
  if (yaml[_flutterKey] is YamlMap) {
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
  Object? flutterValue,
) {
  if (flutterValue is! YamlMap) {
    return const PackagePlatformSupport();
  }

  final pluginValue = flutterValue[_pluginKey];
  if (pluginValue is! YamlMap) {
    return const PackagePlatformSupport();
  }

  return _parsePackagePlatformSupport(pluginValue[_platformsKey]);
}

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
}) {
  if (platformSupport == null || !platformSupport.hasBadge) {
    return;
  }

  final enabledBadges = _platformBadgeDefinitions
      .where((definition) => definition.isEnabled(platformSupport))
      .toList(growable: false);
  if (enabledBadges.isEmpty) {
    return;
  }

  final badgeWidths = enabledBadges
      .map((badge) => _platformBadgeWidthForLabel(badge.label))
      .toList(growable: false);
  final badgesWidth = badgeWidths.fold<double>(0, (sum, width) => sum + width);
  final totalWidth =
      badgesWidth + ((enabledBadges.length - 1) * _platformBadgeGap);
  final startX = x + ((nodeWidth - totalWidth) / _halfDivisor);
  final badgeY =
      y + nodeHeight - _platformBadgeBottomInset - _platformBadgeHeight;

  var currentX = startX;

  for (var index = 0; index < enabledBadges.length; index++) {
    final badge = enabledBadges[index];
    final badgeWidth = badgeWidths[index];
    final badgeX = currentX;
    final badgeCenterX = badgeX + (badgeWidth / _halfDivisor);
    final badgeCenterY = badgeY + (_platformBadgeHeight / _halfDivisor);
    buffer.writeln(
      '<g class="platformBadge platformBadge--${badge.cssSuffix}"><title>${badge.title}</title><rect x="$badgeX" y="$badgeY" width="$badgeWidth" height="$_platformBadgeHeight" rx="$_platformBadgeCornerRadius" ry="$_platformBadgeCornerRadius" fill="${badge.fillColor}" stroke="${badge.strokeColor}" stroke-width="$_platformBadgeStrokeWidth"/><text x="$badgeCenterX" y="$badgeCenterY" text-anchor="middle" dominant-baseline="middle" fill="$_platformBadgeTextColor" font-size="$_platformBadgeFontSize" font-weight="700">${badge.label}</text></g>',
    );
    currentX += badgeWidth + _platformBadgeGap;
  }
}

double _platformBadgeWidthForLabel(String label) {
  final extraCharacterCount = max(
    0,
    label.length - _platformBadgeBaseLabelLength,
  );
  return _platformBadgeMinimumWidth +
      (extraCharacterCount * _platformBadgeWidthPerExtraCharacter);
}
