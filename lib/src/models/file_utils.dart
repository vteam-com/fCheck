import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:glob/glob.dart';

/// Utility functions for file system operations.
///
/// This class provides static methods for common file system operations
/// used throughout the fcheck quality analysis tool, including listing
/// Dart files and counting directories and files.
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
    if (pattern.startsWith('**/') && pattern.endsWith('/**')) {
      // Pattern like **/folder/**
      final folderName = pattern.substring(3, pattern.length - 3);
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
      // Default hide locale files except for the main app_localizations.dart
      final fileName = p.basename(file.path);
      if ((fileName.startsWith('app_localizations_') ||
              fileName.startsWith('app_localization_')) &&
          fileName.endsWith('.dart')) {
        return false;
      }

      // Check if the file is in any default excluded directory
      final relativePath = p.relative(file.path, from: dir.path);
      final pathParts = p.split(relativePath);
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

  /// Counts the total number of subdirectories in a directory recursively.
  ///
  /// [dir] The root directory to count subdirectories in.
  /// [excludePatterns] Optional list of glob patterns to exclude.
  ///
  /// Returns the total number of directories found.
  static int countFolders(Directory dir,
      {List<String> excludePatterns = const []}) {
    // Expand glob patterns to handle common cases
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    final globs = expandedPatterns.map((p) => Glob(p)).toList();

    return dir
        .listSync(recursive: true)
        .whereType<Directory>()
        .where((directory) {
      final relativePath = p.relative(directory.path, from: dir.path);
      final pathParts = p.split(relativePath);
      if (pathParts.any((part) => defaultExcludedDirs.contains(part))) {
        return false;
      }

      for (final glob in globs) {
        if (glob.matches(relativePath)) {
          return false;
        }
      }
      return true;
    }).length;
  }

  /// Counts the total number of files in a directory recursively.
  ///
  /// [dir] The root directory to count files in.
  /// [excludePatterns] Optional list of glob patterns to exclude.
  ///
  /// Returns the total number of files found.
  static int countAllFiles(Directory dir,
      {List<String> excludePatterns = const []}) {
    // Expand glob patterns to handle common cases
    final expandedPatterns = <String>[];
    for (final pattern in excludePatterns) {
      expandedPatterns.addAll(_expandGlobPattern(pattern));
    }
    final globs = expandedPatterns.map((p) => Glob(p)).toList();

    return dir.listSync(recursive: true).whereType<File>().where((file) {
      final relativePath = p.relative(file.path, from: dir.path);
      final pathParts = p.split(relativePath);
      if (pathParts.any((part) => defaultExcludedDirs.contains(part))) {
        return false;
      }

      for (final glob in globs) {
        if (glob.matches(relativePath)) {
          return false;
        }
      }
      return true;
    }).length;
  }
}
