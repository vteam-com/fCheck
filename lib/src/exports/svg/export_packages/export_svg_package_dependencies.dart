import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:fcheck/src/exports/svg/shared/svg_styles.dart';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

part 'export_svg_package_dependencies_routing.dart';
part 'export_svg_package_dependencies_layout.dart';
part 'export_svg_package_dependencies_metadata.dart';
part 'export_svg_package_dependencies_platforms.dart';
part 'export_svg_package_dependencies_node_rendering.dart';
part 'export_svg_package_dependencies_rendering.dart';

const String _defaultProjectName = 'project';
const String _pubspecFileName = 'pubspec.yaml';
const String _pubspecLockFileName = 'pubspec.lock';
const String _dependenciesKey = 'dependencies';
const String _devDependenciesKey = 'dev_dependencies';
const String _yamlPackagesKey = 'packages';
const String _yamlVersionKey = 'version';
const String _unknownPackageVersion = 'unknown';

const String _pubCommand = 'dart';
const String _pubDepsJsonArg = 'pub';
const String _pubDepsCommandArg = 'deps';
const String _pubDepsJsonFormatArg = '--json';
const String _pubDepsPackagesKey = 'packages';
const String _pubDepsNameKey = 'name';
const String _pubDepsVersionKey = 'version';
const String _pubDepsDependenciesKey = 'dependencies';

const double _canvasPadding = 40;
const double _canvasExtraWidth = 240;
const double _edgeLaneClipSafetyPadding = 8;
const int _maxCanvasSizingIterations = 3;
const double _headerHeight = 70;
const double _nodeWidth = 200;
const double _nodeHeight = 68;
const double _columnGap = 240;
const double _titleFontSize = 22;
const double _sectionFontSize = 15;
const double _nodeTextFontSize = 13;
const double _nodeVersionFontSize = 10;
const double _edgeStrokeWidth = 2;
const double _cornerRadius = 8;
const double _edgeOpacity = 0.9;
const int _singleEntryCount = 1;
const int _singleDerivedColumnCount = 1;
const double _columnCount = 2;
const double _halfDivisor = 2;
const double _titleY = 28;
const double _projectMetadataPillY = 36;
const double _sectionUnderlineOffset = 6;
const double _nodeNameYOffset = 20;
const double _nodeVersionYOffset = 33;
const double _packageSlotSpacing = 20;
const double _sectionHeaderHeight = 26;
const double _sectionToNodesGap = 12;
const double _derivedNodeWidth = 280;
const double _derivedNodeHeight = 52;
const double _derivedNodeNameFontSize = 12;
const double _derivedNameYOffset = 18;
const double _derivedColumnSpacing = 12;
const double _derivedRowSpacing = 12;
const double _derivedGroupTopMargin = 48;
const double _derivedGroupLabelFontSize = 13;
const double _derivedGroupLabelY = 20;
const double _derivedNodeTextPadding = 8;
const double _derivedRightIncomingBadgeOffsetY = 5;
const double _derivedRightOutgoingBadgeOffsetY = 6;

const String _derivedNodeDashArray = '4,2';
const String _backgroundColor = '#f8fafc';
const String _dependencyFillColor = '#dbeafe';
const String _dependencyStrokeColor = '#1d4ed8';
const String _devDependencyFillColor = '#dcfce7';
const String _devDependencyStrokeColor = '#166534';
const String _titleTextColor = '#0f172a';
const String _sectionTextColor = '#1e293b';
const String _versionTextColor = '#334155';
const String _derivedNodeFillColor = '#f8fafc';
const String _derivedNodeStrokeColor = '#64748b';
const String _derivedGroupLabelColor = '#475569';
const int _firstDependencyLayerIndex = 0;
const int _nextDependencyLayerStartIndex = 1;

/// Package node info with resolved version.
typedef PackageDependencyNode = ({String name, String version});

/// Package dependency graph values parsed from `pubspec.yaml`.
class PackageDependencyGraphData {
  /// Project/package name owning the dependency graph.
  final String projectName;

  /// Project/package version from `pubspec.yaml`.
  final String version;

  /// Root project SDK/platform metadata from `pubspec.yaml`.
  final PackagePlatformSupport projectPlatformSupport;

  /// Regular dependencies from `dependencies`.
  final List<PackageDependencyNode> dependencies;

