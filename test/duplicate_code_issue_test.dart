import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:test/test.dart';

void main() {
  group('DuplicateCodeIssue', () {
    test('toJson returns all fields', () {
      final issue = DuplicateCodeIssue(
        firstFilePath: 'lib/a.dart',
        firstLineNumber: 10,
        firstSymbol: 'firstFn',
        secondFilePath: 'lib/b.dart',
        secondLineNumber: 20,
        secondSymbol: 'secondFn',
        similarity: 0.9,
        lineCount: 12,
      );

      expect(
        issue.toJson(),
        equals({
          'firstFilePath': 'lib/a.dart',
          'firstLineNumber': 10,
          'firstSymbol': 'firstFn',
          'secondFilePath': 'lib/b.dart',
          'secondLineNumber': 20,
          'secondSymbol': 'secondFn',
          'similarity': 0.9,
          'lineCount': 12,
        }),
      );
    });

    test('toString includes floored percent, line count, paths, and symbols',
        () {
      final issue = DuplicateCodeIssue(
        firstFilePath: 'lib/a.dart',
        firstLineNumber: 10,
        firstSymbol: 'firstFn',
        secondFilePath: 'lib/b.dart',
        secondLineNumber: 20,
        secondSymbol: 'secondFn',
        similarity: 0.875,
        lineCount: 9,
      );

      expect(
        issue.toString(),
        equals(
          '87% (9 lines) lib/a.dart:10 <-> lib/b.dart:20 (firstFn, secondFn)',
        ),
      );
    });

    test('toString strips shared absolute path prefix', () {
      final issue = DuplicateCodeIssue(
        firstFilePath: '/Users/me/workspace/project/lib/a.dart',
        firstLineNumber: 10,
        firstSymbol: 'firstFn',
        secondFilePath: '/Users/me/workspace/project/bin/b.dart',
        secondLineNumber: 20,
        secondSymbol: 'secondFn',
        similarity: 0.9,
        lineCount: 30,
      );

      expect(
        issue.toString(),
        equals(
          '90% (30 lines) lib/a.dart:10 <-> bin/b.dart:20 (firstFn, secondFn)',
        ),
      );
    });
  });
}
