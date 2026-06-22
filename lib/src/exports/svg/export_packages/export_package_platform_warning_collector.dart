import 'package:fcheck/src/exports/svg/export_packages/export_svg_package_dependencies.dart';
import 'package:fcheck/src/models/package_platform_warning.dart';

/// Collects all packages with platform warnings (e.g., legacy iOS CocoaPods support)
/// from the dependency graph, tracking their source dependency relationship.
///
/// Returns a sorted list of [PackagePlatformWarning] with no duplicates.
List<PackagePlatformWarning> collectPackagePlatformWarnings(
  PackageDependencyGraphData graphData,
) {
  final warnings = <String, PackagePlatformWarning>{};
  final visitedPackages = <String>{};

  // Collect direct dependencies as source references for transitive tracking
  final directPackages = {
    ...graphData.dependencies.map((p) => p.name),
    ...graphData.devDependencies.map((p) => p.name),
  };

  // Layer 1: Direct dependencies
  for (final package in graphData.dependencies) {
    _checkPackageWarning(
      packageName: package.name,
      version: package.version,
      introducedBy: null,
      graphData: graphData,
      warnings: warnings,
      visitedPackages: visitedPackages,
    );
  }

  for (final package in graphData.devDependencies) {
    _checkPackageWarning(
      packageName: package.name,
      version: package.version,
      introducedBy: null,
      graphData: graphData,
      warnings: warnings,
      visitedPackages: visitedPackages,
    );
  }

  // Layer 2: Derived dependencies (1-hop)
  for (final directPkg in directPackages) {
    final derived = graphData.derivedDependenciesByPackage[directPkg];
    if (derived != null) {
      for (final package in derived) {
        _checkPackageWarning(
          packageName: package.name,
          version: package.version,
          introducedBy: directPkg,
          graphData: graphData,
          warnings: warnings,
          visitedPackages: visitedPackages,
        );
      }
    }
  }

  // Layer 3: Nested derived dependencies (2-hop)
  for (final directPkg in directPackages) {
    final nested = graphData.nestedDerivedDependenciesByPackage[directPkg];
    if (nested != null) {
      for (final package in nested) {
        _checkPackageWarning(
          packageName: package.name,
          version: package.version,
          introducedBy: directPkg,
          graphData: graphData,
          warnings: warnings,
          visitedPackages: visitedPackages,
        );
      }
    }
  }

  // Layer 4: Transitive dependencies (3+ hops)
  // transitiveDependencyLayersByParentPackage is a List<Map<String, List<PackageDependencyNode>>>
  for (final layerMap in graphData.transitiveDependencyLayersByParentPackage) {
    for (final directPkg in directPackages) {
      final transitive = layerMap[directPkg];
      if (transitive != null) {
        for (final package in transitive) {
          _checkPackageWarning(
            packageName: package.name,
            version: package.version,
            introducedBy: directPkg,
            graphData: graphData,
            warnings: warnings,
            visitedPackages: visitedPackages,
          );
        }
      }
    }
  }

  // Sort warnings by package name for consistent ordering
  final sortedWarnings = warnings.values.toList()
    ..sort((a, b) => a.packageName.compareTo(b.packageName));

  return sortedWarnings;
}

/// Checks if a package has platform warnings and adds it to the warnings map.
///
/// Skips packages already in [visitedPackages] to prevent duplicates.
/// Only adds warnings for packages with legacy iOS CocoaPods support.
void _checkPackageWarning({
  required String packageName,
  required String version,
  required String? introducedBy,
  required PackageDependencyGraphData graphData,
  required Map<String, PackagePlatformWarning> warnings,
  required Set<String> visitedPackages,
}) {
  // Skip if already visited to avoid duplicates
  if (visitedPackages.contains(packageName)) {
    return;
  }

  final platformSupport = graphData.platformSupportByPackage[packageName];
  if (platformSupport?.hasLegacyIosWarning ?? false) {
    visitedPackages.add(packageName);
    warnings[packageName] = PackagePlatformWarning(
      packageName: packageName,
      version: version,
      introducedBy: introducedBy,
      warningType: 'legacyIosCocoaPods',
    );
  }
}
