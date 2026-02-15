import 'dart:convert';
import 'dart:io';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:test/test.dart';

void main() {
  group('printScoreSystemGuide', () {
    late Directory tempDir;
    late String projectRootPath;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('fcheck_console_output_test_');
      projectRootPath = Directory.current.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should print score system guide when --help-score flag is provided',
        () async {
      final result = await Process.run(
        'dart',
        ['run', '$projectRootPath/bin/fcheck.dart', '--help-score'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains(AppStrings.complianceScoreModel));
      expect(result.stdout, contains('Only enabled analyzers contribute'));
      expect(result.stdout, contains('each analyzer share = 100 / N'));
      expect(result.stdout, contains('Special rule: if rounded score is 100'));
    });

    test('should print score system guide before validating input directory',
        () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist_for_score_help';

      final result = await Process.run(
        'dart',
        [
          'run',
          '$projectRootPath/bin/fcheck.dart',
          '--help-score',
          '--input',
          nonExistentPath,
        ],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Compliance score model from 0% to 100%'));
      expect(result.stdout, isNot(contains('does not exist')));
    });
  });

  group('printIgnoreSetupGuide', () {
    late String projectRootPath;

    setUp(() {
      projectRootPath = Directory.current.path;
    });

    test('should print ignore setup guide when --help-ignore flag is provided',
        () async {
      final result = await Process.run(
        'dart',
        ['run', '$projectRootPath/bin/fcheck.dart', '--help-ignore'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Setup ignores directly in Dart file'));
      expect(result.stdout, contains('1. dead_code'));
      expect(result.stdout, contains('Setup using the .fcheck file'));
    });

    test('should print ignore setup guide before validating input directory',
        () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          '$projectRootPath/bin/fcheck.dart',
          '--help-ignore',
          '--input',
          '/tmp/does_not_exist_xyz',
        ],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Setup ignores directly in Dart file'));
      expect(result.stdout, isNot(contains('does not exist')));
    });
  });

  group('list option', () {
    late String projectRootPath;

    setUp(() {
      projectRootPath = Directory.current.path;
    });

    test('should handle --list flag with valid values', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          '$projectRootPath/bin/fcheck.dart',
          '--list',
          'partial',
        ],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
    });

    test('should handle --list flag with invalid values', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          '$projectRootPath/bin/fcheck.dart',
          '--list',
          'invalid_value',
        ],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
    });
  });

  group('json output', () {
    late String projectRootPath;

    setUp(() {
      projectRootPath = Directory.current.path;
    });

    test('should output valid JSON when --json flag is provided', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          '$projectRootPath/bin/fcheck.dart',
          '--json',
        ],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, isNotNull);
      expect(result.stdout, isNotEmpty);

      try {
        final json = jsonDecode(result.stdout);
        expect(json, isNotNull);
        expect(json, isMap);
      } catch (e) {
        fail('Output is not valid JSON: $e');
      }
    });
  });
}
