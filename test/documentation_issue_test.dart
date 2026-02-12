import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentationIssue', () {
    test('formats with line number when present', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedPublicFunction,
        filePath: 'lib/main.dart',
        lineNumber: 12,
        subject: 'runApp',
      );

      expect(
        issue.format(),
        equals(
          'lib/main.dart:12: public function is missing documentation "runApp"',
        ),
      );
    });

    test('serializes toJson with all fields', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.missingReadme,
        filePath: '/project/README.md',
        subject: 'README.md',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'missingReadme',
          'filePath': '/project/README.md',
          'lineNumber': null,
          'subject': 'README.md',
        }),
      );
    });

    test('normalizes duplicated path prefixes in format output', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedComplexPrivateFunction,
        filePath:
            'lib/src/analyzers/magic_numbers/magic_number_visitor.dart:lib/src/analyzers/magic_numbers/magic_number_visitor.dart',
        subject: 'MagicNumberVisitor._inspectLiteral',
      );

      expect(
        issue.format(),
        equals(
          'lib/src/analyzers/magic_numbers/magic_number_visitor.dart: complex private function is missing documentation "MagicNumberVisitor._inspectLiteral"',
        ),
      );
    });

    test('uses embedded line from file path when lineNumber is null', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedPublicFunction,
        filePath: 'lib/main.dart:44',
        subject: 'runApp',
      );

      expect(
        issue.format(),
        equals(
          'lib/main.dart:44: public function is missing documentation "runApp"',
        ),
      );
    });
  });
}
