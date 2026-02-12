import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:test/test.dart';

void main() {
  group('Issue location formatting', () {
    test('HardcodedStringIssue uses file:line with no space', () {
      final issue = HardcodedStringIssue(
        filePath: 'lib/a.dart',
        lineNumber: 12,
        value: 'hello',
      );

      expect(issue.format(lineNumberWidth: 6), startsWith('lib/a.dart:12:'));
    });

    test('MagicNumberIssue uses file:line with no space', () {
      final issue = MagicNumberIssue(
        filePath: 'lib/a.dart',
        lineNumber: 12,
        value: '42',
      );

      expect(issue.format(lineNumberWidth: 6), startsWith('lib/a.dart:12:'));
    });

    test('SecretIssue uses file:line with no space', () {
      final issue = SecretIssue(
        filePath: 'lib/a.dart',
        lineNumber: 12,
        secretType: 'api_key',
        value: 'secret',
      );

      expect(
        issue.format(lineNumberWidth: 6),
        contains('Secret issue at lib/a.dart:12:'),
      );
    });

    test('DeadCodeIssue uses file:line with no space', () {
      final issue = DeadCodeIssue(
        type: DeadCodeIssueType.deadFunction,
        filePath: 'lib/a.dart',
        lineNumber: 12,
        name: 'unusedFn',
      );

      expect(issue.format(lineNumberWidth: 6), startsWith('lib/a.dart:12:'));
    });

    test('DocumentationIssue uses file:line with no space', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedPublicFunction,
        filePath: 'lib/a.dart',
        lineNumber: 12,
        subject: 'runTask',
      );

      expect(issue.format(lineNumberWidth: 6), startsWith('lib/a.dart:12:'));
    });

    test('SourceSortIssue uses file:line with no space', () {
      final issue = SourceSortIssue(
        filePath: 'lib/a.dart',
        className: 'MyWidget',
        lineNumber: 12,
        description: 'sort issue',
      );

      expect(issue.format(lineNumberWidth: 6), startsWith('lib/a.dart:12 '));
    });
  });
}
