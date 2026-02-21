import 'dart:io';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:path/path.dart' as p;
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
        File(
          '${tempDir.path}/helper.dart',
        ).writeAsStringSync('class Helper {}');
        File(
          '${tempDir.path}/misc_helper.dart',
        ).writeAsStringSync('class MiscHelper {}');

        final files = FileUtils.listDartFiles(
          tempDir,
          excludePatterns: ['*misc*'],
        );

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
        File(
          '${subDir.path}/misc_helper.dart',
        ).writeAsStringSync('class MiscHelper {}');
        File('${subDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final files = FileUtils.listDartFiles(
          tempDir,
          excludePatterns: ['helpers/*misc*'],
        );

        expect(files.length, equals(2));
        expect(files.any((f) => f.path.contains('misc_helper')), isFalse);
      });

      test('should support multiple exclude patterns', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${tempDir.path}/test_helper.dart',
        ).writeAsStringSync('class TestHelper {}');
        File(
          '${tempDir.path}/misc_helper.dart',
        ).writeAsStringSync('class MiscHelper {}');
        File('${tempDir.path}/utils.dart').writeAsStringSync('class Utils {}');

        final files = FileUtils.listDartFiles(
          tempDir,
          excludePatterns: ['*misc*', '*test*'],
        );

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
        File(
          '${generatedDir.path}/model.dart',
        ).writeAsStringSync('class Model {}');

        final files = FileUtils.listDartFiles(
          tempDir,
          excludePatterns: ['generated/*'],
        );

        expect(files.length, equals(1));
        expect(files.any((f) => f.path.contains('generated')), isFalse);
      });

      test('should work with empty exclude patterns', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${tempDir.path}/helper.dart',
        ).writeAsStringSync('class Helper {}');

        final files = FileUtils.listDartFiles(tempDir, excludePatterns: []);

        expect(files.length, equals(2));
      });

      test('should exclude app_localizations_ files by default', () {
        File('${tempDir.path}/app_localizations.dart').writeAsStringSync('');
        File('${tempDir.path}/app_localizations_en.dart').writeAsStringSync('');
        File('${tempDir.path}/app_localizations_fr.dart').writeAsStringSync('');
        File('${tempDir.path}/main.dart').writeAsStringSync('');

        final files = FileUtils.listDartFiles(tempDir);

        // Should include app_localizations.dart and main.dart, but exclude _en and _fr
        expect(files.length, equals(2));
        expect(
          files.any((f) => p.basename(f.path) == 'app_localizations.dart'),
          isTrue,
        );
        expect(files.any((f) => p.basename(f.path) == 'main.dart'), isTrue);
        expect(
          files.any((f) => p.basename(f.path) == 'app_localizations_en.dart'),
          isFalse,
        );
      });
    });

    group('Hidden folder exclusion', () {
      test('should skip files in hidden directories (starting with .)', () {
        // Create a hidden directory
        final hiddenDir = Directory('${tempDir.path}/.hidden');
        hiddenDir.createSync();

        // Create files in hidden directory
        File('${hiddenDir.path}/hidden_file.dart').writeAsStringSync('');
        File('${hiddenDir.path}/another_hidden.dart').writeAsStringSync('');

        // Create regular files
        File('${tempDir.path}/main.dart').writeAsStringSync('');
        File('${tempDir.path}/utils.dart').writeAsStringSync('');

        // Test listDartFiles
        final dartFiles = FileUtils.listDartFiles(tempDir);
        expect(dartFiles.length, equals(2));
        expect(dartFiles.any((f) => f.path.contains('.hidden')), isFalse);
        expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('utils.dart')), isTrue);

        // Test unified scan for counts
        final (
          scanDartFiles,
          folderCount,
          fileCount,
          excludedDartFilesCount,
          excludedFoldersCount,
          excludedFilesCount,
        ) = FileUtils.scanDirectory(
          tempDir,
        );
        expect(scanDartFiles.length, equals(2));
        expect(
          folderCount,
          equals(0),
        ); // Hidden directory should not be counted
        expect(fileCount, equals(2));
      });

      test('should skip nested hidden directories', () {
        // Create nested structure with hidden directory
        final srcDir = Directory('${tempDir.path}/src');
        srcDir.createSync();

        final nestedHiddenDir = Directory('${srcDir.path}/.cache');
        nestedHiddenDir.createSync();

        // Create files in nested hidden directory
        File('${nestedHiddenDir.path}/cached_file.dart').writeAsStringSync('');

        // Create regular files
        File('${tempDir.path}/main.dart').writeAsStringSync('');
        File('${srcDir.path}/service.dart').writeAsStringSync('');

        // Test listDartFiles
        final dartFiles = FileUtils.listDartFiles(tempDir);
        expect(dartFiles.length, equals(2));
        expect(dartFiles.any((f) => f.path.contains('.cache')), isFalse);
        expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('service.dart')), isTrue);

        // Test unified scan for counts
        final (
          scanDartFiles,
          folderCount,
          fileCount,
          excludedDartFilesCount,
          excludedFoldersCount,
          excludedFilesCount,
        ) = FileUtils.scanDirectory(
          tempDir,
        );
        expect(scanDartFiles.length, equals(2));
        expect(folderCount, equals(1)); // Only src directory should be counted
        expect(fileCount, equals(2));
      });

      test(
        'should skip files in hidden directories when using exclude patterns',
        () {
          // Create hidden directory
          final hiddenDir = Directory('${tempDir.path}/.hidden');
          hiddenDir.createSync();

          // Create files in hidden directory
          File('${hiddenDir.path}/hidden_helper.dart').writeAsStringSync('');

          // Create regular files
          File('${tempDir.path}/main.dart').writeAsStringSync('');
          File('${tempDir.path}/test_helper.dart').writeAsStringSync('');

          // Test with exclude patterns - hidden files should be skipped regardless of patterns
          final dartFiles = FileUtils.listDartFiles(
            tempDir,
            excludePatterns: ['*test*'],
          );

          expect(dartFiles.length, equals(1));
          expect(dartFiles.any((f) => f.path.contains('.hidden')), isFalse);
          expect(dartFiles.any((f) => f.path.contains('test_helper')), isFalse);
          expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        },
      );
    });

    group('Excluded files listing', () {
      test('should list all excluded files and directories', () {
        // Create test structure with various excluded items
        final hiddenDir = Directory('${tempDir.path}/.hidden');
        hiddenDir.createSync();

        final testDir = Directory('${tempDir.path}/test');
        testDir.createSync();

        final integrationTestDir = Directory(
          '${tempDir.path}/integration_test',
        );
        integrationTestDir.createSync();

        final exampleDir = Directory('${tempDir.path}/example');
        exampleDir.createSync();

        // Create files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${hiddenDir.path}/hidden.dart',
        ).writeAsStringSync('class Hidden {}');
        File(
          '${testDir.path}/test_helper.dart',
        ).writeAsStringSync('class TestHelper {}');
        File(
          '${integrationTestDir.path}/integration_test_helper.dart',
        ).writeAsStringSync('class IntegrationTestHelper {}');
        File(
          '${exampleDir.path}/example.dart',
        ).writeAsStringSync('class Example {}');
        File('${tempDir.path}/README.md').writeAsStringSync('# Test');
        File(
          '${hiddenDir.path}/hidden.txt',
        ).writeAsStringSync('hidden content');

        // Test excluded files listing
        final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) =
            FileUtils.listExcludedFiles(tempDir);

        expect(
          excludedDartFiles.length,
          equals(4),
        ); // hidden.dart, test_helper.dart, integration_test_helper.dart, example.dart
        expect(excludedNonDartFiles.length, equals(1)); // hidden.txt
        expect(
          excludedDirectories.length,
          equals(4),
        ); // .hidden, test, integration_test, example

        expect(
          excludedDartFiles.any((f) => f.path.contains('hidden.dart')),
          isTrue,
        );
        expect(
          excludedDartFiles.any((f) => f.path.contains('test_helper.dart')),
          isTrue,
        );
        expect(
          excludedDartFiles.any(
            (f) => f.path.contains('integration_test_helper.dart'),
          ),
          isTrue,
        );
        expect(
          excludedDartFiles.any((f) => f.path.contains('example.dart')),
          isTrue,
        );

        expect(
          excludedNonDartFiles.any((f) => f.path.contains('hidden.txt')),
          isTrue,
        );

        expect(
          excludedDirectories.any((d) => d.path.contains('.hidden')),
          isTrue,
        );
        expect(excludedDirectories.any((d) => d.path.contains('test')), isTrue);
        expect(
          excludedDirectories.any((d) => d.path.contains('integration_test')),
          isTrue,
        );
        expect(
          excludedDirectories.any((d) => d.path.contains('example')),
          isTrue,
        );
      });

      test('should list excluded files with custom patterns', () {
        // Create test structure
        final helpersDir = Directory('${tempDir.path}/helpers');
        helpersDir.createSync();

        // Create files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${helpersDir.path}/helper.dart',
        ).writeAsStringSync('class Helper {}');
        File(
          '${helpersDir.path}/utils.dart',
        ).writeAsStringSync('class Utils {}');

        // Test with exclude patterns
        final (
          excludedDartFiles,
          excludedNonDartFiles,
          excludedDirectories,
        ) = FileUtils.listExcludedFiles(
          tempDir,
          excludePatterns: ['helpers/*'],
        );

        expect(excludedDartFiles.length, equals(2)); // helper.dart, utils.dart
        expect(excludedNonDartFiles.length, equals(0));
        expect(
          excludedDirectories.length,
          equals(0),
        ); // helpers directory itself is not excluded

        expect(
          excludedDartFiles.any((f) => f.path.contains('helper.dart')),
          isTrue,
        );
        expect(
          excludedDartFiles.any((f) => f.path.contains('utils.dart')),
          isTrue,
        );
      });

      test('should list locale files as excluded', () {
        // Create locale files
        File('${tempDir.path}/app_localizations.dart').writeAsStringSync('');
        File('${tempDir.path}/app_localizations_en.dart').writeAsStringSync('');
        File('${tempDir.path}/app_localizations_fr.dart').writeAsStringSync('');
        File('${tempDir.path}/main.dart').writeAsStringSync('');

        // Test excluded files listing
        final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) =
            FileUtils.listExcludedFiles(tempDir);

        expect(
          excludedDartFiles.length,
          equals(2),
        ); // app_localizations_en.dart, app_localizations_fr.dart
        expect(excludedNonDartFiles.length, equals(0));
        expect(excludedDirectories.length, equals(0));

        expect(
          excludedDartFiles.any((f) => f.path.contains('app_localizations_en')),
          isTrue,
        );
        expect(
          excludedDartFiles.any((f) => f.path.contains('app_localizations_fr')),
          isTrue,
        );
        expect(
          excludedDartFiles.any(
            (f) => f.path.contains('app_localizations.dart'),
          ),
          isFalse,
        ); // main app_localizations.dart should not be excluded
      });
    });

    group('Unified directory scan', () {
      test('should return correct counts in single scan', () {
        // Create test structure
        final srcDir = Directory('${tempDir.path}/src');
        srcDir.createSync();

        final libDir = Directory('${tempDir.path}/lib');
        libDir.createSync();

        // Create files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${srcDir.path}/service.dart',
        ).writeAsStringSync('class Service {}');
        File('${libDir.path}/utils.dart').writeAsStringSync('class Utils {}');
        File('${tempDir.path}/README.md').writeAsStringSync('# Test');
        File('${srcDir.path}/config.json').writeAsStringSync('{}');

        // Test unified scan
        final (
          dartFiles,
          folderCount,
          fileCount,
          excludedDartFilesCount,
          excludedFoldersCount,
          excludedFilesCount,
        ) = FileUtils.scanDirectory(
          tempDir,
        );

        expect(dartFiles.length, equals(3));
        expect(folderCount, equals(2)); // src and lib
        expect(fileCount, equals(5)); // 3 dart + 1 md + 1 json
        expect(excludedDartFilesCount, equals(0));
        expect(excludedFoldersCount, equals(0));
        expect(excludedFilesCount, equals(0));

        // Verify dart files
        expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('service.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('utils.dart')), isTrue);
      });

      test('should apply exclude patterns in unified scan', () {
        // Create test structure
        final srcDir = Directory('${tempDir.path}/src');
        srcDir.createSync();

        final testDir = Directory('${tempDir.path}/test');
        testDir.createSync();

        final integrationTestDir = Directory(
          '${tempDir.path}/integration_test',
        );
        integrationTestDir.createSync();

        // Create files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${srcDir.path}/service.dart',
        ).writeAsStringSync('class Service {}');
        File(
          '${testDir.path}/test_helper.dart',
        ).writeAsStringSync('class TestHelper {}');
        File(
          '${integrationTestDir.path}/integration_test_helper.dart',
        ).writeAsStringSync('class IntegrationTestHelper {}');

        // Test unified scan with exclude patterns
        final (
          dartFiles,
          folderCount,
          fileCount,
          excludedDartFilesCount,
          excludedFoldersCount,
          excludedFilesCount,
        ) = FileUtils.scanDirectory(
          tempDir,
          excludePatterns: ['test/*'],
        );

        expect(dartFiles.length, equals(2)); // main.dart and service.dart only
        expect(
          folderCount,
          equals(1),
        ); // src only (test and integration_test are excluded by default)
        expect(fileCount, equals(2)); // main.dart and service.dart only
        expect(
          excludedDartFilesCount,
          equals(2),
        ); // test_helper.dart and integration_test_helper.dart excluded
        expect(
          excludedFoldersCount,
          equals(2),
        ); // test and integration_test folders excluded by default
        expect(
          excludedFilesCount,
          equals(2),
        ); // test_helper.dart and integration_test_helper.dart excluded

        expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('service.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('test_helper')), isFalse);
        expect(
          dartFiles.any((f) => f.path.contains('integration_test_helper')),
          isFalse,
        );
      });

      test('should skip hidden folders in unified scan', () {
        // Create test structure with hidden folder
        final srcDir = Directory('${tempDir.path}/src');
        srcDir.createSync();

        final hiddenDir = Directory('${tempDir.path}/.hidden');
        hiddenDir.createSync();

        // Create files
        File('${tempDir.path}/main.dart').writeAsStringSync('class Main {}');
        File(
          '${srcDir.path}/service.dart',
        ).writeAsStringSync('class Service {}');
        File(
          '${hiddenDir.path}/hidden.dart',
        ).writeAsStringSync('class Hidden {}');

        // Test unified scan
        final (
          dartFiles,
          folderCount,
          fileCount,
          excludedDartFilesCount,
          excludedFoldersCount,
          excludedFilesCount,
        ) = FileUtils.scanDirectory(
          tempDir,
        );

        expect(dartFiles.length, equals(2)); // Only main.dart and service.dart
        expect(folderCount, equals(1)); // Only src (hidden folder excluded)
        expect(fileCount, equals(2)); // Only main.dart and service.dart
        expect(excludedDartFilesCount, equals(1)); // hidden.dart excluded
        expect(excludedFoldersCount, equals(1)); // .hidden folder excluded
        expect(excludedFilesCount, equals(1)); // hidden.dart excluded

        expect(dartFiles.any((f) => f.path.contains('main.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('service.dart')), isTrue);
        expect(dartFiles.any((f) => f.path.contains('.hidden')), isFalse);
      });
    });

    group('Custom exclusion counting', () {
      test('counts only glob-excluded Dart files beyond defaults', () {
        final helpersDir = Directory('${tempDir.path}/helpers')..createSync();
        final hiddenDir = Directory('${tempDir.path}/.hidden')..createSync();
        final testDir = Directory('${tempDir.path}/test')..createSync();
        final integrationTestDir = Directory('${tempDir.path}/integration_test')
          ..createSync();

        File('${tempDir.path}/main.dart').writeAsStringSync('void main() {}');
        File('${helpersDir.path}/helper.dart').writeAsStringSync('class H {}');
        File('${hiddenDir.path}/hidden.dart').writeAsStringSync('class X {}');
        File('${testDir.path}/test_file.dart').writeAsStringSync('class T {}');
        File(
          '${integrationTestDir.path}/integration_test_file.dart',
        ).writeAsStringSync('class IT {}');

        final count = FileUtils.countCustomExcludedDartFiles(
          tempDir,
          excludePatterns: ['helpers/*'],
        );

        expect(count, equals(1));
      });

      test('returns zero when no custom patterns are provided', () {
        File('${tempDir.path}/main.dart').writeAsStringSync('void main() {}');
        final count = FileUtils.countCustomExcludedDartFiles(tempDir);
        expect(count, equals(0));
      });
    });
  });
}
