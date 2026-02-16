import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _ansiPattern = RegExp(r'\x1B\[[0-9;]*m');

String _normalizeAnsi(String value) => value.replaceAll(_ansiPattern, '');

void main() {
  group('DeadCodeIssue', () {
    test('typeLabel maps all enum values', () {
      expect(
        DeadCodeIssue(
          type: DeadCodeIssueType.deadFile,
          filePath: 'lib/a.dart',
          name: 'a.dart',
        ).typeLabel,
        equals('dead file'),
      );
      expect(
        DeadCodeIssue(
          type: DeadCodeIssueType.deadClass,
          filePath: 'lib/a.dart',
          name: 'A',
        ).typeLabel,
        equals('dead class'),
      );
      expect(
        DeadCodeIssue(
          type: DeadCodeIssueType.deadFunction,
          filePath: 'lib/a.dart',
          name: 'foo',
        ).typeLabel,
        equals('dead function'),
      );
      expect(
        DeadCodeIssue(
          type: DeadCodeIssueType.unusedVariable,
          filePath: 'lib/a.dart',
          name: 'x',
        ).typeLabel,
        equals('unused variable'),
      );
    });

    test('toString uses line number and owner when provided', () {
      final issue = DeadCodeIssue(
        type: DeadCodeIssueType.unusedVariable,
        filePath: 'lib/main.dart',
        lineNumber: 8,
        name: '',
        owner: 'build',
      );

      expect(
        _normalizeAnsi(issue.toString()),
        equals('lib/main.dart:8: unused variable in build'),
      );
    });

    test('toString falls back to file path when line is null or zero', () {
      final withNullLine = DeadCodeIssue(
        type: DeadCodeIssueType.deadFile,
        filePath: 'lib/a.dart',
        name: 'a.dart',
      );
      final withZeroLine = DeadCodeIssue(
        type: DeadCodeIssueType.deadFile,
        filePath: 'lib/b.dart',
        lineNumber: 0,
        name: 'b.dart',
      );

      expect(
          _normalizeAnsi(withNullLine.toString()), startsWith('lib/a.dart:'));
      expect(
          _normalizeAnsi(withZeroLine.toString()), startsWith('lib/b.dart:'));
      expect(
        _normalizeAnsi(withZeroLine.toString()),
        equals('lib/b.dart: dead file b.dart'),
      );
    });

    test('toString formats function/class/variable names consistently', () {
      final deadFunction = DeadCodeIssue(
        type: DeadCodeIssueType.deadFunction,
        filePath: 'lib/f.dart',
        lineNumber: 12,
        name: 'unusedFn',
      );
      final deadClass = DeadCodeIssue(
        type: DeadCodeIssueType.deadClass,
        filePath: 'lib/c.dart',
        name: 'UnusedClass',
      );
      final unusedVariable = DeadCodeIssue(
        type: DeadCodeIssueType.unusedVariable,
        filePath: 'lib/v.dart',
        name: 'value',
      );
      final deadFile = DeadCodeIssue(
        type: DeadCodeIssueType.deadFile,
        filePath: 'lib/d.dart',
        name: 'd.dart',
      );

      expect(
        _normalizeAnsi(deadFunction.toString()),
        contains('dead function "unusedFn(...)"'),
      );
      expect(
        _normalizeAnsi(deadClass.toString()),
        contains('dead class "UnusedClass"'),
      );
      expect(
        _normalizeAnsi(unusedVariable.toString()),
        contains('unused variable "value"'),
      );
      expect(
        _normalizeAnsi(deadFile.toString()),
        contains('dead file d.dart'),
      );
    });

    test('toJson includes all expected fields', () {
      final issue = DeadCodeIssue(
        type: DeadCodeIssueType.deadFunction,
        filePath: 'lib/main.dart',
        lineNumber: 42,
        name: 'unusedFn',
        owner: 'MyClass',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'deadFunction',
          'filePath': 'lib/main.dart',
          'lineNumber': 42,
          'name': 'unusedFn',
          'owner': 'MyClass',
        }),
      );
    });

    test('format normalizes duplicated path prefixes', () {
      final issue = DeadCodeIssue(
        type: DeadCodeIssueType.unusedVariable,
        filePath: 'lib/a.dart:lib/a.dart',
        name: 'value',
      );

      expect(
        _normalizeAnsi(issue.format()),
        equals('lib/a.dart: unused variable "value"'),
      );
    });
  });

  group('Dead code analysis', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_dead_code_test');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: sample
version: 0.0.1
''');

      final libDir = Directory(p.join(tempDir.path, 'lib'));
      libDir.createSync(recursive: true);

      File(p.join(libDir.path, 'main.dart')).writeAsStringSync('''
import 'a.dart';

void main() {
  final a = A();
  a.toString();
  final box = Box<int>();
  box.toString();
}
''');

      File(p.join(libDir.path, 'a.dart')).writeAsStringSync('''
class A {}

class Box<T> {}
''');

      File(p.join(libDir.path, 'b.dart')).writeAsStringSync('''
class B {}

void unused() {}
''');

      File(p.join(libDir.path, 'vars.dart')).writeAsStringSync('''
void doStuff() {
  var x = 1;
}
''');

      File(p.join(libDir.path, 'override.dart')).writeAsStringSync('''
class BuildContext {}

abstract class WidgetBase {
  void build(BuildContext context);
}

class GameWidget extends WidgetBase {
  @override
  void build(BuildContext context) {}
}
''');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports dead files, classes, functions, and unused variables', () {
      final metrics = AnalyzeFolder(tempDir).analyze();
      final issues = metrics.deadCodeIssues;

      final deadFiles = issues
          .where((i) => i.type == DeadCodeIssueType.deadFile)
          .map((i) => i.filePath)
          .toList();

      expect(deadFiles, contains(p.join('lib', 'b.dart')));
      expect(deadFiles, contains(p.join('lib', 'vars.dart')));

      expect(
        issues.where(
            (i) => i.type == DeadCodeIssueType.deadClass && i.name == 'B'),
        isNotEmpty,
      );

      expect(
        issues.where((i) =>
            i.type == DeadCodeIssueType.deadFunction && i.name == 'unused'),
        isNotEmpty,
      );

      expect(
        issues.where(
            (i) => i.type == DeadCodeIssueType.unusedVariable && i.name == 'x'),
        isNotEmpty,
      );

      expect(
        issues.where((i) =>
            i.type == DeadCodeIssueType.unusedVariable && i.name == 'context'),
        isEmpty,
      );

      expect(
        issues.where(
            (i) => i.type == DeadCodeIssueType.deadClass && i.name == 'A'),
        isEmpty,
      );

      expect(
        issues.where(
            (i) => i.type == DeadCodeIssueType.deadClass && i.name == 'Box'),
        isEmpty,
      );
    });
  });
}
