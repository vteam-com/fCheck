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
const String _implementsKey = 'implements';
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

  /// The federated plugin this package implements on iOS, from
  /// `flutter.plugin.implements` when `flutter.plugin.platforms` declares
  /// `ios`; empty otherwise.
  final String iosImplementedPlugin;

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
    this.iosImplementedPlugin = '',
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

  /// Returns a copy of this support with the given fields replaced.
  PackagePlatformSupport copyWith({
    bool? supportsAndroid,
    bool? supportsIos,
    bool? usesLegacyIosCocoaPods,
    bool? supportsWindows,
    bool? supportsMacos,
    bool? supportsLinux,
    bool? supportsWeb,
    bool? isPureDart,
    String? dartSdkConstraint,
    String? flutterSdkConstraint,
    String? iosImplementedPlugin,
  }) => PackagePlatformSupport(
    supportsAndroid: supportsAndroid ?? this.supportsAndroid,
    supportsIos: supportsIos ?? this.supportsIos,
    usesLegacyIosCocoaPods:
        usesLegacyIosCocoaPods ?? this.usesLegacyIosCocoaPods,
    supportsWindows: supportsWindows ?? this.supportsWindows,
    supportsMacos: supportsMacos ?? this.supportsMacos,
    supportsLinux: supportsLinux ?? this.supportsLinux,
    supportsWeb: supportsWeb ?? this.supportsWeb,
    isPureDart: isPureDart ?? this.isPureDart,
    dartSdkConstraint: dartSdkConstraint ?? this.dartSdkConstraint,
    flutterSdkConstraint: flutterSdkConstraint ?? this.flutterSdkConstraint,
    iosImplementedPlugin: iosImplementedPlugin ?? this.iosImplementedPlugin,
  );

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
      iosImplementedPlugin: iosImplementedPlugin.isNotEmpty
          ? iosImplementedPlugin
          : other.iosImplementedPlugin,
    );
    return mergedSupport.copyWith(
      isPureDart: !mergedSupport.hasAny && (isPureDart || other.isPureDart),
    );
  }
}

/// Collects every package name that can render as a node in the package SVG.
Set<String> collectVisiblePackageNames({
  required List<PackageDependencyNode> dependencies,
  required List<PackageDependencyNode> devDependencies,
  required Map<String, List<PackageDependencyNode>>
  derivedDependenciesByPackage,
  required Map<String, List<PackageDependencyNode>>
  nestedDerivedDependenciesByPackage,
  List<Map<String, List<PackageDependencyNode>>>
      transitiveDependencyLayersByParentPackage =
      const <Map<String, List<PackageDependencyNode>>>[],
}) {
  final allTransitiveLayers = transitiveDependencyLayersByParentPackage.isEmpty
      ? <Map<String, List<PackageDependencyNode>>>[
          nestedDerivedDependenciesByPackage,
        ]
      : transitiveDependencyLayersByParentPackage;
  return <String>{
    ...dependencies.map((node) => node.name),
    ...devDependencies.map((node) => node.name),
    ...derivedDependenciesByPackage.values.expand(
      (nodes) => nodes.map((node) => node.name),
    ),
    ...allTransitiveLayers.expand(
      (layerByParent) => layerByParent.values.expand(
        (nodes) => nodes.map((node) => node.name),
      ),
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
      return mergedPlatformSupport.copyWith(
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

  final implementedPlugin = pluginValue[_implementsKey];
  return platformSupport.copyWith(
    usesLegacyIosCocoaPods: _usesLegacyIosCocoaPods(
      pluginValue[_platformsKey],
      packageRoot: packageRoot,
      packageName: packageName,
    ),
    iosImplementedPlugin: implementedPlugin is String
        ? implementedPlugin.trim()
        : '',
  );
}

/// Returns [supportByPackage] without the legacy CocoaPods flag of the iOS
/// implementations the app replaced.
///
/// When a runtime dependency in [runtimePackageNames] implements a federated
/// plugin on iOS, Flutter builds it instead of the plugin's other
/// implementations, such as its endorsed `default_package`, which then only
/// sit in the lockfile (e.g. `google_maps_flutter_ios` once the app depends
/// on `google_maps_flutter_ios_sdk10`). Dev dependencies never replace an
/// implementation, since release builds leave them out. Any package in
/// [directPackageNames] keeps its flag: a CocoaPods plugin the app depends on
/// directly is always reported, whatever the Flutter version.
Map<String, PackagePlatformSupport> withoutReplacedIosImplementations(
  Map<String, PackagePlatformSupport> supportByPackage, {
  required Set<String> runtimePackageNames,
  required Set<String> directPackageNames,
}) {
  final pluginsImplementedByApp = <String>{
    for (final name in runtimePackageNames)
      if (supportByPackage[name]?.iosImplementedPlugin case final plugin?
          when plugin.isNotEmpty)
        plugin,
  };
  if (pluginsImplementedByApp.isEmpty) {
    return supportByPackage;
  }
  return <String, PackagePlatformSupport>{
    for (final MapEntry(key: name, value: support) in supportByPackage.entries)
      name:
          support.usesLegacyIosCocoaPods &&
              !directPackageNames.contains(name) &&
              pluginsImplementedByApp.contains(support.iosImplementedPlugin)
          ? support.copyWith(usesLegacyIosCocoaPods: false)
          : support,
  };
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
