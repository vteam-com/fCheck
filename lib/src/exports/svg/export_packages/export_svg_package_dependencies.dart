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

/// Returns the vertical anchors for the right-side derived badges.
///
/// When a derived node shows both a right incoming badge and a right outgoing
/// badge, the badges are stacked vertically and any outgoing edge must reuse
/// the same outgoing anchor to stay visually aligned with the green badge.
({double incomingY, double outgoingY}) _computeDerivedRightBadgeAnchors({
  required double nodeCenterY,
  required int rightIncomingCount,
  required int outgoingCount,
}) {
  final hasStackedRightBadges = rightIncomingCount > 0 && outgoingCount > 0;
  return (
    incomingY:
        nodeCenterY -
        (hasStackedRightBadges ? _derivedRightIncomingBadgeOffsetY : 0),
    outgoingY:
        nodeCenterY +
        (hasStackedRightBadges ? _derivedRightOutgoingBadgeOffsetY : 0),
  );
}

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
const String _derivedPackagesSectionTitle = 'Derived packages';
const String _transitivePackagesSectionTitle = 'Transitive packages';

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
        reverseDepCounts: <String, int>{},
        outgoingDepCounts: <String, int>{},
      );
    }
    final packages = parsed[_pubDepsPackagesKey];
    if (packages is! List<dynamic>) {
      return (
        derivedByPackage: <String, List<PackageDependencyNode>>{},
        nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
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

    final nestedDerivedByPackage = <String, List<PackageDependencyNode>>{};
    final secondLevelPackageNames = derivedByPackage.values
        .expand((nodeList) => nodeList.map((node) => node.name))
        .toSet();
    final sortedSecondLevelPackageNames = secondLevelPackageNames.toList()
      ..sort();

    for (final secondLevelPackageName in sortedSecondLevelPackageNames) {
      final packageData = pubDepsPackages[secondLevelPackageName];
      if (packageData == null) {
        continue;
      }

      final nestedDerivedNames =
          packageData.dependencies
              .where(
                (dependencyName) =>
                    dependencyName != secondLevelPackageName &&
                    !rootPackageNames.contains(dependencyName) &&
                    !secondLevelPackageNames.contains(dependencyName),
              )
              .toSet()
              .toList()
            ..sort();

      final nestedDerivedNodes = nestedDerivedNames
          .map(
            (nestedDerivedName) => (
              name: nestedDerivedName,
              version:
                  pubDepsPackages[nestedDerivedName]?.version ??
                  packageVersions[nestedDerivedName] ??
                  _unknownPackageVersion,
            ),
          )
          .toList(growable: false);

      if (nestedDerivedNodes.isNotEmpty) {
        nestedDerivedByPackage[secondLevelPackageName] = nestedDerivedNodes;
      }
    }

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
      reverseDepCounts: reverseDepCounts,
      outgoingDepCounts: outgoingDepCounts,
    );
  } catch (_) {
    return (
      derivedByPackage: <String, List<PackageDependencyNode>>{},
      nestedDerivedByPackage: <String, List<PackageDependencyNode>>{},
      reverseDepCounts: <String, int>{},
      outgoingDepCounts: <String, int>{},
    );
  }
}

