import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:fcheck/src/exports/svg/shared/svg_styles.dart';
import 'package:yaml/yaml.dart';

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
const double _nodeHeight = 46;
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
const double _sectionUnderlineOffset = 6;
const double _nodeNameYOffset = 20;
const double _nodeVersionYOffset = 33;
const double _packageSlotSpacing = 20;
const double _sectionHeaderHeight = 26;
const double _sectionToNodesGap = 12;
const double _derivedNodeWidth = 280;
const double _derivedNodeHeight = 28;
const double _derivedNodeNameFontSize = 12;
const double _derivedNameYOffset = 18;
const double _derivedColumnSpacing = 12;
const double _derivedRowSpacing = 12;
const double _derivedGroupTopMargin = 48;
const double _derivedGroupLabelFontSize = 13;
const double _derivedGroupLabelY = 20;
const double _derivedNodeTextPadding = 8;
const double _badgeOffset = 12;

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

/// Package node info with resolved version.
typedef PackageDependencyNode = ({String name, String version});

/// Package dependency graph values parsed from `pubspec.yaml`.
class PackageDependencyGraphData {
  /// Project/package name owning the dependency graph.
  final String projectName;

  /// Project/package version from `pubspec.yaml`.
  final String version;

  /// Regular dependencies from `dependencies`.
  final List<PackageDependencyNode> dependencies;

  /// Development dependencies from `dev_dependencies`.
  final List<PackageDependencyNode> devDependencies;

  /// One-hop derived dependencies keyed by direct package name.
  final Map<String, List<PackageDependencyNode>> derivedDependenciesByPackage;

  /// Reverse dependency counts: how many packages in the full tree depend on each package.
  final Map<String, int> reverseDepCounts;

  /// Outgoing dependency counts: for each package, how many packages it depends on.
  final Map<String, int> outgoingDepCounts;

