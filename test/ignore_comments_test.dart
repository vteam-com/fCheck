import 'dart:io';
import 'package:test/test.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_analyzer.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MagicNumberAnalyzer Ignore Directive', () {
    late Directory tempDir;
    late MagicNumberAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      analyzer = MagicNumberAnalyzer();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'should ignore magic numbers when directive is present (// ignore: fcheck_magic_numbers)',
        () {
      final file = File(p.join(tempDir.path, 'ignored.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_magic_numbers
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test(
        'should ignore magic numbers when directive is present (// ignore: fcheck_magic_numbers with multiple lines)',
        () {
      final file = File(p.join(tempDir.path, 'ignored_multiline.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_magic_numbers
// This is a multi-line comment
// with additional information
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('should NOT ignore magic numbers when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
void main() {
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
      expect(issues.first.value, '42');
    });

    test('should NOT ignore if directive is not at the top', () {
      final file = File(p.join(tempDir.path, 'not_at_top.dart'));
      file.writeAsStringSync('''
void main() {
  // ignore: fcheck_magic_numbers
  var x = 42;
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
    });
  });

  group('HardcodedStringAnalyzer Ignore Directive', () {
    late Directory tempDir;
    late HardcodedStringAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      analyzer = HardcodedStringAnalyzer();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'should ignore hardcoded strings when directive is present (// ignore: fcheck_hardcoded_strings)',
        () {
      final file = File(p.join(tempDir.path, 'ignored.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_hardcoded_strings
void main() {
  var message = "Hello World";
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test(
        'should ignore hardcoded strings when directive is present (// ignore: fcheck_hardcoded_strings with multiple lines)',
        () {
      final file = File(p.join(tempDir.path, 'ignored_multiline.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_hardcoded_strings
// This is a multi-line comment
// with additional information
void main() {
  var message = "Hello World";
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('should NOT ignore hardcoded strings when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
void main() {
  var message = "Hello World";
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
      expect(issues.first.value, 'Hello World');
    });

    test('should NOT ignore if directive is not at the top', () {
      final file = File(p.join(tempDir.path, 'not_at_top.dart'));
      file.writeAsStringSync('''
void main() {
  // ignore: fcheck_hardcoded_strings
  var message = "Hello World";
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
    });
  });

  group('LayersAnalyzer Ignore Directive', () {
    late Directory tempDir;
    late LayersAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      analyzer = LayersAnalyzer(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
        'should ignore layers violations when directive is present (// ignore: fcheck_layers)',
        () {
      final file = File(p.join(tempDir.path, 'ignored.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_layers
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test(
        'should ignore layers violations when directive is present (// ignore: fcheck_layers with multiple lines)',
        () {
      final file = File(p.join(tempDir.path, 'ignored_multiline.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_layers
// This is a multi-line comment
// with additional information
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isEmpty);
    });

    test('should NOT ignore layers violations when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
    });

    test('should NOT ignore if directive is not at the top', () {
      final file = File(p.join(tempDir.path, 'not_at_top.dart'));
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  // ignore: fcheck_layers
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''');

      final issues = analyzer.analyzeFile(file);
      expect(issues, isNotEmpty);
    });
  });
}
