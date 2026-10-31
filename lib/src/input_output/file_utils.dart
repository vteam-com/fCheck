import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Utility functions for file system operations.
///
/// This class provides static methods for common file system operations
/// used throughout the fcheck quality analysis tool, including:
/// - Listing Dart files with exclusion support
/// - Unified directory scanning for performance
/// - Excluded files and directories listing
/// - Hidden folder filtering
class FileUtils {
  static const String _testDirName = 'test';
  static const String _integrationTestDirName = 'integration_test';
  static const String _buildDirName = 'build';

  /// Expands glob patterns to handle common use cases that the glob library
  /// doesn't handle intuitively.
  ///
  /// For example, converts "**/helpers/**" to multiple patterns that properly
  /// match files directly in the helpers folder and its subfolders at any level.
  ///
  /// [pattern] The original glob pattern.
  ///
  /// Returns a list of glob patterns that should be checked.
  static List<String> _expandGlobPattern(String pattern) {
    final expandedPatterns = <String>[pattern];

    // Handle the common case of "**/folder/**" which should match:
    // - files directly in the folder (folder/file.dart)
    // - files in subfolders (folder/subfolder/file.dart)
    // - nested folders at any level (some/path/folder/file.dart)
    /// length of suffix part like "/**" or prefix part like "**/"
    const int globPrefixLength = 3;

    if (pattern.startsWith('**/') && pattern.endsWith('/**')) {
      // Pattern like **/folder/**
      final folderName = pattern.substring(
        globPrefixLength,
        pattern.length - globPrefixLength,
      );
      expandedPatterns.add('**/$folderName/*');
      expandedPatterns.add('$folderName/**');
      expandedPatterns.add('$folderName/*');
    }

    return expandedPatterns;
  }

  /// Builds compiled [Glob] matchers for all expanded exclude patterns.
  static List<Glob> _buildExcludeGlobs(List<String> excludePatterns) {
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    return expandedPatterns.map((p) => Glob(p)).toList();
  }

  /// Returns [entityPath] relative to [rootPath].
  ///
  /// Entities produced by listing [rootPath] always start with it, so a
  /// prefix strip avoids the far costlier normalization in [p.relative],
  /// which dominates scan time on large trees.
  static String _relativeToRoot(String entityPath, String rootPath) {
    final rootPrefix = rootPath.endsWith(p.separator)
        ? rootPath
        : '$rootPath${p.separator}';
    if (entityPath.startsWith(rootPrefix)) {
      return entityPath.substring(rootPrefix.length);
    }
    return p.relative(entityPath, from: rootPath);
  }

  /// Lists [dir] recursively in the same order as `listSync(recursive: true)`
  /// but without descending into hidden directories or `build/`.
  ///
  /// Those directories are still yielded, so they remain visible as excluded
  /// entries; only their contents are skipped. Their contents are never
  /// analyzed, yet they are usually most of a project tree: tool caches
  /// (`.dart_tool`, `.git`), build outputs, and Flutter's `.symlinks` /
  /// `.plugin_symlinks` folders, which link into whole pub-cache packages.
  static Iterable<FileSystemEntity> listProjectEntities(Directory dir) =>
      _listProjectEntities(dir, {dir.resolveSymbolicLinksSync()});

  /// Walks [dir] depth-first, skipping symlinked directories that loop back to
  /// one of [ancestorRealPaths].
  static Iterable<FileSystemEntity> _listProjectEntities(
    Directory dir,
    Set<String> ancestorRealPaths,
  ) sync* {
    for (final entity in dir.listSync()) {
      yield entity;
      if (entity is! Directory || _isPrunedDirectory(entity)) {
        continue;
      }
      final realPath = entity.resolveSymbolicLinksSync();
      if (ancestorRealPaths.contains(realPath)) {
        continue;
      }
      yield* _listProjectEntities(entity, {...ancestorRealPaths, realPath});
    }
  }

  /// Returns true for directories whose contents are never walked.
  static bool _isPrunedDirectory(Directory directory) {
    final name = p.basename(directory.path);
    return name.startsWith('.') || name == _buildDirName;
  }

  static bool _isHiddenPath(List<String> pathParts) =>
      pathParts.any((part) => part.startsWith('.'));

  static bool _isDefaultExcludedPath(List<String> pathParts) =>
      pathParts.any((part) => defaultExcludedDirs.contains(part));

  static bool _isTestPath(List<String> pathParts) => pathParts.any(
    (part) => part == _testDirName || part == _integrationTestDirName,
  );

  static bool _isTestRootDirectory(Directory directory) {
    final name = p.basename(directory.path);
    return name == _testDirName || name == _integrationTestDirName;
  }

  /// Returns true when [relativePath] matches at least one exclude glob.
  static bool _matchesAnyGlob(List<Glob> globs, String relativePath) {
    for (final glob in globs) {
      if (glob.matches(relativePath)) {
        return true;
      }
    }
    return false;
  }

