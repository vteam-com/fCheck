import 'dart:io';

import 'package:fcheck/src/analyzers/magic_numbers/magic_number_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('MagicNumberAnalyzer', () {
    late MagicNumberAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = MagicNumberAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('fcheck_magic_numbers_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns empty list for empty file', () {
      final file = File('${tempDir.path}/empty.dart')..writeAsStringSync('');
      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('detects simple magic numbers', () {
      final file = File('${tempDir.path}/simple.dart')..writeAsStringSync('''
void main() {
  print(42);
  print(0);
}
''');

      final issues = analyzer.analyzeFile(file);

      expect(issues.length, equals(1));
      expect(issues[0].value, equals('42'));
      expect(issues[0].lineNumber, equals(2));
    });

    test('skips const declarations', () {
      final file = File('${tempDir.path}/const.dart')..writeAsStringSync('''
const int maxAttempts = 3;

void main() {
  print("ready");
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('skips ignored literal values', () {
      final file = File('${tempDir.path}/ignored.dart')..writeAsStringSync('''
void main() {
  print(0);
  print(1);
  print(-1);
  print(2);
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('2'));
    });

    test('skips annotation arguments', () {
      final file = File('${tempDir.path}/annotation.dart')
        ..writeAsStringSync('''
@Deprecated(1)
void main() {}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('analyzes directory contents', () {
      File('${tempDir.path}/file1.dart')
          .writeAsStringSync('void main() => print(8);');
      File('${tempDir.path}/file2.dart')
          .writeAsStringSync('void main() => print(9);');
      File('${tempDir.path}/README.txt')
          .writeAsStringSync('This is not a Dart file.');

      final issues = analyzer.analyzeDirectory(tempDir);

      expect(issues.length, equals(2));
      expect(issues.map((issue) => issue.value), contains('8'));
      expect(issues.map((issue) => issue.value), contains('9'));
    });
  });
}
