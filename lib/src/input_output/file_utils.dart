import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:glob/glob.dart';

/// Utility functions for file system operations.
///
/// This class provides static methods for common file system operations
/// used throughout the fcheck quality analysis tool, including:
/// - Listing Dart files with exclusion support
/// - Unified directory scanning for performance
/// - Excluded files and directories listing
/// - Hidden folder filtering
class FileUtils {
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
          globPrefixLength, pattern.length - globPrefixLength);
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

  static bool _isHiddenPath(List<String> pathParts) =>
      pathParts.any((part) => part.startsWith('.'));

  static bool _isDefaultExcludedPath(List<String> pathParts) =>
      pathParts.any((part) => defaultExcludedDirs.contains(part));

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
    'test',
    'tool',
    '.dart_tool',
    'build',
    '.git',
    'ios',
    'android',
    'web',
    'macos',
    'windows',
    'linux'
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
  static List<File> listDartFiles(Directory dir,
      {List<String> excludePatterns = const []}) {
    final globs = _buildExcludeGlobs(excludePatterns);

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .where((file) {
      // Skip files in hidden directories (directories starting with '.')
      final relativePath = p.relative(file.path, from: dir.path);
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
    }).toList();
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
    List<Directory> excludedDirectories
  ) listExcludedFiles(Directory dir,
      {List<String> excludePatterns = const []}) {
    final globs = _buildExcludeGlobs(excludePatterns);

    final excludedDartFiles = <File>[];
    final excludedNonDartFiles = <File>[];
    final excludedDirectories = <Directory>[];

    dir.listSync(recursive: true).forEach((entity) {
      final relativePath = p.relative(entity.path, from: dir.path);
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
  static (
    List<File> dartFiles,
    int folderCount,
    int fileCount,
    int excludedDartFilesCount,
    int excludedFoldersCount,
    int excludedFilesCount
  ) scanDirectory(Directory dir, {List<String> excludePatterns = const []}) {
    final globs = _buildExcludeGlobs(excludePatterns);

    int folderCount = 0;
    int fileCount = 0;
    final excludedCounts = _ScanCounts();
    final dartFiles = <File>[];

    dir.listSync(recursive: true).forEach((entity) {
      final relativePath = p.relative(entity.path, from: dir.path);
      final pathParts = p.split(relativePath);

      // Skip hidden directories and their contents
      if (_isHiddenPath(pathParts)) {
        excludedCounts.addExcludedEntity(entity);
        return;
      }

      // Check if entity is in default excluded directories
      if (_isDefaultExcludedPath(pathParts)) {
        excludedCounts.addExcludedEntity(entity);
        return;
      }

      // Check glob patterns - only exclude files, not directories
      if (entity is File && _matchesAnyGlob(globs, relativePath)) {
        excludedCounts.addExcludedEntity(entity);
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
      excludedCounts.excludedFilesCount
    );
  }

  /// Counts Dart files excluded specifically by user-provided glob patterns.
  ///
  /// Unlike [scanDirectory], this excludes only files matched by
  /// [excludePatterns] after default hidden/system exclusions are removed.
  /// This is intended for suppression scoring and reflects user-configured
  /// skip behavior only.
  static int countCustomExcludedDartFiles(
    Directory dir, {
    List<String> excludePatterns = const [],
  }) {
    if (excludePatterns.isEmpty) {
      return 0;
    }

    final globs = _buildExcludeGlobs(excludePatterns);
    var count = 0;

    dir.listSync(recursive: true).forEach((entity) {
      if (entity is! File || p.extension(entity.path) != '.dart') {
        return;
      }

      final relativePath = p.relative(entity.path, from: dir.path);
      final pathParts = p.split(relativePath);

      if (_isHiddenPath(pathParts) || _isDefaultExcludedPath(pathParts)) {
        return;
      }

      if (_isGeneratedLocalizationDartFile(entity)) {
        return;
      }

      if (_matchesAnyGlob(globs, relativePath)) {
        count++;
      }
    });

    return count;
  }
}

class _ScanCounts {
  int excludedFoldersCount = 0;
  int excludedFilesCount = 0;
  int excludedDartFilesCount = 0;

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
}
