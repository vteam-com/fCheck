import 'dart:io';

import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:test/test.dart';

void main() {
  group('LayersAnalysisResult via LayersAnalyzer', () {
    late Directory tempDir;
    late LayersAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_layers_result_');
      analyzer = LayersAnalyzer(
        tempDir,
        projectRoot: tempDir,
        packageName: 'sample',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('computes non-zero layerCount/edgeCount for acyclic graph', () {
      final result = analyzer.analyzeFromFileData([
        {
          'filePath': 'lib/main.dart',
          'dependencies': ['lib/service.dart'],
          'isEntryPoint': true,
        },
        {
          'filePath': 'lib/service.dart',
          'dependencies': <String>[],
          'isEntryPoint': false,
        },
      ]);

      expect(result.issues, isEmpty);
      expect(result.layerCount, greaterThan(0));
      expect(result.edgeCount, equals(1));
      expect(result.layers['lib/main.dart'], isNotNull);
      expect(result.layers['lib/service.dart'], isNotNull);

      final json = result.toJson();
      expect(json['layerCount'], equals(result.layerCount));
      expect(json['edgeCount'], equals(1));
      expect(json['layers'], equals(result.layers));
      expect(json['dependencyGraph'], equals(result.dependencyGraph));
      expect(json['issues'], isEmpty);
    });

    test('keeps edge count but has zero layers when cycle exists', () {
      final result = analyzer.analyzeFromFileData([
        {
          'filePath': 'lib/a.dart',
          'dependencies': ['lib/b.dart'],
          'isEntryPoint': false,
        },
        {
          'filePath': 'lib/b.dart',
          'dependencies': ['lib/a.dart'],
          'isEntryPoint': false,
        },
      ]);

      expect(result.issues, isNotEmpty);
      expect(
        result.issues.any(
          (issue) => issue.type == LayersIssueType.cyclicDependency,
        ),
        isTrue,
      );
      expect(result.layers, isEmpty);
      expect(result.layerCount, equals(0));
      expect(result.edgeCount, equals(2));

      final json = result.toJson();
      expect(json['layerCount'], equals(0));
      expect(json['edgeCount'], equals(2));
      expect((json['issues'] as List<dynamic>).isNotEmpty, isTrue);
    });

    test('filters dependencies not in analyzed file set', () {
      final result = analyzer.analyzeFromFileData(
        [
          {
            'filePath': 'lib/a.dart',
            'dependencies': ['lib/b.dart', 'lib/c.dart'],
            'isEntryPoint': true,
          },
          {
            'filePath': 'lib/b.dart',
            'dependencies': <String>[],
            'isEntryPoint': false,
          },
          {
            'filePath': 'lib/c.dart',
            'dependencies': <String>[],
            'isEntryPoint': false,
          },
        ],
        analyzedFilePaths: {'lib/a.dart', 'lib/b.dart'},
      );

      expect(result.dependencyGraph['lib/a.dart'], equals(['lib/b.dart']));
      expect(result.edgeCount, equals(1));
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
