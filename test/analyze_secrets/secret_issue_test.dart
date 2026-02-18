import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:test/test.dart';

void main() {
  group('SecretIssue', () {
    test('toJson returns all fields', () {
      final issue = SecretIssue(
        filePath: 'lib/main.dart',
        lineNumber: 14,
        secretType: 'aws_access_key',
        value: 'AKIA_TEST_VALUE',
      );

      expect(
        issue.toJson(),
        equals({
          'filePath': 'lib/main.dart',
          'lineNumber': 14,
          'secretType': 'aws_access_key',
          'value': 'AKIA_TEST_VALUE',
        }),
      );
    });

    test('toString includes file path and line number when both exist', () {
      final issue = SecretIssue(
        filePath: 'lib/config.dart',
        lineNumber: 8,
        secretType: 'token',
      );

      expect(
        issue.toString(),
        equals('Secret issue at lib/config.dart:8: token'),
      );
    });

    test('toString falls back to file path when line number is missing', () {
      final issue = SecretIssue(
        filePath: 'lib/env.dart',
        secretType: 'password',
      );

      expect(
        issue.toString(),
        equals('Secret issue at lib/env.dart: password'),
      );
    });

    test(
      'toString falls back to unknown location when file path is missing',
      () {
        final issue = SecretIssue(lineNumber: 22, secretType: 'private_key');

        expect(
          issue.toString(),
          equals('Secret issue at unknown location: private_key'),
        );
      },
    );
  });
}