  static bool _isGeneratedLocalizationDartFile(File file) {
    final fileName = p.basename(file.path);
    return (fileName.startsWith('app_localizations_') ||
            fileName.startsWith('app_localization_')) &&
        fileName.endsWith('.dart');
  }

  /// Adds [entity] to the appropriate excluded collection by type.
  static void _addExcludedEntity(
    FileSystemEntity entity,
    List<File> excludedDartFiles,
    List<File> excludedNonDartFiles,
    List<Directory> excludedDirectories,
  ) {
    if (entity is Directory) {
      excludedDirectories.add(entity);
      return;
    }
    if (entity is File) {
      if (p.extension(entity.path) == '.dart') {
        excludedDartFiles.add(entity);
      } else {
        excludedNonDartFiles.add(entity);
      }
    }
  }

  /// Default excluded directories.
  static const List<String> defaultExcludedDirs = [
    'example',
    _testDirName,
    _integrationTestDirName,
    'tool',
    '.dart_tool',
    _buildDirName,
    '.git',
    'ios',
    'android',
    'web',
    'macos',
    'windows',
    'linux',
  ];

  /// Private constructor to prevent instantiation.
  ///
  /// This class contains only static methods and should not be instantiated.
  /// Use the static methods directly instead.
  FileUtils._();

  /// Lists all Dart files in a directory recursively, excluding specified patterns.
  ///
  /// This method traverses the directory tree starting from [dir] and
  /// returns all files with the `.dart` extension.
  ///
  /// [dir] The root directory to search in.
  /// [excludePatterns] Optional list of glob patterns to exclude.
  ///
  /// Returns a list of [File] objects representing all Dart files found.
  static List<File> listDartFiles(
    Directory dir, {
    List<String> excludePatterns = const [],
  }) {
    final globs = _buildExcludeGlobs(excludePatterns);

    return listProjectEntities(dir)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .where((file) {
          // Skip files in hidden directories (directories starting with '.')
          final relativePath = _relativeToRoot(file.path, dir.path);
          final pathParts = p.split(relativePath);
          if (_isHiddenPath(pathParts)) {
            return false;
          }

          // Default hide locale files except for the main app_localizations.dart
          if (_isGeneratedLocalizationDartFile(file)) {
            return false;
          }

          // Check if the file is in any default excluded directory
          if (_isDefaultExcludedPath(pathParts)) {
            return false;
          }

          // Check glob patterns
          if (_matchesAnyGlob(globs, relativePath)) {
            return false;
          }

          return true;
        })
        .toList();
  }

  /// Lists all excluded files and directories in a directory recursively.
  ///
  /// This method identifies files and directories that would be excluded from analysis
  /// due to hidden directories, default excluded directories, or custom exclude patterns.
  ///
  /// [dir] The root directory to scan.
  /// [excludePatterns] Optional list of glob patterns to exclude.
  ///
  /// Returns a tuple containing:
  /// - List of excluded Dart files
  /// - List of excluded non-Dart files
  /// - List of excluded directories
  static (
    List<File> excludedDartFiles,
    List<File> excludedNonDartFiles,
    List<Directory> excludedDirectories,
  )
  listExcludedFiles(Directory dir, {List<String> excludePatterns = const []}) {
    final globs = _buildExcludeGlobs(excludePatterns);

    final excludedDartFiles = <File>[];
    final excludedNonDartFiles = <File>[];
    final excludedDirectories = <Directory>[];

    listProjectEntities(dir).forEach((entity) {
      final relativePath = _relativeToRoot(entity.path, dir.path);
      final pathParts = p.split(relativePath);

      // Check if entity is in hidden directories
      if (_isHiddenPath(pathParts)) {
        _addExcludedEntity(
          entity,
          excludedDartFiles,
          excludedNonDartFiles,
          excludedDirectories,
        );
        return;
      }

      // Check if entity is in default excluded directories
      if (_isDefaultExcludedPath(pathParts)) {
        _addExcludedEntity(
          entity,
          excludedDartFiles,
          excludedNonDartFiles,
          excludedDirectories,
        );
        return;
      }

      // Check glob patterns - only exclude files, not directories
      if (entity is File) {
        if (_matchesAnyGlob(globs, relativePath)) {
          _addExcludedEntity(
            entity,
            excludedDartFiles,
            excludedNonDartFiles,
            excludedDirectories,
          );
          return;
        }
      }

      // Check for locale files (special case for Dart files)
      if (entity is File &&
          p.extension(entity.path) == '.dart' &&
          _isGeneratedLocalizationDartFile(entity)) {
        excludedDartFiles.add(entity);
      }
    });

    return (excludedDartFiles, excludedNonDartFiles, excludedDirectories);
  }

