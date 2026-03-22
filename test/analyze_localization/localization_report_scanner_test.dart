import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/analyzers/localization/localization_report_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _l10nRelativePath = 'lib/l10n';
const String _englishArb = 'app_en.arb';
const String _spanishArb = 'app_es.arb';
const String _frenchArb = 'app_fr.arb';
const String _helloKey = 'hello';
const String _goodbyeKey = 'goodbye';
const int _zero = 0;
const int _one = 1;
const int _two = 2;
const double _zeroCoverage = 0.0;
const double _fullCoverage = 100.0;
const double _fiftyPercent = 50.0;

Future<void> _writeArb(
  Directory dir,
  String fileName,
  Map<String, dynamic> content,
) async {
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(jsonEncode(content));
}

void main() {
  group('scanLocalizationLocales (LocaleStats integration)', () {
    late Directory tempDir;
    late Directory l10nDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fcheck_scanner_test_');
      l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // --- LocaleStats fields ---

    test('locale with complete translation has correct fields', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
        _goodbyeKey: 'Adiós',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final es = result.localeStats['es']!;

      expect(es.languageCode, equals('es'));
      expect(es.languageName, equals('Spanish'));
      expect(es.translationCount, equals(_two));
      expect(es.missingCount, equals(_zero));
      expect(es.coveragePercentage, equals(_fullCoverage));
    });

    test('locale with partial translation has correct fields', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final es = result.localeStats['es']!;

      expect(es.translationCount, equals(_one));
      expect(es.missingCount, equals(_one));
      expect(es.coveragePercentage, equals(_fiftyPercent));
    });

    test('locale with all keys missing has zero translationCount', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      // Spanish file has the key but with the same value — flagged as untranslated
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hello',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final es = result.localeStats['es']!;

      expect(es.translationCount, equals(_zero));
      expect(es.missingCount, equals(_one));
      expect(es.coveragePercentage, equals(_zeroCoverage));
    });

    // --- isComplete ---

    test('isComplete is true at 100% coverage', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      expect(result.localeStats['es']!.isComplete, isTrue);
    });

    test('isComplete is false when translations are missing', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      expect(result.localeStats['es']!.isComplete, isFalse);
    });

    // --- hasTranslations ---

    test(
      'hasTranslations is true when at least one key is translated',
      () async {
        await _writeArb(l10nDir, _englishArb, {
          '@@locale': 'en',
          _helloKey: 'Hello',
          _goodbyeKey: 'Goodbye',
        });
        await _writeArb(l10nDir, _spanishArb, {
          '@@locale': 'es',
          _helloKey: 'Hola',
        });

        final result = scanLocalizationLocales(tempDir.path);
        expect(result.localeStats['es']!.hasTranslations, isTrue);
      },
    );

    test('hasTranslations is false when no keys are translated', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hello',
      });

      final result = scanLocalizationLocales(tempDir.path);
      expect(result.localeStats['es']!.hasTranslations, isFalse);
    });

    // --- format() / toString() ---

    test('format() returns "complete" status for 100% locale', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final es = result.localeStats['es']!;

      expect(es.format(), contains('complete'));
      expect(es.format(), contains('Spanish'));
      expect(es.format(), contains('es'));
      expect(es.toString(), equals(es.format()));
    });

    test('format() returns missing-count status for partial locale', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final formatted = result.localeStats['es']!.format();

      expect(formatted, contains('missing'));
      expect(formatted, contains('1'));
    });

    test(
      'format() returns "no translations" when translationCount is zero',
      () async {
        await _writeArb(l10nDir, _englishArb, {
          '@@locale': 'en',
          _helloKey: 'Hello',
        });
        await _writeArb(l10nDir, _spanishArb, {
          '@@locale': 'es',
          _helloKey: 'Hello',
        });

        final result = scanLocalizationLocales(tempDir.path);
        expect(result.localeStats['es']!.format(), contains('no translations'));
      },
    );

    // --- toJson() ---

    test('toJson() returns all expected keys with correct values', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final json = result.localeStats['es']!.toJson();

      expect(json['languageCode'], equals('es'));
      expect(json['languageName'], equals('Spanish'));
      expect(json['translationCount'], equals(_one));
      expect(json['missingCount'], equals(_zero));
      expect(json['coveragePercentage'], equals(_fullCoverage));
      expect(json['isComplete'], isTrue);
      expect(json['hasTranslations'], isTrue);
    });

    // --- operator== and hashCode ---

    test('two LocaleStats with the same languageCode are equal', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });
      await _writeArb(l10nDir, _frenchArb, {
        '@@locale': 'fr',
        _helloKey: 'Bonjour',
      });

      final result = scanLocalizationLocales(tempDir.path);
      final es1 = result.localeStats['es']!;
      final es2 = result.localeStats['es']!;
      final fr = result.localeStats['fr']!;

      expect(es1, equals(es2));
      expect(es1.hashCode, equals(es2.hashCode));
      expect(es1, isNot(equals(fr)));
    });

    // --- scanner edge cases ---

    test('returns empty localeStats for empty analysisRootPath', () {
      final result = scanLocalizationLocales('');
      expect(result.localeStats, isEmpty);
      expect(result.baseLocaleCode, isNull);
      expect(result.baseTranslationCount, equals(_zero));
    });

    test('returns empty localeStats when no l10n directory exists', () {
      final result = scanLocalizationLocales(tempDir.path);
      expect(result.localeStats, isEmpty);
    });

    test('returns localeStats for all locales including base', () async {
      await _writeArb(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
      });
      await _writeArb(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
      });

      final result = scanLocalizationLocales(tempDir.path);

      expect(result.localeStats.keys, containsAll(['en', 'es']));
      expect(result.baseLocaleCode, equals('en'));
      expect(result.baseTranslationCount, equals(_one));
    });
  });
}