/// Builds SVG for Flutter/Dart package dependencies and dev_dependencies.
///
/// The layout renders direct packages in two columns (dependencies left,
/// dev_dependencies right) at the top, followed by grouped containers for the
/// next two dependency hops. Lines connect each direct package node to its
/// first derived packages, then connect first derived packages to the next hop.
String exportSvgPackageDependencies(PackageDependencyGraphData graphData) {
  final dependencies = graphData.dependencies;
  final devDependencies = graphData.devDependencies;
  if (dependencies.isEmpty && devDependencies.isEmpty) {
    return generateEmptySvg('No package dependencies found');
  }

  final derivedMap = graphData.derivedDependenciesByPackage;
  final uniqueDerived = collectUniqueDerived(derivedMap);
  final nestedDerivedMap = graphData.nestedDerivedDependenciesByPackage;
  final uniqueNestedDerived = collectUniqueDerived(nestedDerivedMap);

  final maxSlots = dependencies.length > devDependencies.length
      ? dependencies.length
      : devDependencies.length;
  final directColumnHeight = maxSlots > 0
      ? maxSlots * _nodeHeight + (maxSlots - 1) * _packageSlotSpacing
      : 0.0;

  final directColumnsWidth = (_nodeWidth * _columnCount) + _columnGap;
  final width =
      (_canvasPadding * _columnCount) +
      (_canvasExtraWidth * _columnCount) +
      directColumnsWidth;
  final derivedInnerWidth = width - (_canvasPadding * _columnCount);
  final derivedNodesPerRow = computeDerivedNodesPerRow(derivedInnerWidth);
  final derivedRows = computePackageLevelRowCount(
    uniqueDerived.length,
    derivedNodesPerRow,
  );
  final derivedSectionHeight = computePackageLevelSectionHeight(derivedRows);
  final nestedDerivedNodesPerRow = computeDerivedNodesPerRow(derivedInnerWidth);
  final nestedDerivedRows = computePackageLevelRowCount(
    uniqueNestedDerived.length,
    nestedDerivedNodesPerRow,
  );
  final nestedDerivedSectionHeight = computePackageLevelSectionHeight(
    nestedDerivedRows,
  );

  final columnsTopY = _headerHeight + _sectionHeaderHeight + _sectionToNodesGap;
  var contentBottomY = columnsTopY + directColumnHeight;
  var derivedGroupTopY = contentBottomY;
  if (uniqueDerived.isNotEmpty) {
    derivedGroupTopY = contentBottomY + _derivedGroupTopMargin;
    contentBottomY = derivedGroupTopY + derivedSectionHeight;
  }
  var nestedDerivedGroupTopY = contentBottomY;
  if (uniqueNestedDerived.isNotEmpty) {
    nestedDerivedGroupTopY = contentBottomY + _derivedGroupTopMargin;
    contentBottomY = nestedDerivedGroupTopY + nestedDerivedSectionHeight;
  }
  final height = contentBottomY + _canvasPadding;

  final leftX = (width - directColumnsWidth) / _halfDivisor;
  final rightX = leftX + _nodeWidth + _columnGap;
  final derivedNodesStartX = _canvasPadding;
  final derivedNodesStartY =
      derivedGroupTopY + _sectionHeaderHeight + _sectionToNodesGap;
  final nestedDerivedNodesStartY =
      nestedDerivedGroupTopY + _sectionHeaderHeight + _sectionToNodesGap;

  final derivedPositions = computeDerivedPositions(
    uniqueDerived,
    derivedNodesPerRow,
    startX: derivedNodesStartX,
    startY: derivedNodesStartY,
    innerWidth: derivedInnerWidth,
  );
  final nestedDerivedPositions = computeDerivedPositions(
    uniqueNestedDerived,
    nestedDerivedNodesPerRow,
    startX: derivedNodesStartX,
    startY: nestedDerivedNodesStartY,
    innerWidth: derivedInnerWidth,
  );

  // Count only edges that are visible in this diagram.
  final visibleDirectOutgoingCounts = buildVisibleOutgoingCounts(derivedMap);
  final dependencyNames = dependencies.map((package) => package.name).toSet();
  final devDependencyNames = devDependencies
      .map((package) => package.name)
      .toSet();
  final visibleLeftIncomingCounts = buildVisibleDerivedIncomingCounts(
    derivedMap,
    sourcePackageNames: dependencyNames,
  );
  final visibleRightIncomingCounts = buildVisibleDerivedIncomingCounts(
    derivedMap,
    sourcePackageNames: devDependencyNames,
  );
  final derivedPackageNames = uniqueDerived
      .map((package) => package.name)
      .toSet();
  final visibleDerivedOutgoingCounts = buildVisibleOutgoingCounts(
    nestedDerivedMap,
  );
  final visibleTransitiveIncomingCounts = buildVisibleDerivedIncomingCounts(
    nestedDerivedMap,
    sourcePackageNames: derivedPackageNames,
  );
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
    title: 'dependencies',
    color: _dependencyStrokeColor,
    count: dependencies.length,
  );
  writeSectionHeader(
    buffer,
    x: rightX,
    y: _headerHeight,
    title: 'dev_dependencies',
    color: _devDependencyStrokeColor,
    count: devDependencies.length,
  );

  // Draw derived section header.
  if (uniqueDerived.isNotEmpty) {
    writeDerivedSectionHeader(
      buffer,
      sectionX: _canvasPadding,
      sectionY: derivedGroupTopY,
      sectionWidth: width - (_canvasPadding * _columnCount),
      title: _derivedPackagesSectionTitle,
      count: uniqueDerived.length,
    );
  }
  if (uniqueNestedDerived.isNotEmpty) {
    writeDerivedSectionHeader(
      buffer,
      sectionX: _canvasPadding,
      sectionY: nestedDerivedGroupTopY,
      sectionWidth: width - (_canvasPadding * _columnCount),
      title: _transitivePackagesSectionTitle,
      count: uniqueNestedDerived.length,
    );
  }

  // Draw edges before nodes so nodes render on top
  writeColumnEdges(
    buffer,
    x: leftX,
    packages: dependencies,
    derivedMap: derivedMap,
    derivedPositions: derivedPositions,
    columnsTopY: columnsTopY,
    isLeftColumn: true,
  );
  writeColumnEdges(
    buffer,
    x: rightX,
    packages: devDependencies,
    derivedMap: derivedMap,
    derivedPositions: derivedPositions,
    columnsTopY: columnsTopY,
    isLeftColumn: false,
  );
  writeDerivedLevelEdges(
    buffer,
    derivedMap: nestedDerivedMap,
    sourcePositions: derivedPositions,
    targetPositions: nestedDerivedPositions,
    rightIncomingCounts: visibleRightIncomingCounts,
    sourceNodeWidth: _derivedNodeWidth,
  );

  // Draw direct package nodes
  writeDirectColumn(
    buffer,
    x: leftX,
    packages: dependencies,
    fillColor: _dependencyFillColor,
    strokeColor: _dependencyStrokeColor,
    startY: columnsTopY,
    outgoingCounts: visibleDirectOutgoingCounts,
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
    nodeWidth: _nodeWidth,
    isLeftColumn: false,
    platformSupportByPackage: platformSupportByPackage,
  );

  // Draw derived nodes inside group
  if (uniqueDerived.isNotEmpty) {
    writeDerivedNodes(
      buffer,
      uniqueDerived: uniqueDerived,
      derivedPositions: derivedPositions,
      leftIncomingCounts: visibleLeftIncomingCounts,
      rightIncomingCounts: visibleRightIncomingCounts,
      outgoingCounts: visibleDerivedOutgoingCounts,
      nodeWidth: _derivedNodeWidth,
      platformSupportByPackage: platformSupportByPackage,
    );
  }
  if (uniqueNestedDerived.isNotEmpty) {
    writeDerivedNodes(
      buffer,
      uniqueDerived: uniqueNestedDerived,
      derivedPositions: nestedDerivedPositions,
      leftIncomingCounts: const <String, int>{},
      rightIncomingCounts: visibleTransitiveIncomingCounts,
      outgoingCounts: const <String, int>{},
      nodeWidth: _derivedNodeWidth,
      platformSupportByPackage: platformSupportByPackage,
    );
  }

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}

