/// Represents a package that has platform-related warnings requiring modernization.
///
/// Tracks packages that use legacy CocoaPods instead of Swift Package Manager
/// on iOS, along with the direct dependency that brought them into the project.
class PackagePlatformWarning {
  /// The name of the transitive package with the warning.
  final String packageName;

  /// The resolved version of the package from lockfile.
  final String version;

  /// The direct dependency that introduced this transitive package.
  /// For packages that are direct dependencies themselves, this is null.
  final String? introducedBy;

  /// The type of warning (e.g., 'legacyIosCocoaPods').
  final String warningType;

  /// Creates a new PackagePlatformWarning instance.
  ///
  /// [packageName] The name of the problematic transitive package.
  /// [version] The resolved version from the lockfile.
  /// [introducedBy] The direct dependency that brought this package in, or null if direct.
  /// [warningType] The type of platform warning ('legacyIosCocoaPods').
  const PackagePlatformWarning({
    required this.packageName,
    required this.version,
    this.introducedBy,
    this.warningType = 'legacyIosCocoaPods',
  });

  /// Converts this warning to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'version': version,
    'introducedBy': introducedBy,
    'warningType': warningType,
  };

  @override
  String toString() {
    final intro = introducedBy != null ? ' (via $introducedBy)' : '';
    return '$packageName $version$intro';
  }
}
