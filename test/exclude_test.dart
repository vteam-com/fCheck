import 'dart:io';
import 'package:fcheck/src/utils.dart';
import 'package:fcheck/src/layers/layers_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('Exclude Pattern Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('exclude_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('FileUtils.listDartFiles with exclude patterns', () {
      test('should exclude files matching simple wildcard pattern', () {
        // Create test files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File('${tempDir.path}/helper.dart')
            .writeAsStringSync('class Helper {}');
        File('${tempDir.path}/misc_helper.dart')
            .writeAsStringSync('class MiscHelper {}');

        final files =
            FileUtils.listDartFiles(tempDir, excludePatterns: ['*misc*']);

        expect(files.length, equals(2));
        expect(files.any((f) => f.path.contains('misc_helper')), isFalse);
        expect(files.any((f) => f.path.contains('main.dart')), isTrue);
        expect(files.any((f) => f.path.contains('helper.dart')), isTrue);
      });

      test('should exclude files in subdirectories', () {
        // Create subdirectory structure
        final subDir = Directory('${tempDir.path}/helpers');
        subDir.createSync();

        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File('${subDir.path}/misc_helper.dart')
            .writeAsStringSync('class MiscHelper {}');
        File('${subDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final files = FileUtils.listDartFiles(tempDir,
            excludePatterns: ['helpers/*misc*']);

        expect(files.length, equals(2));
        expect(files.any((f) => f.path.contains('misc_helper')), isFalse);
      });

      test('should support multiple exclude patterns', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File('${tempDir.path}/test_helper.dart')
            .writeAsStringSync('class TestHelper {}');
        File('${tempDir.path}/misc_helper.dart')
            .writeAsStringSync('class MiscHelper {}');
        File('${tempDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final files = FileUtils.listDartFiles(tempDir,
            excludePatterns: ['*misc*', '*test*']);

        expect(files.length, equals(2));
        expect(files.any((f) => f.path.contains('misc_helper')), isFalse);
        expect(files.any((f) => f.path.contains('test_helper')), isFalse);
        expect(files.any((f) => f.path.contains('main.dart')), isTrue);
        expect(files.any((f) => f.path.contains('utils.dart')), isTrue);
      });

      test('should exclude specific directory patterns', () {
        final generatedDir = Directory('${tempDir.path}/generated');
        generatedDir.createSync();

        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File('${generatedDir.path}/model.dart')
            .writeAsStringSync('class Model {}');

        final files =
            FileUtils.listDartFiles(tempDir, excludePatterns: ['generated/*']);

        expect(files.length, equals(1));
        expect(files.any((f) => f.path.contains('generated')), isFalse);
      });

      test('should work with empty exclude patterns', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File('${tempDir.path}/helper.dart')
            .writeAsStringSync('class Helper {}');

        final files = FileUtils.listDartFiles(tempDir, excludePatterns: []);

        expect(files.length, equals(2));
      });
    });

    group('LayersAnalyzer with exclude patterns', () {
      test('should exclude files from dependency graph', () {
        // Create files where main.dart imports misc_helper.dart
        File('${tempDir.path}/main.dart')
            .writeAsStringSync('import "misc_helper.dart"; class Main {}');
        File('${tempDir.path}/misc_helper.dart')
            .writeAsStringSync('class MiscHelper {}');
        File('${tempDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final analyzer = LayersAnalyzer(tempDir);
        final result =
            analyzer.analyzeDirectory(tempDir, excludePatterns: ['*misc*']);

        // misc_helper.dart should not appear in the dependency graph at all
        expect(
            result.dependencyGraph.keys.any((k) => k.contains('misc_helper')),
            isFalse);

        // main.dart shouldn't have misc_helper as a dependency (filtered out)
        final mainDartPath = '${tempDir.path}/main.dart';
        if (result.dependencyGraph.containsKey(mainDartPath)) {
          expect(
              result.dependencyGraph[mainDartPath]!
                  .any((d) => d.contains('misc_helper')),
              isFalse);
        }
      });

      test('should not assign layers to excluded files', () {
        // Create chain: main -> misc_helper -> utils
        File('${tempDir.path}/main.dart')
            .writeAsStringSync('import "misc_helper.dart"; void main() {}');
        File('${tempDir.path}/misc_helper.dart')
            .writeAsStringSync('import "utils.dart"; class MiscHelper {}');
        File('${tempDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final analyzer = LayersAnalyzer(tempDir);
        final result =
            analyzer.analyzeDirectory(tempDir, excludePatterns: ['*misc*']);

        // misc_helper.dart should not have a layer assignment
        expect(
            result.layers.keys.any((k) => k.contains('misc_helper')), isFalse);

        // Only main.dart and utils.dart should have layers
        expect(result.layers.length, equals(2));
      });

      test('should handle exclusion of dependency targets', () {
        // Create scenario where multiple files import excluded file
        File('${tempDir.path}/a.dart')
            .writeAsStringSync('import "misc_helper.dart"; class A {}');
        File('${tempDir.path}/b.dart')
            .writeAsStringSync('import "misc_helper.dart"; class B {}');
        File('${tempDir.path}/misc_helper.dart')
            .writeAsStringSync('class MiscHelper {}');

        final analyzer = LayersAnalyzer(tempDir);
        final result =
            analyzer.analyzeDirectory(tempDir, excludePatterns: ['*misc*']);

        // Neither a.dart nor b.dart should have misc_helper in dependencies (filtered)
        final aDartPath = '${tempDir.path}/a.dart';
        final bDartPath = '${tempDir.path}/b.dart';

        if (result.dependencyGraph.containsKey(aDartPath)) {
          expect(result.dependencyGraph[aDartPath], isEmpty);
        }
        if (result.dependencyGraph.containsKey(bDartPath)) {
          expect(result.dependencyGraph[bDartPath], isEmpty);
        }
      });
    });

    group('FileUtils.countFolders with exclude patterns', () {
      test('should exclude folders matching pattern', () {
        Directory('${tempDir.path}/src').createSync();
        Directory('${tempDir.path}/misc').createSync();
        Directory('${tempDir.path}/utils').createSync();

        final count =
            FileUtils.countFolders(tempDir, excludePatterns: ['misc']);

        // Should count src and utils, but not misc
        expect(count, equals(2));
      });
    });

    group('FileUtils.countAllFiles with exclude patterns', () {
      test('should exclude files matching pattern', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('');
        File('${tempDir.path}/misc_helper.dart').writeAsStringSync('');
        File('${tempDir.path}/README.md').writeAsStringSync('');

        final count =
            FileUtils.countAllFiles(tempDir, excludePatterns: ['*misc*']);

        // Should count main.dart and README.md, but not misc_helper.dart
        expect(count, equals(2));
      });
    });
  });
}
