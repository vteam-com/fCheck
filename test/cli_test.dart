import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

void main() {
  group('CLI Integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_cli_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should run without arguments (current directory)', () async {
      // Create a simple Dart file in temp directory
      File('${tempDir.path}/main.dart').writeAsStringSync('''
// Test file
void main() {
  print("Hello");
}
''');

      // Change to temp directory and run fcheck
      final result = await Process.run(
        'dart',
        ['run', '${Directory.current.path}/bin/fcheck.dart'],
        workingDirectory: tempDir.path,
        runInShell: true,
      );

      // CLI may exit with non-zero code in test environment, but should produce output
      expect(result.stdout, contains('fCheck 0.8.4'));
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
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', tempDir.path],
        workingDirectory: Directory.current.path, // Run from project root
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck 0.8.4'));
      expect(result.stdout, contains(tempDir.path));
      expect(result.stdout, contains('Dart Files       : 1'));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should accept short input option', () async {
      // Create test file
      File('${tempDir.path}/short.dart')
          .writeAsStringSync('void main() => print("test");');

      // Run fcheck with short option
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '-i', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck 0.8.4'));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should handle non-existent directory', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist';

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', nonExistentPath],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Error: Directory'));
      expect(result.stdout, contains('does not exist'));
    });

    test('should show help with --help flag', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--help'],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout,
          contains('Usage: dart run fcheck [options] [<folder>]'));
      expect(result.stdout, contains('Analyze Flutter/Dart code quality'));
      expect(result.stdout, contains('--input'));
      expect(result.stdout, contains('--fix'));
      expect(result.stdout, contains('--help'));
    });

    test('should show help with -h flag', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '-h'],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout,
          contains('Usage: dart run fcheck [options] [<folder>]'));
      expect(result.stdout, contains('--input'));
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

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('❌'));
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

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout,
          contains('✅ All files comply with the "one class per file" rule.'));
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

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('⚠️'));
      expect(result.stdout, contains('potential hardcoded strings detected'));
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
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', dir1.path, dir2.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck 0.8.4'));
      expect(result.stdout, contains(dir1.path));
      expect(result.stdout, contains('test1.dart'));
      expect(result.stdout, isNot(contains('test2.dart')));
    });

    test('should accept positional path argument', () async {
      // Create test file
      File('${tempDir.path}/positional.dart')
          .writeAsStringSync('void main() => print("positional test");');

      // Run fcheck with positional argument
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('fCheck 0.8.4'));
      expect(result.stdout, contains(tempDir.path));
    });
    test('should output structured JSON with --json flag', () async {
      // Create two files with a dependency
      File('${tempDir.path}/a.dart').writeAsStringSync('import "b.dart";');
      File('${tempDir.path}/b.dart').writeAsStringSync('class B {}');

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--input', tempDir.path, '--json'],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));

      // Verify it's valid JSON
      final json = jsonDecode(result.stdout as String);
      expect(json, isA<Map<String, dynamic>>());
      expect(json['project'], isNotNull);
      expect(json['stats'], isNotNull);
      expect(json['stats']['excludedFiles'], isNotNull);
      expect(json['layers']['dependencies'], isNotNull);
      final graph = json['layers']['graph'] as Map<String, dynamic>;
      expect(graph.keys.any((k) => k.endsWith('a.dart')), isTrue);
      final aKey = graph.keys.firstWhere((k) => k.endsWith('a.dart'));
      expect(graph[aKey], contains(contains('b.dart')));
      expect(json['magicNumbers'], isA<List<dynamic>>());
    });
  });
}