  /// Development dependencies from `dev_dependencies`.
  final List<PackageDependencyNode> devDependencies;

  /// One-hop derived dependencies keyed by direct package name.
  final Map<String, List<PackageDependencyNode>> derivedDependenciesByPackage;

  /// Two-hop derived dependencies keyed by one-hop package name.
  final Map<String, List<PackageDependencyNode>>
  nestedDerivedDependenciesByPackage;

  /// Additional transitive dependency layers keyed by parent package name.
  ///
  /// Each list entry represents one extra depth level after
  /// [derivedDependenciesByPackage].
  final List<Map<String, List<PackageDependencyNode>>>
  transitiveDependencyLayersByParentPackage;

  /// Reverse dependency counts: how many packages in the full tree depend on each package.
  final Map<String, int> reverseDepCounts;

  /// Outgoing dependency counts: for each package, how many packages it depends on.
  final Map<String, int> outgoingDepCounts;

  /// Runtime badge metadata keyed by package name.
  ///
  /// Packages without declared platforms and without pure-Dart classification
  /// are omitted from this map.
  final Map<String, PackagePlatformSupport> platformSupportByPackage;

  /// Creates package dependency graph data.
  const PackageDependencyGraphData({
    required this.projectName,
    required this.version,
    this.projectPlatformSupport = const PackagePlatformSupport(),
    required this.dependencies,
    required this.devDependencies,
    this.derivedDependenciesByPackage =
        const <String, List<PackageDependencyNode>>{},
    this.nestedDerivedDependenciesByPackage =
        const <String, List<PackageDependencyNode>>{},
    this.transitiveDependencyLayersByParentPackage =
        const <Map<String, List<PackageDependencyNode>>>[],
    this.reverseDepCounts = const <String, int>{},
    this.outgoingDepCounts = const <String, int>{},
    this.platformSupportByPackage = const <String, PackagePlatformSupport>{},
  });
}

/// Reads package dependency graph data from the nearest `pubspec.yaml` in [directory].
PackageDependencyGraphData loadPackageDependencyGraphData(Directory directory) {
  final pubspecFile = File('${directory.path}/$_pubspecFileName');
  if (!pubspecFile.existsSync()) {
    return const PackageDependencyGraphData(
      projectName: _defaultProjectName,
      version: _unknownPackageVersion,
      dependencies: <PackageDependencyNode>[],
      devDependencies: <PackageDependencyNode>[],
    );
  }

  try {
    final yaml = loadYaml(pubspecFile.readAsStringSync());
    if (yaml is! YamlMap) {
      return const PackageDependencyGraphData(
        projectName: _defaultProjectName,
        version: _unknownPackageVersion,
        dependencies: <PackageDependencyNode>[],
        devDependencies: <PackageDependencyNode>[],
      );
    }

    final projectName = readProjectName(yaml);
    final version = readProjectVersion(yaml);
    final projectPlatformSupport = readPackagePlatformSupportFromPubspec(
      pubspecFile,
    );
    final dependencyNames = readDependencyKeys(yaml, _dependenciesKey);
    final devDependencyNames = readDependencyKeys(yaml, _devDependenciesKey);
    final packageVersions = readPackageVersionsFromLockfile(directory);
    final dependencies = toPackageNodes(dependencyNames, packageVersions);
    final devDependencies = toPackageNodes(devDependencyNames, packageVersions);

    final allDirectPackageNames = {...dependencyNames, ...devDependencyNames};
    final derivedData = readDerivedDependenciesByPackage(
      directory,
      directPackageNames: allDirectPackageNames,
      rootPackageNames: allDirectPackageNames,
      packageVersions: packageVersions,
    );
    final platformSupportByPackage = readPackagePlatformSupportByPackage(
      directory,
      collectVisiblePackageNames(
        dependencies: dependencies,
        devDependencies: devDependencies,
        derivedDependenciesByPackage: derivedData.derivedByPackage,
        nestedDerivedDependenciesByPackage: derivedData.nestedDerivedByPackage,
        transitiveDependencyLayersByParentPackage:
            derivedData.transitiveDependencyLayersByParentPackage,
      ),
    );

    return PackageDependencyGraphData(
      projectName: projectName,
      version: version,
      projectPlatformSupport: projectPlatformSupport,
      dependencies: dependencies,
      devDependencies: devDependencies,
      derivedDependenciesByPackage: derivedData.derivedByPackage,
      nestedDerivedDependenciesByPackage: derivedData.nestedDerivedByPackage,
      transitiveDependencyLayersByParentPackage:
          derivedData.transitiveDependencyLayersByParentPackage,
      reverseDepCounts: derivedData.reverseDepCounts,
      outgoingDepCounts: derivedData.outgoingDepCounts,
      platformSupportByPackage: platformSupportByPackage,
    );
  } catch (_) {
    return const PackageDependencyGraphData(
      projectName: _defaultProjectName,
      version: _unknownPackageVersion,
      dependencies: <PackageDependencyNode>[],
      devDependencies: <PackageDependencyNode>[],
    );
  }
}

