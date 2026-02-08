import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
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
}
''');

      File(p.join(libDir.path, 'a.dart')).writeAsStringSync('''
class A {}
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
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports dead files, classes, functions, and unused variables', () {
      final metrics = AnalyzeFolder(tempDir).analyze();
      final issues = metrics.deadCodeIssues;

      final libDir = p.join(tempDir.path, 'lib');
      final deadFiles = issues
          .where((i) => i.type == DeadCodeIssueType.deadFile)
          .map((i) => i.filePath)
          .toList();

      expect(deadFiles, contains(p.join(libDir, 'b.dart')));
      expect(deadFiles, contains(p.join(libDir, 'vars.dart')));

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
        issues.where(
            (i) => i.type == DeadCodeIssueType.deadClass && i.name == 'A'),
        isEmpty,
      );
    });
  });
}
