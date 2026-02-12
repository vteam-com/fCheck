import 'dart:io';
import 'dart:convert';
import 'package:fcheck/src/models/version.dart';
import 'package:test/test.dart';

void main() {
  group('CLI Integration', () {
    late Directory tempDir;
    late Directory compiledCliDir;
    late String compiledCliPath;
    late String cliScriptPath;
    late String projectRootPath;
    late bool useCompiledCli;

    Future<ProcessResult> runCli(
      List<String> args, {
      String? workingDirectory,
      bool useDirectInvocation = false,
    }) {
      if (useDirectInvocation || !useCompiledCli) {
        return Process.run(
          'dart',
          ['run', cliScriptPath, ...args],
          workingDirectory: workingDirectory ?? projectRootPath,
          runInShell: true,
        );
      }

      return Process.run(
        compiledCliPath,
        args,
        workingDirectory: workingDirectory ?? projectRootPath,
        runInShell: true,
      );
    }

    setUpAll(() async {
      projectRootPath = Directory.current.path;
      cliScriptPath = '$projectRootPath/bin/fcheck.dart';
      compiledCliDir = await Directory.systemTemp.createTemp('fcheck_cli_bin_');
      final executableName =
          Platform.isWindows ? 'fcheck_cli_test.exe' : 'fcheck_cli_test';
      compiledCliPath = '${compiledCliDir.path}/$executableName';
      useCompiledCli = false;

      final compileResult = await Process.run(
        'dart',
        ['compile', 'exe', cliScriptPath, '-o', compiledCliPath],
        workingDirectory: projectRootPath,
        runInShell: true,
      );

      if (compileResult.exitCode == 0) {
        useCompiledCli = true;
      } else {
        stderr.writeln(
          'Warning: Failed to precompile fcheck CLI for tests. '
          'Falling back to direct dart run invocation.\n'
          'stdout: ${compileResult.stdout}\n'
          'stderr: ${compileResult.stderr}',
        );
      }
    });

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_cli_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    tearDownAll(() {
      if (compiledCliDir.existsSync()) {
        compiledCliDir.deleteSync(recursive: true);
      }
    });

    test('should run without arguments (current directory)', () async {
      // Create a simple Dart file in temp directory
      File('${tempDir.path}/main.dart').writeAsStringSync('''
// Test file
void main() {
  print("Hello");
}
''');

      // Keep one true dart run invocation for end-to-end process coverage.
      final result = await runCli(
        const [],
        workingDirectory: tempDir.path,
        useDirectInvocation: true,
      );

      // CLI may exit with non-zero code in test environment, but should produce output
      expect(result.stdout, contains('fCheck $packageVersion'));
    });

    test('should accept input argument', () async {
      // Create test project structure
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/test.dart').writeAsStringSync('''
// Test file
class TestClass {
  void method() {
    // Implementation
  }
}
''');

      // Run fcheck with input argument
      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, contains(tempDir.path));
      expect(result.stdout, contains('Dart Files'));
      expect(result.stdout, contains(RegExp(r'Compliance Score\s+:\s*')));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should accept short input option', () async {
      // Create test file
      File('${tempDir.path}/short.dart')
          .writeAsStringSync('void main() => print("test");');

      // Run fcheck with short option
      final result = await runCli(['-i', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should handle non-existent directory', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist';

      final result = await runCli(['--input', nonExistentPath]);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Error: Directory'));
      expect(result.stdout, contains('does not exist'));
    });

    test('should show help with --help flag', () async {
      final result = await runCli(['--help']);

      expect(result.exitCode, equals(0));
      expect(result.stdout,
          contains('Usage: dart run fcheck [options] [<folder>]'));
      expect(result.stdout, contains('Analyze Flutter/Dart code quality'));
      expect(result.stdout, contains('--input'));
      expect(result.stdout, contains('--fix'));
      expect(result.stdout, contains('--help'));
      expect(result.stdout, contains('--help-score'));
    });

    test('should show help with -h flag', () async {
      final result = await runCli(['-h']);

      expect(result.exitCode, equals(0));
      expect(result.stdout,
          contains('Usage: dart run fcheck [options] [<folder>]'));
      expect(result.stdout, contains('--input'));
    });

    test('should show ignore setup with --help-ignore flag', () async {
      final result = await runCli(['--help-ignore']);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Setup ignores directly in Dart file'));
      expect(
        result.stdout,
        contains('1. dead_code'),
      );
      expect(
        result.stdout,
        contains(
            '6. one_class_per_file | // ignore: fcheck_one_class_per_file'),
      );
      expect(
        result.stdout,
        contains('8. source_sorting'),
      );
      expect(
        result.stdout,
        contains('| (no comment ignore support)'),
      );
      expect(result.stdout, contains('Setup using the .fcheck file'));
      expect(result.stdout, contains('input:'));
      expect(result.stdout, contains('exclude:'));
      expect(result.stdout, contains('default: on|off'));
      expect(result.stdout, contains('disabled: # or enabled'));
      expect(result.stdout, contains('options:'));
      expect(result.stdout, contains('duplicate_code:'));
      expect(result.stdout, contains('similarity_threshold: 0.90'));
      expect(result.stdout, contains('min_tokens: 20'));
      expect(result.stdout, contains('min_non_empty_lines: 8'));
      expect(result.stdout, isNot(contains('enable:')));
    });

    test('should show ignore setup before validating input directory',
        () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist_for_ignores';

      final result = await runCli([
        '--help-ignore',
        '--input',
        nonExistentPath,
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Setup ignores directly in Dart file'));
      expect(result.stdout, isNot(contains('does not exist')));
    });

    test('should show score help with --help-score flag', () async {
      final result = await runCli(['--help-score']);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Compliance score model from 0% to 100%'));
      expect(result.stdout, contains('Only enabled analyzers contribute'));
      expect(result.stdout, contains('each analyzer share = 100 / N'));
      expect(result.stdout, contains('Special rule: if rounded score is 100'));
    });

    test('should show score help before validating input directory', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist_for_score_help';

      final result = await runCli([
        '--help-score',
        '--input',
        nonExistentPath,
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Compliance score model from 0% to 100%'));
      expect(result.stdout, isNot(contains('does not exist')));
    });

    test('should respect --list none flag', () async {
      File('${tempDir.path}/list_none.dart')
          .writeAsStringSync('void main() => print("list none");');

      final result = await runCli(['--input', tempDir.path, '--list', 'none']);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, isNot(contains('Lists')));
    });

    test('should detect class violations', () async {
      // Create a file with multiple classes (violates one class per file rule)
      File('${tempDir.path}/violation.dart').writeAsStringSync('''
// File with multiple classes
class FirstClass {
  void method1() {}
}

class SecondClass {
  void method2() {}
}
''');

      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('[✗]'));
      expect(result.stdout, contains('violate the "one class per file" rule'));
    });

    test('should ignore class violations with directive', () async {
      File('${tempDir.path}/ignored_violation.dart').writeAsStringSync('''
// ignore: fcheck_one_class_per_file
class FirstClass {
  void method1() {}
}

class SecondClass {
  void method2() {}
}
''');

      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('[✓] One class per file check passed.'));
    });

    test('should detect hardcoded strings', () async {
      // Create a file with hardcoded strings
      File('${tempDir.path}/strings.dart').writeAsStringSync('''
// File with hardcoded strings
void main() {
  print("This is hardcoded");
  print("Another hardcoded string");
  print(42);
}
''');

      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('[!]'));
      expect(
        result.stdout,
        contains('Hardcoded strings check skipped (localization off).'),
      );
      expect(result.stdout, contains('localization off'));
      expect(result.stdout, contains('magic numbers detected'));
    });

    test('explicit input option should win over positional argument', () async {
      // Create test files in two different directories
      final dir1 = Directory('${tempDir.path}/dir1')..createSync();
      final dir2 = Directory('${tempDir.path}/dir2')..createSync();

      File('${dir1.path}/test1.dart')
          .writeAsStringSync('void main() => print("dir1");');
      File('${dir2.path}/test2.dart')
          .writeAsStringSync('void main() => print("dir2");');

      // Run with both explicit option and positional argument - explicit should win
      final result = await runCli(['--input', dir1.path, dir2.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, contains(dir1.path));
      expect(result.stdout, isNot(contains(dir2.path)));
    });

    test('should accept positional path argument', () async {
      // Create test file
      File('${tempDir.path}/positional.dart')
          .writeAsStringSync('void main() => print("positional test");');

      // Run fcheck with positional argument
      final result = await runCli([tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck $packageVersion'));
      expect(result.stdout, contains(tempDir.path));
    });
    test('should output structured JSON with --json flag', () async {
      // Create two files with a dependency
      File('${tempDir.path}/a.dart').writeAsStringSync('import "b.dart";');
      File('${tempDir.path}/b.dart').writeAsStringSync('class B {}');

      final result = await runCli(['--input', tempDir.path, '--json']);

      expect(result.exitCode, equals(0));

      // Verify it's valid JSON
      final json = jsonDecode(result.stdout as String);
      expect(json, isA<Map<String, dynamic>>());
      expect(json['project'], isNotNull);
      expect(json['stats'], isNotNull);
      expect(json['stats']['excludedFiles'], isNotNull);
      expect(json['stats']['duplicateCodeIssues'], isNotNull);
      expect(json['stats']['complianceScore'], isNotNull);
      expect(json['layers']['dependencies'], isNotNull);
      expect(json['compliance'], isNotNull);
      expect(json['compliance']['score'], isNotNull);
      final graph = json['layers']['graph'] as Map<String, dynamic>;
      expect(graph.keys.any((k) => k.endsWith('a.dart')), isTrue);
      final aKey = graph.keys.firstWhere((k) => k.endsWith('a.dart'));
      expect(graph[aKey], contains(contains('b.dart')));
      expect(json['magicNumbers'], isA<List<dynamic>>());
    });

    test('should disable analyzers via .fcheck', () async {
      File('${tempDir.path}/main.dart').writeAsStringSync('''
void main() {
  print("Hardcoded");
}
''');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  disabled:
    - hardcoded_strings
''');

      final result = await runCli(['--input', tempDir.path, '--json']);

      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final stats = json['stats'] as Map<String, dynamic>;
      expect(stats['hardcodedStrings'], equals(0));
    });

    test('should show skipped message for disabled analyzer in text output',
        () async {
      File('${tempDir.path}/main.dart').writeAsStringSync('''
void main() {
  print("Hardcoded");
}
''');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  disabled:
    - hardcoded_strings
''');

      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Localization'));
      expect(result.stdout, contains('HardCoded'));
      expect(result.stdout, contains('disabled'));
      expect(
        result.stdout,
        contains('Hardcoded strings check skipped (disabled).'),
      );
      expect(result.stdout, isNot(contains('Hardcoded strings check passed.')));
    });

    test('should support analyzer opt-in mode via .fcheck', () async {
      File('${tempDir.path}/main.dart').writeAsStringSync('''
void main() {
  print("Hardcoded");
  print(7);
}
''');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  default: off
  enabled:
    - magic_numbers
''');

      final result = await runCli(['--input', tempDir.path, '--json']);

      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final stats = json['stats'] as Map<String, dynamic>;
      expect(stats['hardcodedStrings'], equals(0));
      expect(stats['magicNumbers'], equals(1));
    });

    test('should respect input root and exclude patterns from .fcheck',
        () async {
      final appDir = Directory('${tempDir.path}/app')..createSync();
      final generatedDir = Directory('${appDir.path}/generated')..createSync();
      File('${appDir.path}/main.dart').writeAsStringSync('''
void main() {
  print(2);
}
''');
      File('${generatedDir.path}/skip.dart').writeAsStringSync('''
void skip() {
  print(7);
}
''');
      File('${tempDir.path}/outside.dart').writeAsStringSync('''
void outside() {
  print(9);
}
''');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
input:
  root: app
  exclude:
    - "**/generated/**"
analyzers:
  default: off
  enabled:
    - magic_numbers
    - layers
''');

      final result = await runCli(['--input', tempDir.path, '--json']);

      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final stats = json['stats'] as Map<String, dynamic>;
      expect(stats['dartFiles'], equals(1));
      expect(stats['magicNumbers'], equals(1));

      final graph = json['layers']['graph'] as Map<String, dynamic>;
      expect(graph.keys.length, equals(1));
      expect(graph.keys.first, contains('app/main.dart'));
    });

    test('should apply duplicate code options from .fcheck', () async {
      File('${tempDir.path}/a.dart').writeAsStringSync('''
int a(int x) {
  return x + 1;
}
''');
      File('${tempDir.path}/b.dart').writeAsStringSync('''
int b(int x) {
  return x + 1;
}
''');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  default: off
  enabled:
    - duplicate_code
  options:
    duplicate_code:
      similarity_threshold: 0.85
      min_tokens: 1
      min_non_empty_lines: 1
''');

      final result = await runCli(['--input', tempDir.path, '--json']);

      expect(result.exitCode, equals(0));
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final stats = json['stats'] as Map<String, dynamic>;
      expect(stats['duplicateCodeIssues'], equals(1));
    });

    test('should fail with readable error for invalid .fcheck', () async {
      File('${tempDir.path}/main.dart').writeAsStringSync('void main() {}');
      File('${tempDir.path}/.fcheck').writeAsStringSync('''
analyzers:
  disabled:
    - unknown_analyzer
''');

      final result = await runCli(['--input', tempDir.path]);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Invalid .fcheck configuration'));
      expect(result.stdout, contains('unknown analyzer'));
    });
  });
}
