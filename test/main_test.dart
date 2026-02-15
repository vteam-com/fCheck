import 'dart:io';
import 'dart:convert';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/models/version.dart';
import 'package:test/test.dart';

/// Unit tests for the main() function in bin/fcheck.dart
///
/// These tests verify the behavior of the main() entry point including:
/// - Argument parsing errors
/// - Help/version display
/// - Directory validation
/// - Configuration loading
void main() {
  group('main() function', () {
    late Directory tempDir;
    late String projectRootPath;
    late String cliScriptPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_main_test_');
      projectRootPath = Directory.current.path;
      cliScriptPath = '$projectRootPath/bin/fcheck.dart';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should exit with code 1 for invalid arguments', () async {
      // Use an invalid flag that will cause parseConsoleInput to throw
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--invalid-flag-xyz'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      // Exit code 1 indicates an error (though sometimes dart may suppress the error message)
      expect(result.exitCode, equals(1));
    });

    test('should show help and exit with code 0 for --help flag', () async {
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--help'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains(AppStrings.usageLine));
      expect(result.stdout, contains(AppStrings.descriptionLine));
    });

    test('should show version and exit with code 0 for --version flag',
        () async {
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--version'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains(packageVersion));
    });

    test(
        'should show ignore instructions and exit with code 0 for --help-ignore flag',
        () async {
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--help-ignore'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Setup ignores directly in Dart file'));
      expect(result.stdout, contains('1. dead_code'));
    });

    test(
        'should show score instructions and exit with code 0 for --help-score flag',
        () async {
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--help-score'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Compliance score model from 0% to 100%'));
    });

    test('should exit with code 1 for non-existent input directory', () async {
      final nonExistentPath = '${tempDir.path}/non_existent_dir_12345';

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', nonExistentPath],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Error'));
      expect(result.stdout, contains('does not exist'));
    });

    test('should exit with code 1 for invalid .fcheck configuration', () async {
      // Create a directory with an invalid .fcheck file
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  disabled:
    - unknown_analyzer_xyz
''');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', tempDir.path],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Invalid .fcheck configuration'));
    });

    test('should run analysis successfully for valid input directory',
        () async {
      // Create a simple Dart project
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/main.dart').writeAsStringSync('''
void main() {
  print("Hello World");
}
''');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', tempDir.path],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should output JSON when --json flag is provided', () async {
      // Create a simple Dart project
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/main.dart').writeAsStringSync('''
void main() {
  print("Hello");
}
''');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', tempDir.path, '--json'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));

      // Verify it's valid JSON
      final json = jsonDecode(result.stdout as String);
      expect(json, isA<Map<String, dynamic>>());
      expect(json['project'], isNotNull);
      expect(json['stats'], isNotNull);
      expect(json['compliance'], isNotNull);
    });

    test('should list excluded files when --excluded flag is provided',
        () async {
      // Create a Dart project with excluded files
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      final generatedDir = Directory('${libDir.path}/generated')..createSync();

      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');
      File('${generatedDir.path}/generated.dart')
          .writeAsStringSync('void generated() {}');

      File('${tempDir.path}/.fcheck').writeAsStringSync('''
input:
  exclude:
    - "**/generated/**"
''');

      // The flag is --excluded (short -x), not --list-excluded
      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', tempDir.path, '--excluded'],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Excluded'));
    });

    test('should exit with code 0 for help flags even with non-existent input',
        () async {
      // This tests that help flags take precedence over directory validation
      final nonExistentPath = '${tempDir.path}/does_not_exist_xyz';

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--help', '--input', nonExistentPath],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains(AppStrings.usageLine));
      expect(result.stdout, isNot(contains('does not exist')));
    });

    test('should accept -i short flag for input', () async {
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '-i', tempDir.path],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
    });

    test('should accept positional argument as input path', () async {
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, tempDir.path],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
    });

    test('should handle analysis errors gracefully', () async {
      // Create a directory with a Dart file that might cause issues
      // Using an empty directory with no Dart files should still work
      // but we can test with a file that has parse issues

      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/syntax.dart').writeAsStringSync('''
// This file has intentional syntax error
void main() {
  print(
''');

      final result = await Process.run(
        'dart',
        ['run', cliScriptPath, '--input', tempDir.path],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      // The tool should handle analysis errors gracefully
      // Either exit 0 with results (partial) or exit 1 with error message
      expect(
        result.exitCode,
        anyOf(equals(0), equals(1)),
        reason: 'Should either complete or fail gracefully',
      );
    });
  });
}
