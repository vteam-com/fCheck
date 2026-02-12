import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:test/test.dart';

void main() {
  group('MagicNumberIssue', () {
    test('formats with standard file:line output', () {
      final issue = MagicNumberIssue(
        filePath: 'lib/main.dart',
        lineNumber: 12,
        value: '2',
      );

      expect(issue.format(), equals('lib/main.dart:12: 2'));
    });

    test('normalizes duplicated path prefixes in format output', () {
      final issue = MagicNumberIssue(
        filePath:
            'lib/src/analyzers/magic_numbers/magic_number_visitor.dart:lib/src/analyzers/magic_numbers/magic_number_visitor.dart',
        lineNumber: 35,
        value: '2',
      );

      expect(
        issue.format(),
        equals(
          'lib/src/analyzers/magic_numbers/magic_number_visitor.dart:35: 2',
        ),
      );
    });
  });
}
