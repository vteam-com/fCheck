import 'package:fcheck/src/analyzers/localization/localization_issue.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizationIssue', () {
    test('creates issue with correct properties', () {
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 5,
        totalCount: 10,
      );

      expect(issue.languageCode, equals('es'));
      expect(issue.languageName, equals('Spanish'));
      expect(issue.missingCount, equals(5));
      expect(issue.totalCount, equals(10));
      expect(issue.coveragePercentage, equals(50.0)); // (10-5)/10 * 100
    });

    test('calculates coverage percentage correctly', () {
      // Complete translation
      final complete = LocalizationIssue(
        languageCode: 'fr',
        languageName: 'French',
        missingCount: 0,
        totalCount: 8,
      );
      expect(complete.coveragePercentage, equals(100.0));

      // Half translated
      final half = LocalizationIssue(
        languageCode: 'de',
        languageName: 'German',
        missingCount: 3,
        totalCount: 6,
      );
      expect(half.coveragePercentage, equals(50.0));

      // Mostly complete
      final mostlyComplete = LocalizationIssue(
        languageCode: 'it',
        languageName: 'Italian',
        missingCount: 1,
        totalCount: 10,
      );
      expect(mostlyComplete.coveragePercentage, equals(90.0));

      // Edge case: zero total count
      final zeroTotal = LocalizationIssue(
        languageCode: 'ja',
        languageName: 'Japanese',
        missingCount: 0,
        totalCount: 0,
      );
      expect(zeroTotal.coveragePercentage, equals(100.0));
    });

    test('format returns correct string representation', () {
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 3,
        totalCount: 10,
      );

      final formatted = issue.format();
      expect(formatted, contains('Spanish'));
      expect(formatted, contains('es'));
      expect(formatted, contains('70.0%')); // Coverage percentage
      expect(formatted, contains('3 missing'));
    });

    test('format includes problem reason breakdown when provided', () {
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 3,
        totalCount: 10,
        problemCounts: {
          LocalizationTranslationProblemType.empty: 2,
          LocalizationTranslationProblemType.placeholderMismatch: 1,
        },
      );

      final formatted = issue.format();
      expect(formatted, contains('3 issues'));
      expect(formatted, contains('2 empty'));
      expect(formatted, contains('1 placeholder mismatch'));
    });

    test('format shows complete when no missing translations', () {
      final issue = LocalizationIssue(
        languageCode: 'fr',
        languageName: 'French',
        missingCount: 0,
        totalCount: 5,
      );

      final formatted = issue.format();
      expect(formatted, contains('French'));
      expect(formatted, contains('fr'));
      expect(formatted, contains('100.0%'));
      expect(formatted, contains('complete'));
      expect(formatted, isNot(contains('missing')));
    });

    test('toString returns formatted string', () {
      final issue = LocalizationIssue(
        languageCode: 'de',
        languageName: 'German',
        missingCount: 2,
        totalCount: 4,
      );

      expect(issue.toString(), equals(issue.format()));
    });

    test('toJson returns correct JSON representation', () {
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 3,
        totalCount: 10,
      );

      final json = issue.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['languageCode'], equals('es'));
      expect(json['languageName'], equals('Spanish'));
      expect(json['missingCount'], equals(3));
      expect(json['totalCount'], equals(10));
      expect(json['coveragePercentage'], equals(70.0));
      expect(json['problemCounts'], equals(<String, dynamic>{}));
    });

    test('toJson includes problem counts when provided', () {
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 2,
        totalCount: 10,
        problemCounts: {LocalizationTranslationProblemType.unchanged: 2},
      );

      final json = issue.toJson();
      expect(json['problemCounts'], equals(<String, dynamic>{'unchanged': 2}));
    });

    test('handles floating point precision correctly', () {
      // Test case that would result in repeating decimal
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 1,
        totalCount: 3,
      );

      expect(
        issue.coveragePercentage,
        equals(
          66.7,
        ), // 1/3 = 0.333... * 100 = 33.333... rounded to 33.3, but 2/3 = 66.666... rounded to 66.7
      );
    });

    test('coverage percentage never exceeds 100', () {
      // Edge case where missing count might be negative (shouldn't happen but test defensively)
      final issue = LocalizationIssue(
        languageCode: 'test',
        languageName: 'Test',
        missingCount: -1, // Invalid but test defensive programming
        totalCount: 10,
      );

      expect(issue.coveragePercentage, equals(100.0)); // Should clamp to 100%
    });

    test('coverage percentage never goes below 0', () {
      // Edge case where missing count exceeds total
      final issue = LocalizationIssue(
        languageCode: 'test',
        languageName: 'Test',
        missingCount: 15, // More missing than total
        totalCount: 10,
      );

      expect(issue.coveragePercentage, equals(0.0)); // Should clamp to 0%
    });
  });
}
