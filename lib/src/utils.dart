import 'dart:io';
import 'package:path/path.dart' as p;

/// Utility functions for file system operations.
///
/// This class provides static methods for common file system operations
/// used throughout the fcheck quality analysis tool, including listing
/// Dart files and counting directories and files.
class FileUtils {
  /// Lists all Dart files in a directory recursively, excluding example and test directories.
  ///
  /// This method traverses the directory tree starting from [dir] and
  /// returns all files with the `.dart` extension, but excludes files in
  /// directories that typically contain demonstration or test code that
  /// shouldn't be analyzed for production quality metrics.
  ///
  /// Excluded directories: example/, test/, tool/, .dart_tool/, build/, .git/
  ///
  /// [dir] The root directory to search in.
  ///
  /// Returns a list of [File] objects representing all Dart files found.
  static List<File> listDartFiles(Directory dir) {
    final excludedDirs = [
      'example',
      'test',
      'tool',
      '.dart_tool',
      'build',
      '.git'
    ];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .where((file) {
      // Check if the file is in any excluded directory
      final relativePath = p.relative(file.path, from: dir.path);
      final pathParts = p.split(relativePath);
      return !pathParts.any((part) => excludedDirs.contains(part));
    }).toList();
  }

  /// Counts the total number of subdirectories in a directory recursively.
  ///
  /// This includes all nested directories at any depth level, excluding
  /// directories that typically contain demonstration or test code.
  ///
  /// Excluded directories: example/, test/, tool/, .dart_tool/, build/, .git/
  ///
  /// [dir] The root directory to count subdirectories in.
  ///
  /// Returns the total number of directories found.
  static int countFolders(Directory dir) {
    final excludedDirs = [
      'example',
      'test',
      'tool',
      '.dart_tool',
      'build',
      '.git'
    ];

    return dir
        .listSync(recursive: true)
        .whereType<Directory>()
        .where((directory) {
      final relativePath = p.relative(directory.path, from: dir.path);
      final pathParts = p.split(relativePath);
      return !pathParts.any((part) => excludedDirs.contains(part));
    }).length;
  }

  /// Counts the total number of files in a directory recursively.
  ///
  /// This includes all files at any depth level within the directory tree,
  /// excluding files in directories that typically contain demonstration or
  /// test code.
  ///
  /// Excluded directories: example/, test/, tool/, .dart_tool/, build/, .git/
  ///
  /// [dir] The root directory to count files in.
  ///
  /// Returns the total number of files found.
  static int countAllFiles(Directory dir) {
    final excludedDirs = [
      'example',
      'test',
      'tool',
      '.dart_tool',
      'build',
      '.git'
    ];

    return dir.listSync(recursive: true).whereType<File>().where((file) {
      final relativePath = p.relative(file.path, from: dir.path);
      final pathParts = p.split(relativePath);
      return !pathParts.any((part) => excludedDirs.contains(part));
    }).length;
  }
}
