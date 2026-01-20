import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  static List<File> listDartFiles(Directory dir) {
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .toList();
  }

  static int countFolders(Directory dir) {
    return dir.listSync(recursive: true).whereType<Directory>().length;
  }

  static int countAllFiles(Directory dir) {
    return dir.listSync(recursive: true).whereType<File>().length;
  }
}