/// Renders all direct package nodes in a single column.
void writeDirectColumn(
  StringBuffer buffer, {
  required double x,
  required List<PackageDependencyNode> packages,
  required String fillColor,
  required String strokeColor,
  required double startY,
  required Map<String, int> outgoingCounts,
  required double nodeWidth,
  required bool isLeftColumn,
  required Map<String, PackagePlatformSupport> platformSupportByPackage,
}) {
  for (var i = 0; i < packages.length; i++) {
    final y = startY + i * (_nodeHeight + _packageSlotSpacing);
    final package = packages[i];

    writePackageNodeSvg(
      buffer,
      x: x,
      y: y,
      nodeWidth: nodeWidth,
      nodeHeight: _nodeHeight,
      nameYOffset: _nodeNameYOffset,
      versionYOffset: _nodeVersionYOffset,
      node: package,
      fillColor: fillColor,
      strokeColor: strokeColor,
      platformSupport: platformSupportByPackage[package.name],
    );

    // Render badges
    final outCount = outgoingCounts[package.name] ?? 0;

    if (outCount > 0) {
      final badgeCx = isLeftColumn ? x : x + nodeWidth;
      final badgeDirection = isLeftColumn
          ? BadgeDirection.west
          : BadgeDirection.east;
      final outgoingBadge = BadgeModel.outgoing(
        cx: badgeCx,
        cy: y + _nodeHeight / _halfDivisor,
        count: outCount,
        direction: badgeDirection,
      );
      buffer.writeln(outgoingBadge.renderSvg());
    }
  }
}

