import 'dart:io';
import 'package:fcheck/fcheck.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyzerEngine', () {
    late Directory tempDir;
    late AnalyzeFolder analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_test_');
      analyzer = AnalyzeFolder(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should analyze empty directory', () {
      final metrics = analyzer.analyze();

      expect(metrics.totalFolders, equals(0));
      expect(metrics.totalFiles, equals(0));
      expect(metrics.totalDartFiles, equals(0));
      expect(metrics.totalLinesOfCode, equals(0));
      expect(metrics.totalCommentLines, equals(0));
      expect(metrics.fileMetrics, isEmpty);
      expect(metrics.hardcodedStringIssues, isEmpty);
      expect(metrics.magicNumberIssues, isEmpty);
      expect(metrics.sourceSortIssues, isEmpty);
      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('should analyze directory with Dart files', () {
      // Create a simple Dart file
      File('${tempDir.path}/example.dart').writeAsStringSync('''
// This is a comment
void main() {
  print("Hello World"); // Another comment
}
''');

      // Create a subdirectory with another file
      final subDir = Directory('${tempDir.path}/lib')..createSync();
      File('${subDir.path}/utils.dart').writeAsStringSync('''
// Utility functions
class Utils {
  static void helper() {
    // Do something
  }
}
''');

      final metrics = analyzer.analyze();

      expect(metrics.totalFolders, equals(1)); // lib directory
      expect(metrics.totalFiles, equals(2)); // 2 Dart files
      expect(metrics.totalDartFiles, equals(2));
      expect(metrics.totalLinesOfCode, greaterThan(0));
      expect(metrics.totalCommentLines, greaterThan(0));
      expect(metrics.fileMetrics.length, equals(2));
    });

    test('should detect hardcoded strings in analyzed files', () {
      File('${tempDir.path}/strings.dart').writeAsStringSync('''
void main() {
  print("This is a hardcoded string");
  const String key = "safe"; // This should not be detected
}
''');

      final metrics = analyzer.analyze();

      expect(metrics.hardcodedStringIssues.length, equals(1));
      expect(
        metrics.hardcodedStringIssues[0].value,
        equals('This is a hardcoded string'),
      );
    });

    test('should detect magic numbers in analyzed files', () {
      File('${tempDir.path}/magic.dart').writeAsStringSync('''
void main() {
  print(7);
  const skipValue = 5;
}
''');

      final metrics = analyzer.analyze();
      expect(metrics.magicNumberIssues.length, equals(1));
      expect(metrics.magicNumberIssues.first.value, equals('7'));
    });

    test('should analyze single file correctly', () {
      final dartFile = File('${tempDir.path}/single.dart')
        ..writeAsStringSync('''
// Single file test
class MyClass {
  void method() {
    // Implementation
  }
}
''');

      final fileMetrics = analyzer.analyzeFile(dartFile);

      expect(fileMetrics.path, equals(dartFile.path));
      expect(fileMetrics.linesOfCode, greaterThan(0));
      expect(fileMetrics.commentLines, greaterThan(0));
      expect(fileMetrics.classCount, equals(1));
      expect(fileMetrics.isStatefulWidget, isFalse);
    });
  });
}
