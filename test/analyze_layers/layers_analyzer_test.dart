import 'dart:io';

import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:test/test.dart';

void main() {
  group('LayersIssue', () {
    test('toString includes type, file path, and message', () {
      final issue = LayersIssue(
        type: LayersIssueType.cyclicDependency,
        filePath: 'lib/a.dart',
        message: 'Cyclic dependency detected involving lib/b.dart',
      );

      expect(
        issue.toString(),
        equals(
          '[LayersIssueType.cyclicDependency] lib/a.dart: '
          'Cyclic dependency detected involving lib/b.dart',
        ),
      );
    });

    test('toJson serializes cyclic dependency type', () {
      final issue = LayersIssue(
        type: LayersIssueType.cyclicDependency,
        filePath: 'lib/a.dart',
        message: 'Cycle found',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'cyclicDependency',
          'filePath': 'lib/a.dart',
          'message': 'Cycle found',
        }),
      );
    });

    test('toJson serializes wrong layer type', () {
      final issue = LayersIssue(
        type: LayersIssueType.wrongLayer,
        filePath: 'lib/presentation/screen.dart',
        message: 'Component is in wrong layer',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'wrongLayer',
          'filePath': 'lib/presentation/screen.dart',
          'message': 'Component is in wrong layer',
        }),
      );
    });
  });

  group('LayersAnalyzer', () {
    late Directory tempDir;
    late LayersAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_layers_analyzer_');
      analyzer = LayersAnalyzer(
        tempDir,
        projectRoot: tempDir,
        packageName: 'sample',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'does not report folder-layer violation for downward file dependency',
      () {
        final result = analyzer.analyzeFromFileData([
          {
            'filePath': 'lib/x/x.dart',
            'dependencies': ['lib/y/y.dart'],
            'isEntryPoint': false,
          },
          {
            'filePath': 'lib/y/y.dart',
            'dependencies': ['lib/a/a2.dart'],
            'isEntryPoint': false,
          },
          {
            'filePath': 'lib/a/a1.dart',
            'dependencies': ['lib/b/b1.dart'],
            'isEntryPoint': false,
          },
          {
            'filePath': 'lib/a/a2.dart',
            'dependencies': <String>[],
            'isEntryPoint': false,
          },
          {
            'filePath': 'lib/b/b1.dart',
            'dependencies': <String>[],
            'isEntryPoint': false,
          },
        ]);

        final folderViolations = result.issues
            .where((issue) => issue.type == LayersIssueType.wrongFolderLayer)
            .toList();

        expect(folderViolations, isEmpty);
      },
    );
  });
}
