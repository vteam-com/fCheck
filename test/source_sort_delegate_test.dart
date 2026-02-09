import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegates.dart';
import 'package:test/test.dart';

AnalysisFileContext _contextForSource(
  Directory tempDir,
  String source, {
  String fileName = 'sample.dart',
  String? contentOverride,
}) {
  final file = File('${tempDir.path}/$fileName')..writeAsStringSync(source);
  final parseResult = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final content = contentOverride ?? source;

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
  group('SourceSortDelegate', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_source_sort_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns no issues when file has parse errors', () {
      final context = _contextForSource(
        tempDir,
        'class A extends StatelessWidget { void broken( }',
        fileName: 'parse_error.dart',
      );

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('returns no issues for non-Flutter classes', () {
      final context = _contextForSource(
        tempDir,
        '''
class PlainClass {
  void zebra() {}
  void alpha() {}
}
''',
        fileName: 'plain.dart',
      );

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('skips target class with empty members', () {
      final context = _contextForSource(
        tempDir,
        'class EmptyWidget extends StatelessWidget {}',
        fileName: 'empty_widget.dart',
      );

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('returns no issues when class members are already sorted', () {
      final context = _contextForSource(
        tempDir,
        '''
class SortedWidget extends StatelessWidget {
  void initState() {}

  void build() {}

  void alpha() {}
  void beta() {}

  void _alpha() {}
  void _beta() {}
}
''',
        fileName: 'sorted.dart',
      );

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('reports issue for unsorted Flutter class when fix is false', () {
      final context = _contextForSource(
        tempDir,
        '''
class UnsortedWidget extends StatelessWidget {
  void zebra() {}
  void alpha() {}
}
''',
        fileName: 'unsorted.dart',
      );

      final delegate = SourceSortDelegate(fix: false);
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, hasLength(1));
      expect(issues.first.className, equals('UnsortedWidget'));
      expect(issues.first.filePath, contains('unsorted.dart'));
      expect(issues.first.description, contains('not properly sorted'));
    });

    test('fix mode rewrites file and returns no issues', () {
      final source = '''
class FixableWidget extends StatelessWidget {
  void zebra() {}
  void alpha() {}
}
''';
      final context = _contextForSource(
        tempDir,
        source,
        fileName: 'fixable.dart',
      );

      final delegate = SourceSortDelegate(fix: true);
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);

      final rewritten = context.file.readAsStringSync();
      expect(rewritten.indexOf('void alpha() {}'),
          lessThan(rewritten.indexOf('void zebra() {}')));
    });

    test('swallows internal exceptions and returns no issues', () {
      const source = '''
class BrokenContextWidget extends StatelessWidget {
  void zebra() {}
  void alpha() {}
}
''';
      final context = _contextForSource(
        tempDir,
        source,
        fileName: 'broken_context.dart',
        // Force substring failures inside MemberSorter source extraction.
        contentOverride: 'x',
      );

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });
  });
}
