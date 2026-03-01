import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_delegate.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_delegate.dart';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

AnalysisFileContext _contextForFile(File file) {
  final content = file.readAsStringSync();
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return AnalysisFileContext(
    file: file,
    content: content,
    parseResult: parseResult,
    lines: content.split('\n'),
    compilationUnit: parseResult.unit,
    hasParseErrors: parseResult.errors.isNotEmpty,
  );
}

void main() {
  group('MagicNumberDelegate Ignore Directive', () {
    late Directory tempDir;
    late MagicNumberDelegate delegate;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      delegate = MagicNumberDelegate();
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

        final issues = delegate.analyzeFileWithContext(_contextForFile(file));
        expect(issues, isEmpty);
      },
    );

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

        final issues = delegate.analyzeFileWithContext(_contextForFile(file));
        expect(issues, isEmpty);
      },
    );

    test('should NOT ignore magic numbers when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
void main() {
  var x = 42;
}
''');

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
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

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
      expect(issues, isNotEmpty);
    });

    test('should ignore with flexible whitespace in inline directive', () {
      final file = File(p.join(tempDir.path, 'inline_whitespace.dart'));
      file.writeAsStringSync('''
void main() { //ignore : fcheck_magic_numbers
  var x = 42;
}
''');

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
      expect(issues, isEmpty);
    });
  });

  group('HardcodedStringDelegate Ignore Directive', () {
    late Directory tempDir;
    late HardcodedStringDelegate delegate;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_ignore_test');
      delegate = HardcodedStringDelegate();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should ignore hardcoded strings when directive is present ()', () {
      final file = File(p.join(tempDir.path, 'ignored.dart'));
      file.writeAsStringSync('''
// ignore: fcheck_hardcoded_strings

void main() {
  var message = "Hello World";
}
''');

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
      expect(issues, isEmpty);
    });

    test(
      'should ignore hardcoded strings when directive is present ( with multiple lines)',
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

        final issues = delegate.analyzeFileWithContext(_contextForFile(file));
        expect(issues, isEmpty);
      },
    );

    test('should NOT ignore hardcoded strings when directive is absent', () {
      final file = File(p.join(tempDir.path, 'not_ignored.dart'));
      file.writeAsStringSync('''
void main() {
  var message = "Hello World";
}
''');

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
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

      final issues = delegate.analyzeFileWithContext(_contextForFile(file));
      expect(issues, isNotEmpty);
    });
  });
}