  /// Creates package dependency graph data.
  const PackageDependencyGraphData({
    required this.projectName,
    required this.version,
    required this.dependencies,
    required this.devDependencies,
    this.derivedDependenciesByPackage =
        const <String, List<PackageDependencyNode>>{},
    this.reverseDepCounts = const <String, int>{},
    this.outgoingDepCounts = const <String, int>{},
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

    return PackageDependencyGraphData(
      projectName: projectName,
      version: version,
      dependencies: dependencies,
      devDependencies: devDependencies,
      derivedDependenciesByPackage: derivedData.derivedByPackage,
      reverseDepCounts: derivedData.reverseDepCounts,
      outgoingDepCounts: derivedData.outgoingDepCounts,
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
      reverseDepCounts: <String, int>{},
      outgoingDepCounts: <String, int>{},
    );
  }

  try {
    final parsed = jsonDecode(result.stdout as String);
    if (parsed is! Map<String, dynamic>) {
      return (
        derivedByPackage: <String, List<PackageDependencyNode>>{},
        reverseDepCounts: <String, int>{},
        outgoingDepCounts: <String, int>{},
      );
    }
    final packages = parsed[_pubDepsPackagesKey];
    if (packages is! List<dynamic>) {
      return (
        derivedByPackage: <String, List<PackageDependencyNode>>{},
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
      reverseDepCounts: reverseDepCounts,
      outgoingDepCounts: outgoingDepCounts,
    );
  } catch (_) {
    return (
      derivedByPackage: <String, List<PackageDependencyNode>>{},
      reverseDepCounts: <String, int>{},
      outgoingDepCounts: <String, int>{},
    );
  }
}

/// Builds SVG for Flutter/Dart package dependencies and dev_dependencies.
///
/// The layout renders direct packages in two columns (dependencies left,
/// dev_dependencies right) at the top, followed by a grouped container of all
/// unique derived (transitive) packages at the bottom. Lines connect each
/// direct package node to the derived packages it depends on.
String exportSvgPackageDependencies(PackageDependencyGraphData graphData) {
  final dependencies = graphData.dependencies;
  final devDependencies = graphData.devDependencies;
  if (dependencies.isEmpty && devDependencies.isEmpty) {
    return generateEmptySvg('No package dependencies found');
  }

  final derivedMap = graphData.derivedDependenciesByPackage;
  final uniqueDerived = collectUniqueDerived(derivedMap);

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
  final derivedRows = uniqueDerived.isEmpty
      ? 0
      : (uniqueDerived.length + derivedNodesPerRow - 1) ~/ derivedNodesPerRow;
  final derivedGridHeight = derivedRows == 0
      ? 0.0
      : derivedRows * _derivedNodeHeight +
            (derivedRows - 1) * _derivedRowSpacing;
  final derivedSectionHeight = uniqueDerived.isEmpty
      ? 0.0
      : _sectionHeaderHeight + _sectionToNodesGap + derivedGridHeight;

  final columnsTopY = _headerHeight + _sectionHeaderHeight + _sectionToNodesGap;
  final derivedGroupTopY =
      columnsTopY +
      directColumnHeight +
      (uniqueDerived.isEmpty ? 0 : _derivedGroupTopMargin);
  final height = derivedGroupTopY + derivedSectionHeight + _canvasPadding;

  final leftX = (width - directColumnsWidth) / _halfDivisor;
  final rightX = leftX + _nodeWidth + _columnGap;
  final derivedNodesStartX = _canvasPadding;
  final derivedNodesStartY =
      derivedGroupTopY + _sectionHeaderHeight + _sectionToNodesGap;

  final derivedPositions = computeDerivedPositions(
    uniqueDerived,
    derivedNodesPerRow,
    startX: derivedNodesStartX,
    startY: derivedNodesStartY,
    innerWidth: derivedInnerWidth,
  );

  // Count only edges that are visible in this diagram.
  final visibleDirectOutgoingCounts = buildVisibleDirectOutgoingCounts(
    derivedMap,
  );
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

  buffer.writeln(
    '<text x="${width / _halfDivisor}" y="$_titleY" text-anchor="middle" fill="$_titleTextColor" font-size="$_titleFontSize" font-weight="700">${escapeXml(graphData.projectName)} v${escapeXml(graphData.version)}</text>',
  );

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
      count: uniqueDerived.length,
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
  );

  // Draw derived nodes inside group
  if (uniqueDerived.isNotEmpty) {
    writeDerivedNodes(
      buffer,
      uniqueDerived: uniqueDerived,
      derivedPositions: derivedPositions,
      leftIncomingCounts: visibleLeftIncomingCounts,
      rightIncomingCounts: visibleRightIncomingCounts,
      nodeWidth: _derivedNodeWidth,
    );
  }

  writeSvgDocumentEnd(buffer);
  return buffer.toString();
}

/// Collects all unique derived packages across all direct packages, sorted by name.
List<PackageDependencyNode> collectUniqueDerived(
  Map<String, List<PackageDependencyNode>> derivedMap,
) {
  final seen = <String>{};
  final result = <PackageDependencyNode>[];
  for (final nodeList in derivedMap.values) {
    for (final node in nodeList) {
      if (seen.add(node.name)) {
        result.add(node);
      }
    }
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

/// Counts visible direct-to-derived edges for each direct package.
Map<String, int> buildVisibleDirectOutgoingCounts(
  Map<String, List<PackageDependencyNode>> derivedMap,
) {
  final counts = <String, int>{};
  derivedMap.forEach((packageName, derivedPackages) {
    counts[packageName] = derivedPackages.length;
  });
  return counts;
}

/// Counts visible incoming edges for each derived package.
Map<String, int> buildVisibleDerivedIncomingCounts(
  Map<String, List<PackageDependencyNode>> derivedMap, {
  required Set<String> sourcePackageNames,
}) {
  final counts = <String, int>{};
  derivedMap.forEach((packageName, derivedPackages) {
    if (!sourcePackageNames.contains(packageName)) {
      return;
    }
    for (final derivedPackage in derivedPackages) {
      counts[derivedPackage.name] = (counts[derivedPackage.name] ?? 0) + 1;
    }
  });
  return counts;
}

/// Computes how many derived nodes fit in a row.
///
/// Derived packages are intentionally rendered as a single vertical column.
int computeDerivedNodesPerRow(double _) {
  return _singleDerivedColumnCount;
}

/// Computes the pixel position of each derived package node, centred in rows.
Map<String, ({double x, double y})> computeDerivedPositions(
  List<PackageDependencyNode> uniqueDerived,
  int nodesPerRow, {
  required double startX,
  required double startY,
  required double innerWidth,
}) {
  final result = <String, ({double x, double y})>{};
  for (var i = 0; i < uniqueDerived.length; i++) {
    final row = i ~/ nodesPerRow;
    final col = i % nodesPerRow;
    final remaining = uniqueDerived.length - row * nodesPerRow;
    final rowNodes = remaining > nodesPerRow ? nodesPerRow : remaining;
    final rowWidth =
        rowNodes * _derivedNodeWidth + (rowNodes - 1) * _derivedColumnSpacing;
    final rowStartX = startX + (innerWidth - rowWidth) / _halfDivisor;
    final x = rowStartX + col * (_derivedNodeWidth + _derivedColumnSpacing);
    final y = startY + row * (_derivedNodeHeight + _derivedRowSpacing);
    result[uniqueDerived[i].name] = (x: x, y: y);
  }
  return result;
}

/// Draws edges from each direct package node to its derived package nodes.
/// For left column, edges exit from the left edge; for right column, from the right edge.
void writeColumnEdges(
  StringBuffer buffer, {
  required double x,
  required List<PackageDependencyNode> packages,
  required Map<String, List<PackageDependencyNode>> derivedMap,
  required Map<String, ({double x, double y})> derivedPositions,
  required double columnsTopY,
  required bool isLeftColumn,
}) {
  for (var i = 0; i < packages.length; i++) {
    final pkg = packages[i];
    final pkgStartX = isLeftColumn ? x : x + _nodeWidth;
    final pkgCenterY =
        columnsTopY +
        i * (_nodeHeight + _packageSlotSpacing) +
        (_nodeHeight / _halfDivisor);
    final derived = derivedMap[pkg.name] ?? const <PackageDependencyNode>[];
    for (final derivedPkg in derived) {
      final pos = derivedPositions[derivedPkg.name];
      if (pos == null) {
        continue;
      }
      final derivedEndX = isLeftColumn ? pos.x : pos.x + _derivedNodeWidth;
      final derivedCenterY = pos.y + (_derivedNodeHeight / _halfDivisor);
      final pathData = buildBezierEdgePath(
        pkgStartX,
        pkgCenterY,
        derivedEndX,
        derivedCenterY,
        isLeftExit: isLeftColumn,
        isLeftArrival: isLeftColumn,
      );
      writeEdge(
        buffer,
        pathData: pathData,
        title:
            '${escapeXml(pkg.name)} -> ${escapeXml(derivedPkg.name)} v${escapeXml(derivedPkg.version)}',
      );
    }
  }
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
      nameFontSize: _nodeTextFontSize,
      versionFontSize: _nodeVersionFontSize,
      node: package,
      fillColor: fillColor,
      strokeColor: strokeColor,
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
  required int count,
}) {
  final plural = count == _singleEntryCount ? '' : 's';
  buffer.writeln(
    '<text x="${sectionX + (sectionWidth / _halfDivisor)}" y="${sectionY + _derivedGroupLabelY}" text-anchor="middle" fill="$_derivedGroupLabelColor" font-size="$_derivedGroupLabelFontSize" font-weight="700">Derived packages ($count item$plural)</text>',
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
  required double nodeWidth,
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
      nameFontSize: _derivedNodeNameFontSize,
      versionFontSize: 0,
      node: node,
      fillColor: _derivedNodeFillColor,
      strokeColor: _derivedNodeStrokeColor,
      strokeDashArray: _derivedNodeDashArray,
      inlineVersion: true,
    );

    // Render badges
    final leftInCount = leftIncomingCounts[node.name] ?? 0;
    final rightInCount = rightIncomingCounts[node.name] ?? 0;

    if (leftInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x,
        cy: pos.y + _derivedNodeHeight / _halfDivisor,
        count: leftInCount,
        direction: BadgeDirection.east,
      );
      buffer.writeln(incomingBadge.renderSvg());
    }

    // Right badge (incoming count) - use west to point RIGHT
    if (rightInCount > 0) {
      final incomingBadge = BadgeModel.incoming(
        cx: pos.x + nodeWidth,
        cy: pos.y + _derivedNodeHeight / _halfDivisor,
        count: rightInCount,
        direction: BadgeDirection.west,
      );
      buffer.writeln(incomingBadge.renderSvg());
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
    '<text x="$x" y="$y" fill="$_sectionTextColor" font-size="$_sectionFontSize" font-weight="700">$title ($count item$plural)</text>',
  );
  buffer.writeln(
    '<line x1="$x" y1="${y + _sectionUnderlineOffset}" x2="${x + _nodeWidth}" y2="${y + _sectionUnderlineOffset}" stroke="$color" stroke-width="$_edgeStrokeWidth" opacity="$_edgeOpacity"/>',
  );
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
  required double nameFontSize,
  required double versionFontSize,
  required PackageDependencyNode node,
  required String fillColor,
  required String strokeColor,
  String strokeDashArray = '',
  bool inlineVersion = false,
}) {
  final dashAttr = strokeDashArray.isNotEmpty
      ? ' stroke-dasharray="$strokeDashArray"'
      : '';
  buffer.writeln(
    '<rect x="$x" y="$y" width="$nodeWidth" height="$nodeHeight" rx="$_cornerRadius" ry="$_cornerRadius" fill="$fillColor" stroke="$strokeColor" stroke-width="1"$dashAttr/>',
  );
  if (inlineVersion) {
    // Render name on left and version on right with gray styling.
    // Only add ^ if version is a plain semver (starts with digit).
    final escapedName = escapeXml(node.name);
    final escapedVersion = escapeXml(node.version);
    final versionDisplay = escapedVersion.startsWith(RegExp(r'[0-9]'))
        ? '^$escapedVersion'
        : escapedVersion;

    // Render package name on the left
    buffer.writeln(
      '<text x="${x + _derivedNodeTextPadding}" y="${y + nameYOffset}" text-anchor="start" fill="$_titleTextColor" font-size="$nameFontSize">$escapedName</text>',
    );
    // Render version on the right in gray
    buffer.writeln(
      '<text x="${x + nodeWidth - _derivedNodeTextPadding}" y="${y + nameYOffset}" text-anchor="end" fill="$_versionTextColor" font-size="$nameFontSize">$versionDisplay</text>',
    );
  } else {
    // Render name and version on separate lines
    buffer.writeln(
      '<text x="${x + (nodeWidth / _halfDivisor)}" y="${y + nameYOffset}" text-anchor="middle" fill="$_titleTextColor" font-size="$nameFontSize">${escapeXml(node.name)}</text>',
    );
    buffer.writeln(
      '<text x="${x + (nodeWidth / _halfDivisor)}" y="${y + versionYOffset}" text-anchor="middle" fill="$_versionTextColor" font-size="$versionFontSize">v${escapeXml(node.version)}</text>',
    );
  }
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