/// Reads lockfile package versions keyed by package name.
///
/// Returns an empty map when lockfile parsing is unavailable.
Map<String, String> readPackageVersionsFromLockfile(Directory directory) {
  final lockFile = File('${directory.path}/$_pubspecLockFileName');
  if (!lockFile.existsSync()) {
    return <String, String>{};
  }

  try {
    final yaml = loadYaml(lockFile.readAsStringSync());
    if (yaml is! YamlMap) {
      return <String, String>{};
    }
    final packages = yaml[_yamlPackagesKey];
    if (packages is! YamlMap) {
      return <String, String>{};
    }

    final result = <String, String>{};
    for (final entry in packages.entries) {
      final packageName = entry.key.toString();
      final packageSpec = entry.value;
      if (packageSpec is! YamlMap) {
        continue;
      }
      final version = packageSpec[_yamlVersionKey];
      if (version == null) {
        continue;
      }
      result[packageName] = version.toString();
    }
    return result;
  } catch (_) {
    return <String, String>{};
  }
}

/// Reads project name from [yaml].
///
/// Returns name field if present, otherwise returns default project name.
String readProjectName(YamlMap yaml) {
  final value = yaml['name'];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return _defaultProjectName;
}

/// Reads project version from [yaml].
///
/// Returns version string if present, otherwise returns 'unknown'.
String readProjectVersion(YamlMap yaml) {
  final value = yaml[_yamlVersionKey];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return _unknownPackageVersion;
}

