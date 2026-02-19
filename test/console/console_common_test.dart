import '../../bin/console/console_common.dart';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:test/test.dart';

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
}
