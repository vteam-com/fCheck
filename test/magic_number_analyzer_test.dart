import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_delegate.dart';

import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:test/test.dart';

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

List<MagicNumberIssue> _analyzeFile(
  MagicNumberDelegate delegate,
  File file,
) {
  final context = _contextForFile(file);
  return delegate.analyzeFileWithContext(context);
}

List<MagicNumberIssue> _analyzeDirectory(
  MagicNumberDelegate delegate,
  Directory directory,
) {
  final issues = <MagicNumberIssue>[];
  final dartFiles = FileUtils.listDartFiles(directory);
  for (final file in dartFiles) {
    issues.addAll(_analyzeFile(delegate, file));
  }
  return issues;
}

void main() {
  group('MagicNumberDelegate', () {
    late MagicNumberDelegate delegate;
    late Directory tempDir;

    setUp(() {
      delegate = MagicNumberDelegate();
      tempDir = Directory.systemTemp.createTempSync('fcheck_magic_numbers_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns empty list for empty file', () {
      final file = File('${tempDir.path}/empty.dart')..writeAsStringSync('');
      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('detects simple magic numbers', () {
      final file = File('${tempDir.path}/simple.dart')..writeAsStringSync('''
void main() {
  print(42);
  print(0);
}
''');

      final issues = _analyzeFile(delegate, file);

      expect(issues.length, equals(1));
      expect(issues[0].value, equals('42'));
      expect(issues[0].lineNumber, equals(2));
    });

    test('skips const declarations', () {
      final file = File('${tempDir.path}/const.dart')..writeAsStringSync('''
const int maxAttempts = 3;

void main() {
  print("ready");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('skips ignored literal values', () {
      final file = File('${tempDir.path}/ignored.dart')..writeAsStringSync('''
void main() {
  print(0);
  print(1);
  print(-1);
  print(2);
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('2'));
    });

    test('skips annotation arguments', () {
      final file = File('${tempDir.path}/annotation.dart')
        ..writeAsStringSync('''
@Deprecated(1)
void main() {}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('analyzes directory contents', () {
      File('${tempDir.path}/file1.dart')
          .writeAsStringSync('void main() => print(8);');
      File('${tempDir.path}/file2.dart')
          .writeAsStringSync('void main() => print(9);');
      File('${tempDir.path}/README.txt')
          .writeAsStringSync('This is not a Dart file.');

      final issues = _analyzeDirectory(delegate, tempDir);

      expect(issues.length, equals(2));
      expect(issues.map((issue) => issue.value), contains('8'));
      expect(issues.map((issue) => issue.value), contains('9'));
    });

    test('skips static const declarations with descriptive names', () {
      final file = File('${tempDir.path}/static_const.dart')
        ..writeAsStringSync('''
        class MyClass {
          static const int searchBoxFillAlpha = 77;
          static const double roomItemLeadingWidth = 40.0;
        }
      ''');
      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('skips final numeric declarations with descriptive names', () {
      final file = File('${tempDir.path}/final_numeric.dart')
        ..writeAsStringSync('''
        class MyClass {
          final int theFinalIntValue = 42;
          final double theFinalDoubleValue = 3.14;
          final num theFinalNumValue = 100;
        }
      ''');
      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });
  });
}
