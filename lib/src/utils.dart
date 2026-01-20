import 'dart:io';
import 'package:path/path.dart' as p;

/// Utility functions for file system operations.
///
/// This class provides static methods for common file system operations
/// used throughout the fcheck quality analysis tool, including listing
/// Dart files and counting directories and files.
class FileUtils {
  /// Lists all Dart files in a directory recursively.
  ///
  /// This method traverses the directory tree starting from [dir] and
  /// returns all files with the `.dart` extension.
  ///
  /// [dir] The root directory to search in.
  ///
  /// Returns a list of [File] objects representing all Dart files found.
  static List<File> listDartFiles(Directory dir) {
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .toList();
  }

  /// Counts the total number of subdirectories in a directory recursively.
  ///
  /// This includes all nested directories at any depth level.
  ///
  /// [dir] The root directory to count subdirectories in.
  ///
  /// Returns the total number of directories found.
  static int countFolders(Directory dir) {
    return dir.listSync(recursive: true).whereType<Directory>().length;
  }

  /// Counts the total number of files in a directory recursively.
  ///
  /// This includes all files at any depth level within the directory tree.
  ///
  /// [dir] The root directory to count files in.
  ///
  /// Returns the total number of files found.
  static int countAllFiles(Directory dir) {
    return dir.listSync(recursive: true).whereType<File>().length;
  }
}