/// Reads and sorts dependency keys from [yaml] at section [key].
///
/// Returns a unique, alphabetically sorted package list with blank entries
/// removed to keep SVG output deterministic and compact.
List<String> readDependencyKeys(YamlMap yaml, String key) {
  final value = yaml[key];
  if (value is! YamlMap) {
    return <String>[];
  }

  final keys =
      value.keys
          .map((entryKey) => entryKey.toString().trim())
          .where((entryKey) => entryKey.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return keys;
}

/// Converts package names to versioned package nodes.
List<PackageDependencyNode> toPackageNodes(
  List<String> packageNames,
  Map<String, String> packageVersions,
) {
  return packageNames
      .map(
        (packageName) => (
          name: packageName,
          version: packageVersions[packageName] ?? _unknownPackageVersion,
        ),
      )
      .toList(growable: false);
}

/// Resolves one-hop derived dependencies for each direct package.
///
/// The graph is loaded from `dart pub deps --json` to capture resolved
/// transitive relationships after pub's version solving.
/// Result record from [readDerivedDependenciesByPackage].
typedef DerivedPackageData = ({
  Map<String, List<PackageDependencyNode>> derivedByPackage,
  Map<String, List<PackageDependencyNode>> nestedDerivedByPackage,
  List<Map<String, List<PackageDependencyNode>>>
  transitiveDependencyLayersByParentPackage,
  Map<String, int> reverseDepCounts,
  Map<String, int> outgoingDepCounts,
});

/// Builds the derived dependency map and reverse dependency counts from `dart pub deps --json`.
///
/// The `derivedByPackage` maps each direct package name to its resolved
/// transitive dependencies. The `reverseDepCounts` maps every package name
/// to the number of other packages in the full tree that depend on it.
DerivedPackageData readDerivedDependenciesByPackage(
  Directory directory, {
  required Set<String> directPackageNames,
  required Set<String> rootPackageNames,
  required Map<String, String> packageVersions,
}) {
  final result = Process.runSync(_pubCommand, const <String>[
    _pubDepsJsonArg,
    _pubDepsCommandArg,
    _pubDepsJsonFormatArg,
  ], workingDirectory: directory.path);

  if (result.exitCode != 0) {
    return (
      derivedByPackage: <String, List<PackageDependencyNode>>{},
      nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
      transitiveDependencyLayersByParentPackage:
          <Map<String, List<PackageDependencyNode>>>[],
      reverseDepCounts: <String, int>{},
      outgoingDepCounts: <String, int>{},
    );
  }

  try {
    final parsed = jsonDecode(result.stdout as String);
    if (parsed is! Map<String, dynamic>) {
      return (
        derivedByPackage: <String, List<PackageDependencyNode>>{},
        nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
        transitiveDependencyLayersByParentPackage:
            <Map<String, List<PackageDependencyNode>>>[],
        reverseDepCounts: <String, int>{},
        outgoingDepCounts: <String, int>{},
      );
    }
    final packages = parsed[_pubDepsPackagesKey];
    if (packages is! List<dynamic>) {
      return (
        derivedByPackage: <String, List<PackageDependencyNode>>{},
        nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
        transitiveDependencyLayersByParentPackage:
            <Map<String, List<PackageDependencyNode>>>[],
        reverseDepCounts: <String, int>{},
        outgoingDepCounts: <String, int>{},
      );
    }

    final pubDepsPackages =
        <String, ({String version, List<String> dependencies})>{};
    for (final entry in packages) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final nameValue = entry[_pubDepsNameKey];
      if (nameValue is! String || nameValue.trim().isEmpty) {
        continue;
      }
      final versionValue = entry[_pubDepsVersionKey];
      final version = versionValue is String && versionValue.trim().isNotEmpty
          ? versionValue
          : (packageVersions[nameValue] ?? _unknownPackageVersion);
      final dependencyValues = entry[_pubDepsDependenciesKey];
      final dependencies = dependencyValues is List<dynamic>
          ? dependencyValues
                .whereType<String>()
                .map((dependencyName) => dependencyName.trim())
                .where((dependencyName) => dependencyName.isNotEmpty)
                .toList(growable: false)
          : const <String>[];

      pubDepsPackages[nameValue] = (
        version: version,
        dependencies: dependencies,
      );
    }

    final derivedByPackage = <String, List<PackageDependencyNode>>{};
    for (final directPackageName in directPackageNames) {
      final packageData = pubDepsPackages[directPackageName];
      if (packageData == null) {
        continue;
      }
      final derivedNames =
          packageData.dependencies
              .where(
                (dependencyName) =>
                    dependencyName != directPackageName &&
                    !rootPackageNames.contains(dependencyName),
              )
              .toSet()
              .toList()
            ..sort();

      final derivedNodes = derivedNames
          .map(
            (derivedName) => (
              name: derivedName,
              version:
                  pubDepsPackages[derivedName]?.version ??
                  packageVersions[derivedName] ??
                  _unknownPackageVersion,
            ),
          )
          .toList(growable: false);

      if (derivedNodes.isNotEmpty) {
        derivedByPackage[directPackageName] = derivedNodes;
      }
    }

    final transitiveDependencyLayersByParentPackage =
        <Map<String, List<PackageDependencyNode>>>[];
    final seenPackageNames = <String>{...rootPackageNames};
    final secondLevelPackageNames = derivedByPackage.values
        .expand((nodeList) => nodeList.map((node) => node.name))
        .toSet();
    seenPackageNames.addAll(secondLevelPackageNames);
    var currentLevelPackageNames = secondLevelPackageNames.toList()..sort();

    while (currentLevelPackageNames.isNotEmpty) {
      final currentLayerByParent = <String, List<PackageDependencyNode>>{};
      final nextLevelPackageNames = <String>{};

      for (final currentLevelPackageName in currentLevelPackageNames) {
        final packageData = pubDepsPackages[currentLevelPackageName];
        if (packageData == null) {
          continue;
        }

        final nextLevelDependencyNames =
            packageData.dependencies
                .where(
                  (dependencyName) =>
                      dependencyName != currentLevelPackageName &&
                      !rootPackageNames.contains(dependencyName) &&
                      !seenPackageNames.contains(dependencyName),
                )
                .toSet()
                .toList()
              ..sort();

        final nextLevelDependencyNodes = nextLevelDependencyNames
            .map(
              (nextLevelDependencyName) => (
                name: nextLevelDependencyName,
                version:
                    pubDepsPackages[nextLevelDependencyName]?.version ??
                    packageVersions[nextLevelDependencyName] ??
                    _unknownPackageVersion,
              ),
            )
            .toList(growable: false);

        if (nextLevelDependencyNodes.isEmpty) {
          continue;
        }

        currentLayerByParent[currentLevelPackageName] =
            nextLevelDependencyNodes;
        nextLevelPackageNames.addAll(nextLevelDependencyNames);
      }

      if (currentLayerByParent.isEmpty) {
        break;
      }

      transitiveDependencyLayersByParentPackage.add(currentLayerByParent);
      seenPackageNames.addAll(nextLevelPackageNames);
      currentLevelPackageNames = nextLevelPackageNames.toList()..sort();
    }
    final nestedDerivedByPackage =
        transitiveDependencyLayersByParentPackage.isEmpty
        ? <String, List<PackageDependencyNode>>{}
        : transitiveDependencyLayersByParentPackage.first;

    // Build reverse dependency counts: for each package, how many others depend on it.
    final reverseDepCounts = <String, int>{};
    // Build outgoing dependency counts: for each package, how many packages it depends on.
    final outgoingDepCounts = <String, int>{};
    pubDepsPackages.forEach((pkgName, pkgData) {
      for (final dep in pkgData.dependencies) {
        reverseDepCounts[dep] = (reverseDepCounts[dep] ?? 0) + 1;
      }
      outgoingDepCounts[pkgName] = pkgData.dependencies.length;
    });

    return (
      derivedByPackage: derivedByPackage,
      nestedDerivedByPackage: nestedDerivedByPackage,
      transitiveDependencyLayersByParentPackage:
          transitiveDependencyLayersByParentPackage,
      reverseDepCounts: reverseDepCounts,
      outgoingDepCounts: outgoingDepCounts,
    );
  } catch (_) {
    return (
      derivedByPackage: <String, List<PackageDependencyNode>>{},
      nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
      transitiveDependencyLayersByParentPackage:
          <Map<String, List<PackageDependencyNode>>>[],
      reverseDepCounts: <String, int>{},
      outgoingDepCounts: <String, int>{},
    );
  }
}