  /// Performs a single unified scan of a directory to collect all file system metrics.
  ///
  /// This method efficiently collects Dart files, folder count, file count, and excluded counts
  /// in a single traversal, avoiding the performance overhead of multiple scans.
  ///
  /// [dir] The root directory to scan.
  /// [excludePatterns] Optional list of glob patterns to exclude.
  ///
  /// Returns a tuple containing:
  /// - List of Dart files
  /// - Total folder count
  /// - Total file count
  /// - Excluded Dart files count
  /// - Excluded folders count
  /// - Excluded files count
  /// - Test root directories count (`test`, `integration_test`)
  /// - Test files count (all files under test roots)
  /// - Test Dart files count (Dart files under test roots)
  /// - Custom excluded Dart files count (matched by user-provided globs only)
  /// - Test Dart files (the files behind the test Dart files count), so test
  ///   analysis can reuse this walk instead of listing the tree again
  static (
    List<File> dartFiles,
    int folderCount,
    int fileCount,
    int excludedDartFilesCount,
    int excludedFoldersCount,
    int excludedFilesCount,
    int testDirectoriesCount,
    int testFilesCount,
    int testDartFilesCount,
    int customExcludedDartFilesCount,
    List<File> testDartFiles,
  )
  scanDirectory(Directory dir, {List<String> excludePatterns = const []}) {
    final globs = _buildExcludeGlobs(excludePatterns);

    int folderCount = 0;
    int fileCount = 0;
    final excludedCounts = _ScanCounts();
    final dartFiles = <File>[];

    listProjectEntities(dir).forEach((entity) {
      final relativePath = _relativeToRoot(entity.path, dir.path);
      final pathParts = p.split(relativePath);

      // Skip hidden directories and their contents
      if (_isHiddenPath(pathParts)) {
        excludedCounts.addExcludedEntity(entity);
        return;
      }

      if (_isTestPath(pathParts)) {
        excludedCounts.addTestEntity(entity);
      }

      // Check if entity is in default excluded directories
      if (_isDefaultExcludedPath(pathParts)) {
        excludedCounts.addExcludedEntity(entity);
        return;
      }

      // Check glob patterns - only exclude files, not directories
      if (entity is File && _matchesAnyGlob(globs, relativePath)) {
        excludedCounts.addExcludedEntity(entity);
        excludedCounts.addCustomExcludedEntity(entity);
        return;
      }

      if (entity is Directory) {
        folderCount++;
      } else if (entity is File) {
        fileCount++;
        if (p.extension(entity.path) == '.dart') {
          // Additional checks for Dart files
          if (_isGeneratedLocalizationDartFile(entity)) {
            excludedCounts.excludedDartFilesCount++;
            return; // Skip locale files except main app_localizations.dart
          }
          dartFiles.add(entity);
        }
      }
    });

    return (
      dartFiles,
      folderCount,
      fileCount,
      excludedCounts.excludedDartFilesCount,
      excludedCounts.excludedFoldersCount,
      excludedCounts.excludedFilesCount,
      excludedCounts.testDirectoriesCount,
      excludedCounts.testFilesCount,
      excludedCounts.testDartFilesCount,
      excludedCounts.customExcludedDartFilesCount,
      excludedCounts.testDartFiles,
    );
  }
}

class _ScanCounts {
  int excludedFoldersCount = 0;
  int excludedFilesCount = 0;
  int excludedDartFilesCount = 0;
  int testDirectoriesCount = 0;
  int testFilesCount = 0;
  int testDartFilesCount = 0;
  int customExcludedDartFilesCount = 0;
  final List<File> testDartFiles = <File>[];

  /// Records one excluded entity and updates per-kind counters.
  ///
  /// Directories increase [excludedFoldersCount]. Files increase
  /// [excludedFilesCount], and Dart files additionally increase
  /// [excludedDartFilesCount].
  void addExcludedEntity(FileSystemEntity entity) {
    if (entity is Directory) {
      excludedFoldersCount++;
      return;
    }
    if (entity is File) {
      excludedFilesCount++;
      if (p.extension(entity.path) == '.dart') {
        excludedDartFilesCount++;
      }
    }
  }

  /// Records test discovery counters for canonical test paths.
  void addTestEntity(FileSystemEntity entity) {
    if (entity is Directory && FileUtils._isTestRootDirectory(entity)) {
      testDirectoriesCount++;
      return;
    }
    if (entity is File) {
      testFilesCount++;
      if (p.extension(entity.path) == '.dart') {
        testDartFilesCount++;
        testDartFiles.add(entity);
      }
    }
  }

  /// Records one user-glob excluded Dart file.
  void addCustomExcludedEntity(FileSystemEntity entity) {
    if (entity is File && p.extension(entity.path) == '.dart') {
      customExcludedDartFilesCount++;
    }
  }
}