/// Renders the derived package section header without a surrounding container.
void writeDerivedSectionHeader(
  StringBuffer buffer, {
  required double sectionX,
  required double sectionY,
  required double sectionWidth,
  required String title,
  required int count,
}) {
  final plural = count == _singleEntryCount ? '' : 's';
  buffer.writeln(
    '<text x="${sectionX + (sectionWidth / _halfDivisor)}" y="${sectionY + _derivedGroupLabelY}" class="$_packageDerivedSectionLabelClass" text-anchor="middle">$title ($count item$plural)</text>',
  );
  buffer.writeln(
    '<line x1="$sectionX" y1="${sectionY + _sectionHeaderHeight}" x2="${sectionX + sectionWidth}" y2="${sectionY + _sectionHeaderHeight}" stroke="$_derivedNodeStrokeColor" stroke-width="1" opacity="0.35"/>',
  );
}

/// Renders the derived package nodes inside the group container.
void writeDerivedNodes(
  StringBuffer buffer, {
  required List<PackageDependencyNode> uniqueDerived,
  required Map<String, ({double x, double y})> derivedPositions,
  required Map<String, int> leftIncomingCounts,
  required Map<String, int> rightIncomingCounts,
  required Map<String, int> outgoingCounts,
  required double nodeWidth,
  required Map<String, PackagePlatformSupport> platformSupportByPackage,
}) {
  for (final node in uniqueDerived) {
    final pos = derivedPositions[node.name];
    if (pos == null) {
      continue;
    }
    writePackageNodeSvg(
      buffer,
      x: pos.x,
      y: pos.y,
      nodeWidth: nodeWidth,
      nodeHeight: _derivedNodeHeight,
      nameYOffset: _derivedNameYOffset,
      versionYOffset: 0,
      node: node,
      fillColor: _derivedNodeFillColor,
      strokeColor: _derivedNodeStrokeColor,
      strokeDashArray: _derivedNodeDashArray,
      inlineVersion: true,
      platformSupport: platformSupportByPackage[node.name],
    );

    // Render badges
    final leftInCount = leftIncomingCounts[node.name] ?? 0;
    final rightInCount = rightIncomingCounts[node.name] ?? 0;
    final outCount = outgoingCounts[node.name] ?? 0;
    final badgeCenterY = pos.y + _derivedNodeHeight / _halfDivisor;
    final rightBadgeAnchors = _computeDerivedRightBadgeAnchors(
      nodeCenterY: badgeCenterY,
      rightIncomingCount: rightInCount,
      outgoingCount: outCount,
    );

    if (leftInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x,
        cy: badgeCenterY,
        count: leftInCount,
        direction: BadgeDirection.east,
      );
      buffer.writeln(incomingBadge.renderSvg());
    }

    // Right badge (incoming count) - use west to point RIGHT
    if (rightInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x + nodeWidth,
        cy: rightBadgeAnchors.incomingY,
        count: rightInCount,
        direction: BadgeDirection.west,
      );
      buffer.writeln(incomingBadge.renderSvg());
    }

    if (outCount > 0) {
      final outgoingBadge = BadgeModel.outgoing(
        cx: pos.x + nodeWidth,
        cy: rightBadgeAnchors.outgoingY,
        count: outCount,
        direction: BadgeDirection.east,
      );
      buffer.writeln(outgoingBadge.renderSvg());
    }
  }
}

/// Writes a section header to [buffer] at position ([x], [y]).
///
/// Renders a title with item count and an underline in the specified [color].
void writeSectionHeader(
  StringBuffer buffer, {
  required double x,
  required double y,
  required String title,
  required String color,
  required int count,
}) {
  final plural = count == _singleEntryCount ? '' : 's';
  buffer.writeln(
    '<text x="$x" y="$y" class="$_packageSectionLabelClass">$title ($count item$plural)</text>',
  );
  buffer.writeln(
    '<line x1="$x" y1="${y + _sectionUnderlineOffset}" x2="${x + _nodeWidth}" y2="${y + _sectionUnderlineOffset}" stroke="$color" stroke-width="$_edgeStrokeWidth" opacity="$_edgeOpacity"/>',
  );
}

/// Renders an SVG edge with Bezier curve routing and tooltip.
///
/// Uses the unified `.edgeVertical` CSS class for consistent gradient and
/// hover effects across all SVG diagrams. The edge path is routed with a
/// smooth cubic Bezier curve (see [buildBezierEdgePath]) to create visual
/// clarity and improve readability.
void writeEdge(
  StringBuffer buffer, {
  required String pathData,
  required String title,
}) {
  renderEdgeWithTooltip(
    buffer,
    pathData: pathData,
    source: '',
    target: '',
    cssClass: 'edgeVertical',
    pathStyle: null,
  );
  buffer.writeln('<title>$title</title>');
}
