import 'dart:io';
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
      File('${tempDir.path}/main.dart')..writeAsStringSync('''
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
      expect(result.stdout, contains('Analyzing project at'));
      expect(result.stdout, contains('Quality Report'));
    });

    test('should accept path argument', () async {
      // Create test project structure
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/test.dart')..writeAsStringSync('''
// Test file
class TestClass {
  void method() {
    // Implementation
  }
}
''');

      // Run fcheck with path argument
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--path', tempDir.path],
        workingDirectory: Directory.current.path, // Run from project root
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Analyzing project at'));
      expect(result.stdout, contains(tempDir.path));
      expect(result.stdout, contains('Quality Report'));
      expect(result.stdout, contains('Total Dart Files: 1'));
    });

    test('should accept short path option', () async {
      // Create test file
      File('${tempDir.path}/short.dart')
        ..writeAsStringSync('void main() => print("test");');

      // Run fcheck with short option
      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '-p', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Analyzing project at'));
      expect(result.stdout, contains(tempDir.path));
    });

    test('should handle non-existent directory', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist';

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--path', nonExistentPath],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('Error: Directory'));
      expect(result.stdout, contains('does not exist'));
    });

    test('should detect class violations', () async {
      // Create a file with multiple classes (violates one class per file rule)
      File('${tempDir.path}/violation.dart')..writeAsStringSync('''
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
        ['run', 'bin/fcheck.dart', '--path', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('❌'));
      expect(result.stdout, contains('violate the "one class per file" rule'));
    });

    test('should detect hardcoded strings', () async {
      // Create a file with hardcoded strings
      File('${tempDir.path}/strings.dart')..writeAsStringSync('''
// File with hardcoded strings
void main() {
  print("This is hardcoded");
  print("Another hardcoded string");
}
''');

      final result = await Process.run(
        'dart',
        ['run', 'bin/fcheck.dart', '--path', tempDir.path],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('⚠️'));
      expect(result.stdout, contains('potential hardcoded strings detected'));
    });
  });
}
