import 'dart:io';
import 'package:test/test.dart';
import 'package:fcheck/src/magic_numbers/magic_number_analyzer.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MagicNumberAnalyzer Ignore Directive', () {
    late Directory tempDir;
    late MagicNumberAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      analyzer = MagicNumberAnalyzer();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'should ignore magic numbers when directive is present (// fcheck - ignore magic numbers)',
        () {
      final file = File(p.join(tempDir.path, 'ignored.dart'));
      file.writeAsStringSync('''
// fcheck - ignore magic numbers
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test(
        'should ignore magic numbers when directive is present (// fcheck: ignore magic numbers)',
        () {
      final file = File(p.join(tempDir.path, 'ignored_alt.dart'));
      file.writeAsStringSync('''
// fcheck: ignore magic numbers
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('should ignore magic numbers when directive is in block comment', () {
      final file = File(p.join(tempDir.path, 'ignored_block.dart'));
      file.writeAsStringSync('''
/*
 * fcheck - ignore magic numbers
 */
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('should NOT ignore magic numbers when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
      expect(issues.first.value, '42');
    });

    test('should NOT ignore if directive is not at the top', () {
      final file = File(p.join(tempDir.path, 'not_at_top.dart'));
      file.writeAsStringSync('''
void main() {
  // fcheck - ignore magic numbers
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
    });
  });
}
