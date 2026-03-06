import 'dart:io';

import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Parsed pubspec.yaml metadata for a project.
class PubspecInfo {
  /// Directory containing the resolved `pubspec.yaml`, when available.
  final Directory? projectRoot;

  /// Package name declared in `pubspec.yaml`.
  final String name;

  /// Package version declared in `pubspec.yaml`.
  final String version;

  /// Detected project type based on pubspec dependencies.
  final ProjectType projectType;

  /// Number of regular dependencies declared in the pubspec.
  final int dependencyCount;

  /// Number of dev dependencies declared in the pubspec.
  final int devDependencyCount;

  /// Creates parsed pubspec metadata for an analysis run.
  const PubspecInfo({
    required this.projectRoot,
    required this.name,
    required this.version,
    required this.projectType,
    required this.dependencyCount,
    required this.devDependencyCount,
  });

  /// Package identifier resolved from `pubspec.yaml`.
  String get packageName => name;

  /// Resolves project metadata from `pubspec.yaml` for [startDir].
  static PubspecInfo load(Directory startDir) {
    final normalizedStartDir = Directory(p.normalize(startDir.absolute.path));
    Directory? currentDir = normalizedStartDir;

    while (currentDir != null) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return _loadFromPubspecFile(pubspecFile, currentDir);
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    final descendantPubspecInfo = _loadFromSingleDescendantPubspec(
      normalizedStartDir,
    );
    if (descendantPubspecInfo != null) {
      return descendantPubspecInfo;
    }

    return _unknown();
  }

  /// Attempts descendant-package resolution when no ancestor pubspec is found.
  ///
  /// Returns `null` when no Dart files exist, when any Dart file cannot be
  /// mapped to a descendant pubspec, or when multiple descendant packages are
  /// discovered under [startDir].
  static PubspecInfo? _loadFromSingleDescendantPubspec(Directory startDir) {
    final dartFiles = FileUtils.listDartFiles(startDir);
    if (dartFiles.isEmpty) {
      return null;
    }

    final pubspecPaths = <String>{};
    final pubspecByPath = <String, File>{};
    for (final dartFile in dartFiles) {
      final pubspecFile = _findNearestPubspecForFile(
        dartFile: dartFile,
        rootDirectory: startDir,
      );
      if (pubspecFile == null) {
        return null;
      }

      final pubspecPath = p.normalize(pubspecFile.absolute.path);
      pubspecPaths.add(pubspecPath);
      pubspecByPath[pubspecPath] = pubspecFile;
      if (pubspecPaths.length > 1) {
        return null;
      }
    }

    if (pubspecPaths.length != 1) {
      return null;
    }

    final pubspecFile = pubspecByPath[pubspecPaths.single];
    if (pubspecFile == null) {
      return null;
    }

    return _loadFromPubspecFile(pubspecFile, pubspecFile.parent);
  }

  /// Finds the nearest ancestor `pubspec.yaml` for [dartFile] within [rootDirectory].
  static File? _findNearestPubspecForFile({
    required File dartFile,
    required Directory rootDirectory,
  }) {
    final normalizedRootPath = p.normalize(rootDirectory.absolute.path);
    Directory currentDir = dartFile.parent;

    while (_isSameOrWithin(normalizedRootPath, currentDir.absolute.path)) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return pubspecFile;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    return null;
  }

  static bool _isSameOrWithin(String rootPath, String candidatePath) {
    final normalizedRootPath = p.normalize(rootPath);
    final normalizedCandidatePath = p.normalize(candidatePath);
    return normalizedRootPath == normalizedCandidatePath ||
        p.isWithin(normalizedRootPath, normalizedCandidatePath);
  }

  /// Parses metadata fields from a concrete `pubspec.yaml` file.
  ///
  /// Falls back to `unknown` values when parsing fails or the YAML structure is
  /// not the expected map shape.
  static PubspecInfo _loadFromPubspecFile(
    File pubspecFile,
    Directory projectRoot,
  ) {
    try {
      final yaml = loadYaml(pubspecFile.readAsStringSync());
      if (yaml is YamlMap) {
        final name = _readStringField(yaml, 'name');
        final version = _readStringField(yaml, 'version');
        final projectType = _detectProjectType(yaml);
        return PubspecInfo(
          projectRoot: projectRoot,
          name: name,
          version: version,
          projectType: projectType,
          dependencyCount: _readMapEntryCount(yaml, 'dependencies'),
          devDependencyCount: _readMapEntryCount(yaml, 'dev_dependencies'),
        );
      }
      return PubspecInfo(
        projectRoot: projectRoot,
        name: 'unknown',
        version: 'unknown',
        projectType: ProjectType.dart,
        dependencyCount: 0,
        devDependencyCount: 0,
      );
    } catch (_) {
      return PubspecInfo(
        projectRoot: projectRoot,
        name: 'unknown',
        version: 'unknown',
        projectType: ProjectType.unknown,
        dependencyCount: 0,
        devDependencyCount: 0,
      );
    }
  }

  /// Returns the sentinel metadata object used when no pubspec can be resolved.
  static PubspecInfo _unknown() {
    return const PubspecInfo(
      projectRoot: null,
      name: 'unknown',
      version: 'unknown',
      projectType: ProjectType.unknown,
      dependencyCount: 0,
      devDependencyCount: 0,
    );
  }

  /// Reads a scalar-like YAML field and normalizes missing values to `unknown`.
  static String _readStringField(YamlMap yaml, String field) {
    final value = yaml[field];
    if (value == null) {
      return 'unknown';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  static int _readMapEntryCount(YamlMap yaml, String field) {
    final value = yaml[field];
    if (value is YamlMap) {
      return value.length;
    }
    return 0;
  }

  /// Detects whether the pubspec describes a Flutter or plain Dart package.
  static ProjectType _detectProjectType(YamlMap yaml) {
    final dependencies = yaml['dependencies'];
    if (dependencies is YamlMap && dependencies.containsKey('flutter')) {
      return ProjectType.flutter;
    }
    final devDependencies = yaml['dev_dependencies'];
    if (devDependencies is YamlMap && devDependencies.containsKey('flutter')) {
      return ProjectType.flutter;
    }
    return ProjectType.dart;
  }
}
