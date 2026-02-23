import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/sorted/source_sort_delegate.dart';

import 'package:test/test.dart';

AnalysisFileContext _contextForSource(
  Directory tempDir,
  String source, {
  String fileName = 'sample.dart',
  String? contentOverride,
}) {
  final file = File('${tempDir.path}/$fileName');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(source);
  final pubspec = File('${tempDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    pubspec.writeAsStringSync('name: fcheck\n');
  }
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
      final context = _contextForSource(tempDir, '''
class PlainClass {
  void zebra() {}
  void alpha() {}
}
''', fileName: 'plain.dart');

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('skips generated files', () {
      final context = _contextForSource(tempDir, '''
class UnsortedWidget extends StatelessWidget {
  void zebra() {}
  void alpha() {}
}
''', fileName: 'generated_widget.g.dart');

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
      final context = _contextForSource(tempDir, '''
class SortedWidget extends StatelessWidget {
  void initState() {}

  void build() {}

  void alpha() {}
  void beta() {}

  void _alpha() {}
  void _beta() {}
}
''', fileName: 'sorted.dart');

      final delegate = SourceSortDelegate();
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);
    });

    test('reports issue for unsorted Flutter class when fix is false', () {
      final context = _contextForSource(tempDir, '''
class UnsortedWidget extends StatelessWidget {
  void zebra() {}
  void alpha() {}
}
''', fileName: 'unsorted.dart');

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
      expect(
        rewritten.indexOf('void alpha() {}'),
        lessThan(rewritten.indexOf('void zebra() {}')),
      );
    });

    test('fix mode sorts imports by directive ordering lint groups', () {
      final source = '''
import 'b.dart';
import 'package:fcheck/local.dart';
import 'package:zebra/zebra.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'http://example.com/remote.dart';
import 'package:apple/apple.dart';
import 'a.dart';

class FixableWidget extends StatelessWidget {
  void build() {}
}
''';
      final context = _contextForSource(
        tempDir,
        source,
        fileName: 'fixable_imports.dart',
      );

      final delegate = SourceSortDelegate(fix: true, packageName: 'fcheck');
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);

      final rewritten = context.file.readAsStringSync();
      expect(
        rewritten.indexOf("import 'dart:io';"),
        lessThan(rewritten.indexOf("import 'package:apple/apple.dart';")),
      );
      expect(
        rewritten.indexOf("import 'package:apple/apple.dart';"),
        lessThan(rewritten.indexOf("import 'package:fcheck/local.dart';")),
      );
      expect(
        rewritten.indexOf("import 'package:fcheck/local.dart';"),
        lessThan(rewritten.indexOf("import 'package:flutter/material.dart';")),
      );
      expect(
        rewritten.indexOf("import 'package:flutter/material.dart';"),
        lessThan(rewritten.indexOf("import 'package:zebra/zebra.dart';")),
      );
      expect(
        rewritten.indexOf("import 'package:zebra/zebra.dart';"),
        lessThan(rewritten.indexOf("import 'http://example.com/remote.dart';")),
      );
      expect(
        rewritten.indexOf("import 'http://example.com/remote.dart';"),
        lessThan(rewritten.indexOf("import 'a.dart';")),
      );
      expect(
        rewritten.indexOf("import 'a.dart';"),
        lessThan(rewritten.indexOf("import 'b.dart';")),
      );
      expect(
        rewritten,
        contains(
          "import 'package:zebra/zebra.dart';\n\nimport 'http://example.com/remote.dart';\n\nimport 'a.dart';",
        ),
      );
    });

    test('fix mode converts relative imports under lib to package imports', () {
      final source = '''
import '../../core/config.dart';
import 'helpers.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

class FixableWidget extends StatelessWidget {
  void build() {}
}
''';
      final context = _contextForSource(
        tempDir,
        source,
        fileName: 'lib/src/feature/fixable_relative_imports.dart',
      );

      final delegate = SourceSortDelegate(fix: true, packageName: 'fcheck');
      final issues = delegate.analyzeFileWithContext(context);

      expect(issues, isEmpty);

      final rewritten = context.file.readAsStringSync();
      expect(rewritten, isNot(contains("import '../../core/config.dart';")));
      expect(rewritten, isNot(contains("import 'helpers.dart';")));
      expect(rewritten, contains("import 'package:fcheck/core/config.dart';"));
      expect(
        rewritten,
        contains("import 'package:fcheck/src/feature/helpers.dart';"),
      );
      expect(
        rewritten,
        contains(
          "import 'dart:io';\n\nimport 'package:fcheck/core/config.dart';\nimport 'package:fcheck/src/feature/helpers.dart';\nimport 'package:flutter/widgets.dart';",
        ),
      );
    });

    test(
      'fix mode inserts blank line between directive sections even when already ordered',
      () {
        final source = '''
import 'dart:io';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';

class FixableWidget extends StatelessWidget {
  void build() {}
}
''';
        final context = _contextForSource(
          tempDir,
          source,
          fileName: 'lib/src/analyzers/layers/fixable_spacing.dart',
        );

        final delegate = SourceSortDelegate(fix: true, packageName: 'fcheck');
        final issues = delegate.analyzeFileWithContext(context);
        expect(issues, isEmpty);

        final rewritten = context.file.readAsStringSync();
        expect(
          rewritten,
          contains(
            "import 'dart:io';\n\nimport 'package:fcheck/src/analyzers/layers/layers_issue.dart';",
          ),
        );
      },
    );

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
