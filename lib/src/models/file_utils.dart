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
    // Expand glob patterns to handle common cases
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    final globs = expandedPatterns.map((p) => Glob(p)).toList();

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .where((file) {
      // Skip files in hidden directories (directories starting with '.')
      final relativePath = p.relative(file.path, from: dir.path);
      final pathParts = p.split(relativePath);
      if (pathParts.any((part) => part.startsWith('.'))) {
        return false;
      }

      // Default hide locale files except for the main app_localizations.dart
      final fileName = p.basename(file.path);
      if ((fileName.startsWith('app_localizations_') ||
              fileName.startsWith('app_localization_')) &&
          fileName.endsWith('.dart')) {
        return false;
      }

      // Check if the file is in any default excluded directory
      if (pathParts.any((part) => defaultExcludedDirs.contains(part))) {
        return false;
      }

      // Check glob patterns
      // We check if the relative path matches any exclusion glob
      for (final glob in globs) {
        if (glob.matches(relativePath)) {
          return false;
        }
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
    // Expand glob patterns to handle common cases
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    final globs = expandedPatterns.map((p) => Glob(p)).toList();

    final excludedDartFiles = <File>[];
    final excludedNonDartFiles = <File>[];
    final excludedDirectories = <Directory>[];

    dir.listSync(recursive: true).forEach((entity) {
      final relativePath = p.relative(entity.path, from: dir.path);
      final pathParts = p.split(relativePath);

      // Check if entity is in hidden directories
      if (pathParts.any((part) => part.startsWith('.'))) {
        if (entity is Directory) {
          excludedDirectories.add(entity);
        } else if (entity is File) {
          if (p.extension(entity.path) == '.dart') {
            excludedDartFiles.add(entity);
          } else {
            excludedNonDartFiles.add(entity);
          }
        }
        return;
      }

      // Check if entity is in default excluded directories
      if (pathParts.any((part) => defaultExcludedDirs.contains(part))) {
        if (entity is Directory) {
          excludedDirectories.add(entity);
        } else if (entity is File) {
          if (p.extension(entity.path) == '.dart') {
            excludedDartFiles.add(entity);
          } else {
            excludedNonDartFiles.add(entity);
          }
        }
        return;
      }

      // Check glob patterns - only exclude files, not directories
      if (entity is File) {
        for (final glob in globs) {
          if (glob.matches(relativePath)) {
            if (p.extension(entity.path) == '.dart') {
              excludedDartFiles.add(entity);
            } else {
              excludedNonDartFiles.add(entity);
            }
            return;
          }
        }
      }

      // Check for locale files (special case for Dart files)
      if (entity is File && p.extension(entity.path) == '.dart') {
        final fileName = p.basename(entity.path);
        if ((fileName.startsWith('app_localizations_') ||
                fileName.startsWith('app_localization_')) &&
            fileName.endsWith('.dart')) {
          excludedDartFiles.add(entity);
        }
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
    // Expand glob patterns to handle common cases
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    final globs = expandedPatterns.map((p) => Glob(p)).toList();

    int folderCount = 0;
    int fileCount = 0;
    int excludedFoldersCount = 0;
    int excludedFilesCount = 0;
    int excludedDartFilesCount = 0;
    final dartFiles = <File>[];

    dir.listSync(recursive: true).forEach((entity) {
      final relativePath = p.relative(entity.path, from: dir.path);
      final pathParts = p.split(relativePath);

      // Skip hidden directories and their contents
      if (pathParts.any((part) => part.startsWith('.'))) {
        if (entity is Directory) {
          excludedFoldersCount++;
        } else if (entity is File) {
          excludedFilesCount++;
          if (p.extension(entity.path) == '.dart') {
            excludedDartFilesCount++;
          }
        }
        return;
      }

      // Check if entity is in default excluded directories
      if (pathParts.any((part) => defaultExcludedDirs.contains(part))) {
        if (entity is Directory) {
          excludedFoldersCount++;
        } else if (entity is File) {
          excludedFilesCount++;
          if (p.extension(entity.path) == '.dart') {
            excludedDartFilesCount++;
          }
        }
        return;
      }

      // Check glob patterns - only exclude files, not directories
      if (entity is File) {
        for (final glob in globs) {
          if (glob.matches(relativePath)) {
            excludedFilesCount++;
            if (p.extension(entity.path) == '.dart') {
              excludedDartFilesCount++;
            }
            return;
          }
        }
      }

      if (entity is Directory) {
        folderCount++;
      } else if (entity is File) {
        fileCount++;
        if (p.extension(entity.path) == '.dart') {
          // Additional checks for Dart files
          final fileName = p.basename(entity.path);
          if ((fileName.startsWith('app_localizations_') ||
                  fileName.startsWith('app_localization_')) &&
              fileName.endsWith('.dart')) {
            excludedDartFilesCount++;
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
      excludedDartFilesCount,
      excludedFoldersCount,
      excludedFilesCount
    );
  }
}