/// Builds SVG for Flutter/Dart package dependencies and dev_dependencies.
///
/// The layout renders direct packages in two columns (dependencies left,
/// dev_dependencies right) at the top, followed by grouped containers for each
/// resolved transitive dependency depth.
String exportSvgPackageDependencies(PackageDependencyGraphData graphData) {
  final dependencies = graphData.dependencies;
  final devDependencies = graphData.devDependencies;
  if (dependencies.isEmpty && devDependencies.isEmpty) {
    return generateEmptySvg(AppStrings.noPackageDependenciesFound);
  }

  final derivedMap = graphData.derivedDependenciesByPackage;
  final transitiveLayersByParent =
      graphData.transitiveDependencyLayersByParentPackage.isNotEmpty
      ? graphData.transitiveDependencyLayersByParentPackage
      : (graphData.nestedDerivedDependenciesByPackage.isNotEmpty
            ? <Map<String, List<PackageDependencyNode>>>[
                graphData.nestedDerivedDependenciesByPackage,
              ]
            : const <Map<String, List<PackageDependencyNode>>>[]);
  final dependencyLayerMaps = <Map<String, List<PackageDependencyNode>>>[
    derivedMap,
    ...transitiveLayersByParent,
  ];
  final uniquePackagesByLayer = dependencyLayerMaps
      .map(collectUniqueDerived)
      .toList(growable: false);

  final maxSlots = dependencies.length > devDependencies.length
      ? dependencies.length
      : devDependencies.length;
  final directColumnHeight = maxSlots > 0
      ? maxSlots * _nodeHeight + (maxSlots - 1) * _packageSlotSpacing
      : 0.0;

  final directColumnsWidth = (_nodeWidth * _columnCount) + _columnGap;
  final columnsTopY = _headerHeight + _sectionHeaderHeight + _sectionToNodesGap;

  ({
    double width,
    double height,
    double leftX,
    double rightX,
    List<double> layerTopYs,
    List<Map<String, ({double x, double y})>> layerPositions,
  })
  buildLayout(double sidePadding) {
    final width =
        (_canvasPadding * _columnCount) +
        (sidePadding * _columnCount) +
        directColumnsWidth;
    final derivedInnerWidth = width - (_canvasPadding * _columnCount);
    final layerNodesPerRow = List<int>.generate(
      uniquePackagesByLayer.length,
      (_) => computeDerivedNodesPerRow(derivedInnerWidth),
      growable: false,
    );
    final layerRows = List<int>.generate(
      uniquePackagesByLayer.length,
      (index) => computePackageLevelRowCount(
        uniquePackagesByLayer[index].length,
        layerNodesPerRow[index],
      ),
      growable: false,
    );
    final layerSectionHeights = List<double>.generate(
      uniquePackagesByLayer.length,
      (index) => computePackageLevelSectionHeight(layerRows[index]),
      growable: false,
    );

    var contentBottomY = columnsTopY + directColumnHeight;
    final layerTopYs = List<double>.filled(uniquePackagesByLayer.length, 0.0);
    for (
      var layerIndex = 0;
      layerIndex < uniquePackagesByLayer.length;
      layerIndex++
    ) {
      final layerPackages = uniquePackagesByLayer[layerIndex];
      layerTopYs[layerIndex] = contentBottomY;
      if (layerPackages.isEmpty) {
        continue;
      }
      final layerTopY = contentBottomY + _derivedGroupTopMargin;
      layerTopYs[layerIndex] = layerTopY;
      contentBottomY = layerTopY + layerSectionHeights[layerIndex];
    }

    final leftX = (width - directColumnsWidth) / _halfDivisor;
    final rightX = leftX + _nodeWidth + _columnGap;
    final derivedNodesStartX = _canvasPadding;
    final layerPositions = List<Map<String, ({double x, double y})>>.generate(
      uniquePackagesByLayer.length,
      (layerIndex) => computeDerivedPositions(
        uniquePackagesByLayer[layerIndex],
        layerNodesPerRow[layerIndex],
        startX: derivedNodesStartX,
        startY:
            layerTopYs[layerIndex] + _sectionHeaderHeight + _sectionToNodesGap,
        innerWidth: derivedInnerWidth,
      ),
      growable: false,
    );

    return (
      width: width,
      height: contentBottomY + _canvasPadding,
      leftX: leftX,
      rightX: rightX,
      layerTopYs: layerTopYs,
      layerPositions: layerPositions,
    );
  }

  // Count only edges that are visible in this diagram.
  final visibleDirectPeers = buildVisiblePackagePeerLists(
    derivedMap,
    sourcePackageNames: null,
  );
  final visibleDirectOutgoingPeers = visibleDirectPeers.outgoing;
  final visibleDirectOutgoingCounts = buildPeerCounts(
    visibleDirectOutgoingPeers,
  );
  final dependencyNames = dependencies.map((package) => package.name).toSet();
  final devDependencyNames = devDependencies
      .map((package) => package.name)
      .toSet();
  final visibleLeftIncomingPeers = buildVisiblePackagePeerLists(
    derivedMap,
    sourcePackageNames: dependencyNames,
  ).incoming;
  final visibleLeftIncomingCounts = buildPeerCounts(visibleLeftIncomingPeers);
  final visibleRightIncomingPeers = buildVisiblePackagePeerLists(
    derivedMap,
    sourcePackageNames: devDependencyNames,
  ).incoming;
  final visibleRightIncomingCounts = buildPeerCounts(visibleRightIncomingPeers);
  final layerNodeOutgoingPeers = List<Map<String, List<String>>>.generate(
    uniquePackagesByLayer.length,
    (layerIndex) {
      if (layerIndex + 1 >= dependencyLayerMaps.length) {
        return const <String, List<String>>{};
      }
      return buildVisiblePackagePeerLists(
        dependencyLayerMaps[layerIndex + 1],
        sourcePackageNames: null,
      ).outgoing;
    },
    growable: false,
  );
  final layerNodeOutgoingCounts = layerNodeOutgoingPeers
      .map(buildPeerCounts)
      .toList(growable: false);

  final layerRightIncomingPeers = List<Map<String, List<String>>>.filled(
    uniquePackagesByLayer.length,
    const <String, List<String>>{},
  );
  if (uniquePackagesByLayer.isNotEmpty) {
    layerRightIncomingPeers[_firstDependencyLayerIndex] =
        visibleRightIncomingPeers;
    for (
      var layerIndex = _nextDependencyLayerStartIndex;
      layerIndex < uniquePackagesByLayer.length;
      layerIndex++
    ) {
      final incomingLayerMap = dependencyLayerMaps[layerIndex];
      layerRightIncomingPeers[layerIndex] = buildVisiblePackagePeerLists(
        incomingLayerMap,
        sourcePackageNames: null,
      ).incoming;
    }
  }
  final layerRightIncomingCounts = layerRightIncomingPeers
      .map(buildPeerCounts)
      .toList(growable: false);

  var sidePadding = _canvasExtraWidth;
  var layout = buildLayout(sidePadding);
  for (var i = 0; i < _maxCanvasSizingIterations; i++) {
    var maxLaneCount = 0;
    maxLaneCount = max(
      maxLaneCount,
      _laneCountForColumnEdges(
        packages: dependencies,
        derivedMap: derivedMap,
        derivedPositions: layout.layerPositions[_firstDependencyLayerIndex],
        columnsTopY: columnsTopY,
        isLeftColumn: true,
        rightIncomingCounts: visibleRightIncomingCounts,
        outgoingCounts: layerNodeOutgoingCounts[_firstDependencyLayerIndex],
      ),
    );
    maxLaneCount = max(
      maxLaneCount,
      _laneCountForColumnEdges(
        packages: devDependencies,
        derivedMap: derivedMap,
        derivedPositions: layout.layerPositions[_firstDependencyLayerIndex],
        columnsTopY: columnsTopY,
        isLeftColumn: false,
        rightIncomingCounts: visibleRightIncomingCounts,
        outgoingCounts: layerNodeOutgoingCounts[_firstDependencyLayerIndex],
      ),
    );

    for (
      var layerIndex = _nextDependencyLayerStartIndex;
      layerIndex < uniquePackagesByLayer.length;
      layerIndex++
    ) {
      maxLaneCount = max(
        maxLaneCount,
        _laneCountForDerivedLevelEdges(
          derivedMap: dependencyLayerMaps[layerIndex],
          sourcePositions: layout.layerPositions[layerIndex - 1],
          targetPositions: layout.layerPositions[layerIndex],
          rightIncomingCounts: layerRightIncomingCounts[layerIndex - 1],
        ),
      );
    }

    final requiredPadding = _requiredEdgeSidePaddingForLaneCount(maxLaneCount);
    if (requiredPadding <= sidePadding) {
      break;
    }
    sidePadding = requiredPadding;
    layout = buildLayout(sidePadding);
  }

  final width = layout.width;
  final height = layout.height;
  final leftX = layout.leftX;
  final rightX = layout.rightX;
  final layerTopYs = layout.layerTopYs;
  final layerPositions = layout.layerPositions;

  final platformSupportByPackage = graphData.platformSupportByPackage;

  final buffer = StringBuffer();
  writeSvgDocumentStart(
    buffer,
    width: width,
    height: height,
    viewBoxWidth: width,
    viewBoxHeight: height,
    backgroundFill: _backgroundColor,
  );

  buffer.writeln(SvgDefinitions.generateUnifiedDefs());
  buffer.writeln(SvgDefinitions.generateUnifiedStyles());
  buffer.writeln(_buildPackageLabelStyles());

  buffer.writeln(
    '<text x="${width / _halfDivisor}" y="$_titleY" class="$_packageTitleLabelClass" text-anchor="middle">${escapeXml(graphData.projectName)} v${escapeXml(graphData.version)}</text>',
  );
  final projectMetadataLabels = projectSdkMetadataLabels(
    graphData.projectPlatformSupport,
  );
  if (projectMetadataLabels.isNotEmpty) {
    _writeMetadataPills(
      buffer,
      centerX: width / _halfDivisor,
      topY: _projectMetadataPillY,
      labels: projectMetadataLabels,
    );
  }

  writeSectionHeader(
    buffer,
    x: leftX,
    y: _headerHeight,
    title: AppStrings.packageDependenciesTitle,
    color: _dependencyStrokeColor,
    count: dependencies.length,
  );
  writeSectionHeader(
    buffer,
    x: rightX,
    y: _headerHeight,
    title: AppStrings.packageDevDependenciesTitle,
    color: _devDependencyStrokeColor,
    count: devDependencies.length,
  );

  for (
    var layerIndex = 0;
    layerIndex < uniquePackagesByLayer.length;
    layerIndex++
  ) {
    final layerPackages = uniquePackagesByLayer[layerIndex];
    if (layerPackages.isEmpty) {
      continue;
    }
    final depthLevel = layerIndex + 1;
    writeDerivedSectionHeader(
      buffer,
      sectionX: _canvasPadding,
      sectionY: layerTopYs[layerIndex],
      sectionWidth: width - (_canvasPadding * _columnCount),
      title: 'Derived packages (Depth $depthLevel)',
      count: layerPackages.length,
    );
  }

  // Draw edges before nodes so nodes render on top
  writeColumnEdges(
    buffer,
    x: leftX,
    packages: dependencies,
    derivedMap: derivedMap,
    derivedPositions: layerPositions[_firstDependencyLayerIndex],
    columnsTopY: columnsTopY,
    isLeftColumn: true,
    platformSupportByPackage: platformSupportByPackage,
    rightIncomingCounts: visibleRightIncomingCounts,
    outgoingCounts: layerNodeOutgoingCounts[_firstDependencyLayerIndex],
  );
  writeColumnEdges(
    buffer,
    x: rightX,
    packages: devDependencies,
    derivedMap: derivedMap,
    derivedPositions: layerPositions[_firstDependencyLayerIndex],
    columnsTopY: columnsTopY,
    isLeftColumn: false,
    platformSupportByPackage: platformSupportByPackage,
    rightIncomingCounts: visibleRightIncomingCounts,
    outgoingCounts: layerNodeOutgoingCounts[_firstDependencyLayerIndex],
  );
  for (
    var layerIndex = _nextDependencyLayerStartIndex;
    layerIndex < uniquePackagesByLayer.length;
    layerIndex++
  ) {
    writeDerivedLevelEdges(
      buffer,
      derivedMap: dependencyLayerMaps[layerIndex],
      sourcePositions: layerPositions[layerIndex - 1],
      targetPositions: layerPositions[layerIndex],
      rightIncomingCounts: layerRightIncomingCounts[layerIndex - 1],
      sourceNodeWidth: _derivedNodeWidth,
      platformSupportByPackage: platformSupportByPackage,
    );
  }

  // Draw direct package nodes
  writeDirectColumn(
    buffer,
    x: leftX,
    packages: dependencies,
    fillColor: _dependencyFillColor,
    strokeColor: _dependencyStrokeColor,
    startY: columnsTopY,
    outgoingCounts: visibleDirectOutgoingCounts,
    outgoingPeers: visibleDirectOutgoingPeers,
    nodeWidth: _nodeWidth,
    isLeftColumn: true,
    platformSupportByPackage: platformSupportByPackage,
  );
  writeDirectColumn(
    buffer,
    x: rightX,
    packages: devDependencies,
    fillColor: _devDependencyFillColor,
    strokeColor: _devDependencyStrokeColor,
    startY: columnsTopY,
    outgoingCounts: visibleDirectOutgoingCounts,
    outgoingPeers: visibleDirectOutgoingPeers,
    nodeWidth: _nodeWidth,
    isLeftColumn: false,
    platformSupportByPackage: platformSupportByPackage,
  );

  // Draw derived and transitive nodes inside each section.
  for (
    var layerIndex = 0;
    layerIndex < uniquePackagesByLayer.length;
    layerIndex++
  ) {
    final layerPackages = uniquePackagesByLayer[layerIndex];
    if (layerPackages.isEmpty) {
      continue;
    }
    writeDerivedNodes(
      buffer,
      uniqueDerived: layerPackages,
      derivedPositions: layerPositions[layerIndex],
      leftIncomingCounts: layerIndex == _firstDependencyLayerIndex
          ? visibleLeftIncomingCounts
          : const <String, int>{},
      leftIncomingPeers: layerIndex == _firstDependencyLayerIndex
          ? visibleLeftIncomingPeers
          : const <String, List<String>>{},
      rightIncomingCounts: layerRightIncomingCounts[layerIndex],
      rightIncomingPeers: layerRightIncomingPeers[layerIndex],
      outgoingCounts: layerNodeOutgoingCounts[layerIndex],
      outgoingPeers: layerNodeOutgoingPeers[layerIndex],
      nodeWidth: _derivedNodeWidth,
      platformSupportByPackage: platformSupportByPackage,
    );
  }

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}
