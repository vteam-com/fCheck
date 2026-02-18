import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:test/test.dart';

void main() {
  group('HardcodedStringIssue', () {
    test('toString includes file path, line number, and quoted value', () {
      final issue = HardcodedStringIssue(
        filePath: 'lib/main.dart',
        lineNumber: 12,
        value: 'Hello World',
      );

      expect(issue.toString(), equals('lib/main.dart:12: "Hello World"'));
    });

    test('toJson returns all fields', () {
      final issue = HardcodedStringIssue(
        filePath: 'lib/main.dart',
        lineNumber: 12,
        value: 'Hello World',
      );

      expect(
        issue.toJson(),
        equals({
          'filePath': 'lib/main.dart',
          'lineNumber': 12,
          'value': 'Hello World',
        }),
      );
    });
  });
}
