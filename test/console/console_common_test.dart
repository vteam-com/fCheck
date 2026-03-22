import 'dart:async';

import '../../bin/console/console_common.dart';
import '../../bin/console/console_output.dart';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/models/ignore_inventory.dart';
import 'package:test/test.dart';

/// Runs [fn] synchronously while capturing all `print()` output.
List<String> _captureOutput(void Function() fn) {
  final lines = <String>[];
  runZoned(
    fn,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, String line) => lines.add(line),
    ),
  );
  return lines;
}

void main() {
  group('ReportListMode', () {
    test('should find mode from cliName', () {
      expect(ReportListMode.fromCliName('none'), equals(ReportListMode.none));
      expect(
        ReportListMode.fromCliName('partial'),
        equals(ReportListMode.partial),
      );
      expect(ReportListMode.fromCliName('full'), equals(ReportListMode.full));
      expect(
        ReportListMode.fromCliName('filenames'),
        equals(ReportListMode.filenames),
      );
    });

    test('should return null for invalid cliName', () {
      expect(ReportListMode.fromCliName('invalid'), isNull);
    });

    test('should have correct enum values', () {
      expect(ReportListMode.values, hasLength(4));
      expect(ReportListMode.values, contains(ReportListMode.none));
      expect(ReportListMode.values, contains(ReportListMode.partial));
      expect(ReportListMode.values, contains(ReportListMode.full));
      expect(ReportListMode.values, contains(ReportListMode.filenames));
    });
  });

  group('constants', () {
    test('should have usageLine constant', () {
      expect(usageLine, isNotEmpty);
    });

    test('should have descriptionLine constant', () {
      expect(descriptionLine, isNotEmpty);
    });

    test('should have invalidArgumentsLine constant', () {
      expect(invalidArgumentsLine, isNotEmpty);
    });
  });

  group('AppStrings methods', () {
    test('should format current analyzer count line', () {
      final result = AppStrings.currentAnalyzerCountLine(5, '20');
      expect(result, equals('  Current: 5 analyzers -> 20% each'));
    });

    test('should build missing directory error', () {
      final result = AppStrings.missingDirectoryError('/path/to/dir');
      expect(result, equals('Error: Directory "/path/to/dir" does not exist.'));
    });

    test('should build invalid .fcheck configuration error', () {
      final result = AppStrings.invalidFcheckConfigurationError(
        'Invalid config',
      );
      expect(
        result,
        equals('Error: Invalid .fcheck configuration. Invalid config'),
      );
    });

    test('should build excluded Dart files header', () {
      final result = AppStrings.excludedDartFilesHeader('3');
      expect(result, equals('Excluded Dart files (3):'));
    });

    test('should build excluded non-Dart files header', () {
      final result = AppStrings.excludedNonDartFilesHeader('2');
      expect(result, equals('\nExcluded non-Dart files (2):'));
    });

    test('should build excluded directories header', () {
      final result = AppStrings.excludedDirectoriesHeader('1');
      expect(result, equals('\nExcluded directories (1):'));
    });
  });

  // ----------------------------------------------------------------
  // Integration: AppStrings methods exercised via production printers
  // ----------------------------------------------------------------

  group('AppStrings via printIgnoreInventory (integration)', () {
    test(
      'printIgnoreInventory exercises all ignoreInventory string builders',
      () {
        final inventory = IgnoreInventory(
          configFilePath: '.fcheck',
          configExcludePatterns: const ['**/gen/**'],
          analyzersDisabled: const ['dead_code'],
          analyzersIgnoredLegacy: const [],
          dartCommentDirectives: const [
            IgnoreDirectiveLocation(
              path: 'lib/main.dart',
              line: 5,
              token: 'fcheck_magic_numbers',
              rawLine: '// ignore: fcheck_magic_numbers',
            ),
          ],
        );

        final output = _captureOutput(() => printIgnoreInventory(inventory));
        final joined = output.join('\n');

        // ignoreInventoryConfigFileLine
        expect(joined, contains(AppStrings.configFileLabel));
        // ignoreInventoryConfigExcludeLine
        expect(joined, contains('.fcheck input.exclude'));
        // ignoreInventoryEntriesLine (entries label)
        expect(joined, contains(AppStrings.entriesLabel));
        // ignoreInventoryTotalLine (total label)
        expect(joined, contains(AppStrings.totalLabel));
      },
    );

    test('printIgnoreInventory with null configFilePath emits "(none)"', () {
      final inventory = IgnoreInventory(
        configFilePath: null,
        configExcludePatterns: const [],
        analyzersDisabled: const [],
        analyzersIgnoredLegacy: const [],
        dartCommentDirectives: const [],
      );

      final output = _captureOutput(() => printIgnoreInventory(inventory));
      expect(output.join('\n'), contains('(none)'));
    });
  });

  group('AppStrings via printLiteralsSummary (integration)', () {
    test('printLiteralsSummary exercises foundItemsHeader', () {
      final output = _captureOutput(
        () => printLiteralsSummary(
          totalStringLiteralCount: 2,
          duplicatedStringLiteralCount: 1,
          hardcodedStringCount: 1,
          totalNumberLiteralCount: 1,
          duplicatedNumberLiteralCount: 0,
          hardcodedNumberCount: 0,
          stringLiteralFrequencies: const {'hello': 2},
          numberLiteralFrequencies: const {'42': 1},
          hardcodedStringEntries: [
            {'filePath': 'lib/a.dart', 'lineNumber': 3, 'value': 'Hello'},
          ],
          listMode: ReportListMode.full,
          listItemLimit: 10,
        ),
      );

      final joined = output.join('\n');
      // foundItemsHeader — "Hardcoded Strings found (1):"
      expect(joined, contains(AppStrings.hardcodedStrings));
      expect(joined, contains('found'));
      // uniqueFoundItemsHeader — "Unique strings found (1):"
      expect(joined, contains('Unique'));
    });

    test(
      'printLiteralsSummary exercises uniqueFoundItemsHeader for numbers',
      () {
        final output = _captureOutput(
          () => printLiteralsSummary(
            totalStringLiteralCount: 0,
            duplicatedStringLiteralCount: 0,
            hardcodedStringCount: 0,
            totalNumberLiteralCount: 3,
            duplicatedNumberLiteralCount: 1,
            hardcodedNumberCount: 0,
            stringLiteralFrequencies: const {},
            numberLiteralFrequencies: const {'42': 2, '99': 1},
            hardcodedStringEntries: const [],
            listMode: ReportListMode.full,
            listItemLimit: 10,
          ),
        );

        final joined = output.join('\n');
        // uniqueFoundItemsHeader for numbers — "Unique numbers found (2):"
        expect(joined, contains('Unique'));
        expect(joined, contains(AppStrings.numbers.toLowerCase()));
      },
    );
  });

  group('AppStrings via printAnalysisError (integration)', () {
    test('printAnalysisError exercises analysisErrorLine', () {
      const error = 'something went wrong';
      final output = _captureOutput(
        () => printAnalysisError(error, StackTrace.empty),
      );

      expect(output.first, equals(AppStrings.analysisErrorLine(error)));
      expect(output.first, contains(AppStrings.analysisError));
      expect(output.first, contains(error));
    });
  });
}
