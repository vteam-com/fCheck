import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/localization/localization_delegate.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _l10nRelativePath = 'lib/l10n';
const String _englishArb = 'app_en.arb';
const String _spanishArb = 'app_es.arb';
const String _frenchArb = 'app_fr.arb';
const String _germanArb = 'app_de.arb';
const String _portugueseBrazilArb = 'app_pt_BR.arb';
const String _chineseHansArb = 'app_zh_Hans.arb';
const String _helloKey = 'hello';
const String _goodbyeKey = 'goodbye';
const String _titleKey = 'title';
const String _welcomeKey = 'welcome';
const String _greetingKey = 'greeting';
const String _unusedKey = 'unused';
const String _namePlaceholder = 'name';
const String _otherPlaceholder = 'nombre';
const int _one = 1;
const int _zero = 0;
const int _two = 2;
const int _three = 3;
const double _zeroCoverage = 0.0;
const double _fiftyPercent = 50.0;
const double _fullCoverage = 100.0;
const double _thirtyThreePointThree = 33.3;

Future<File> _writeArbFile(
  Directory directory,
  String fileName,
  Map<String, dynamic> content,
) async {
  final file = File(p.join(directory.path, fileName));
  await file.writeAsString(jsonEncode(content));
  return file;
}

void main() {
  group('LocalizationDelegate', () {
    late Directory tempDir;
    late LocalizationDelegate delegate;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'fcheck_localization_test_',
      );
      delegate = LocalizationDelegate();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'analyzeFileWithContext returns empty list for individual files',
      () async {
        // Localization analysis is project-wide, so individual file analysis should return empty
        final testFile = File(p.join(tempDir.path, 'test.dart'));
        await testFile.writeAsString('void main() {}');

        final content = testFile.readAsStringSync();
        final parseResult = parseString(
          content: content,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );

        final context = AnalysisFileContext(
          file: testFile,
          content: content,
          parseResult: parseResult,
          lines: content.split('\n'),
          compilationUnit: parseResult.unit,
          hasParseErrors: parseResult.errors.isNotEmpty,
        );

        final result = delegate.analyzeFileWithContext(context);

        expect(result, isEmpty);
      },
    );

    test('analyzeProject returns empty list when no l10n directory exists', () {
      final result = delegate.analyzeProject(tempDir);
      expect(result, isEmpty);
    });

    test(
      'analyzeProject returns empty list when l10n directory exists but no ARB files',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        final result = delegate.analyzeProject(tempDir);
        expect(result, isEmpty);
      },
    );

    test('analyzeProject analyzes ARB files correctly', () async {
      // Create l10n directory
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      // Create base English ARB file
      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        _helloKey: 'Hello',
        _goodbyeKey: 'Goodbye',
        _welcomeKey: 'Welcome to our app',
        '@$_helloKey': {'description': 'Greeting message'},
        '@$_goodbyeKey': {'description': 'Farewell message'},
      });

      // Create Spanish ARB file with missing translations
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
        '@$_helloKey': {'description': 'Spanish greeting'},
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one));
      final issue = result.first;
      expect(issue.languageCode, equals('es'));
      expect(issue.languageName, equals('Spanish'));
      expect(
        issue.missingCount,
        equals(_two),
      ); // 'goodbye' and 'welcome' are missing
      expect(issue.totalCount, equals(_three)); // 3 keys in English base
      expect(
        issue.coveragePercentage,
        equals(_thirtyThreePointThree),
      ); // 1/3 = 33.333... rounded to 33.3
    });

    test('analyzeProject handles multiple language files', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      // Base English file
      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        _titleKey: 'App Title',
        'description': 'App Description',
      });

      // Spanish file - complete
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _titleKey: 'Título de la App',
        'description': 'Descripción de la App',
      });

      // French file - incomplete
      await _writeArbFile(l10nDir, _frenchArb, {
        '@@locale': 'fr',
        _titleKey: "Titre de l'App",
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one)); // Only French has missing translations
      final issue = result.first;
      expect(issue.languageCode, equals('fr'));
      expect(issue.languageName, equals('French'));
      expect(issue.missingCount, equals(_one)); // 'description' is missing
      expect(issue.totalCount, equals(_two));
    });

    test(
      'analyzeProject uses first ARB file as base if no English file found',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        // German file as base (no English file)
        await _writeArbFile(l10nDir, _germanArb, {
          '@@locale': 'de',
          _helloKey: 'Hallo',
          'world': 'Welt',
        });

        // French file - incomplete
        await _writeArbFile(l10nDir, _frenchArb, {
          '@@locale': 'fr',
          _helloKey: 'Bonjour',
        });

        final result = delegate.analyzeProject(tempDir);

        expect(result, hasLength(_one));
        final issue = result.first;
        expect(issue.languageCode, equals('fr'));
        expect(issue.languageName, equals('French'));
        expect(issue.missingCount, equals(_one)); // 'world' is missing
        expect(issue.totalCount, equals(_two));
      },
    );

    test('analyzeProject handles malformed ARB files gracefully', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      // Valid English file
      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        'valid': 'Valid String',
      });

      // Malformed Spanish file
      await File(
        p.join(l10nDir.path, _spanishArb),
      ).writeAsString('invalid yaml content {{{');

      final result = delegate.analyzeProject(tempDir);

      // Should skip malformed file and not report issues for it
      expect(result, isEmpty);
    });

    test('language code extraction through project analysis', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      // Test various naming patterns by creating files and checking if they're detected
      final files = {
        _englishArb: {
          '@@locale': 'en',
          _helloKey: 'Hello',
          _goodbyeKey: 'Goodbye',
        },
        _spanishArb: {'@@locale': 'es', _helloKey: 'Hola'},
        'messages_fr.arb': {'@@locale': 'fr', _helloKey: 'Bonjour'},
        'l10n_de.arb': {'@@locale': 'de', _goodbyeKey: 'Auf Wiedersehen'},
      };

      for (final fileName in files.entries) {
        await _writeArbFile(l10nDir, fileName.key, fileName.value);
      }

      final result = delegate.analyzeProject(tempDir);

      // Should detect 3 languages with missing translations (es, fr, de)
      expect(result, hasLength(_three));

      final languageCodes = result.map((issue) => issue.languageCode).toSet();
      expect(languageCodes, contains('es'));
      expect(languageCodes, contains('fr'));
      expect(languageCodes, contains('de'));
    });

    test('language name mapping through project analysis', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      // Base English file
      await _writeArbFile(l10nDir, _englishArb, {_helloKey: 'Hello'});

      // Spanish file
      final esArbFile = await _writeArbFile(l10nDir, _spanishArb, {
        _helloKey: 'Hola',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, isEmpty); // Spanish is complete, so no issues

      // Now create an incomplete Spanish file to test language name
      await esArbFile.writeAsString(jsonEncode({'different': 'Diferente'}));

      final result2 = delegate.analyzeProject(tempDir);
      expect(result2, hasLength(_one));
      expect(result2.first.languageName, equals('Spanish'));
    });

    test(
      'analyzeProject supports locale variants like pt_BR and zh_Hans',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        await _writeArbFile(l10nDir, _englishArb, {
          '@@locale': 'en',
          _helloKey: 'Hello',
          _goodbyeKey: 'Goodbye',
        });
        await _writeArbFile(l10nDir, _portugueseBrazilArb, {
          '@@locale': 'pt_BR',
          _helloKey: 'Olá',
        });
        await _writeArbFile(l10nDir, _chineseHansArb, {
          '@@locale': 'zh_Hans',
          _goodbyeKey: '再见',
        });

        final result = delegate.analyzeProject(tempDir);

        expect(result, hasLength(_two));
        final issueByCode = {
          for (final issue in result) issue.languageCode: issue,
        };
        expect(issueByCode.keys, contains('pt_BR'));
        expect(issueByCode.keys, contains('zh_Hans'));
        expect(issueByCode['pt_BR']!.languageName, equals('Portuguese'));
        expect(issueByCode['zh_Hans']!.languageName, equals('Chinese'));
        expect(issueByCode['pt_BR']!.missingCount, equals(_one));
        expect(issueByCode['zh_Hans']!.missingCount, equals(_one));
      },
    );

    test(
      'analyzeProject uses deterministic alphabetical fallback when no English file exists',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        await _writeArbFile(l10nDir, _frenchArb, {
          '@@locale': 'fr',
          _helloKey: 'Bonjour',
        });
        await _writeArbFile(l10nDir, _spanishArb, {
          '@@locale': 'es',
          _goodbyeKey: 'Adiós',
        });
        await _writeArbFile(l10nDir, _germanArb, {
          '@@locale': 'de',
          _helloKey: 'Hallo',
          _goodbyeKey: 'Auf Wiedersehen',
        });

        final result = delegate.analyzeProject(tempDir);

        expect(result, hasLength(_two));
        final languageCodes = result.map((issue) => issue.languageCode).toSet();
        expect(languageCodes, contains('es'));
        expect(languageCodes, contains('fr'));

        for (final issue in result) {
          expect(issue.missingCount, equals(_one));
          expect(issue.totalCount, equals(_two));
        }
      },
    );

    test('analyzeProject supports a non-English base locale', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _helloKey: 'Hola',
        _goodbyeKey: 'Adiós',
      });
      await _writeArbFile(l10nDir, _frenchArb, {
        '@@locale': 'fr',
        _helloKey: 'Bonjour',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one));
      expect(result.first.languageCode, equals('fr'));
      expect(result.first.languageName, equals('French'));
      expect(result.first.missingCount, equals(_one));
      expect(result.first.totalCount, equals(_two));
    });

    test('analyzeProject flags empty translations as missing', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        _welcomeKey: 'Welcome',
      });
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _welcomeKey: '',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one));
      expect(result.first.languageCode, equals('es'));
      expect(result.first.missingCount, equals(_one));
      expect(result.first.totalCount, equals(_one));
      expect(result.first.coveragePercentage, equals(_zeroCoverage));
    });

    test(
      'analyzeProject flags untranslated identical strings as missing',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        await _writeArbFile(l10nDir, _englishArb, {
          '@@locale': 'en',
          _titleKey: 'Home',
        });
        await _writeArbFile(l10nDir, _spanishArb, {
          '@@locale': 'es',
          _titleKey: 'Home',
        });

        final result = delegate.analyzeProject(tempDir);

        expect(result, hasLength(_one));
        expect(result.first.languageCode, equals('es'));
        expect(result.first.missingCount, equals(_one));
        expect(result.first.totalCount, equals(_one));
      },
    );

    test('analyzeProject flags duplicate keys as issues', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        'cancel': 'Cancel',
        'ok': 'OK',
      });
      await File(p.join(l10nDir.path, _spanishArb)).writeAsString('''
{
  "@@locale": "es",
  "cancel": "Cancelar",
  "cancel": "Cancelar otra vez",
  "ok": "Vale"
}
''');

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one));
      final issue = result.first;
      expect(issue.languageCode, equals('es'));
      expect(issue.missingCount, equals(_zero));
      expect(issue.totalCount, equals(_two));
      expect(
        issue.problemCounts[LocalizationTranslationProblemType.duplicateKey],
        equals(_one),
      );
      expect(issue.details, hasLength(_one));
      expect(
        issue.details.first.problemType,
        equals(LocalizationTranslationProblemType.duplicateKey),
      );
      expect(issue.details.first.key, equals('cancel'));
    });

    test('analyzeProject ignores keys marked do not translate', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        'anapayTitle': 'anapay',
        '@anapayTitle': {
          'description': 'DO NOT TRANSLATE. This is the official brand name.',
        },
      });
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        'anapayTitle': 'anapay',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, isEmpty);
    });

    test('analyzeProject ignores keys marked ignore', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        'anapayTitle': 'anapay',
        '@anapayTitle': {
          'description': 'IGNORE. Keep the brand name unchanged.',
        },
      });
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        'anapayTitle': 'anapay',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, isEmpty);
    });

    test('analyzeProject ignores keys marked reviewed', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        _titleKey: 'Table',
      });
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _titleKey: 'Table',
        '@$_titleKey': {'description': 'reviewed'},
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, isEmpty);
    });

    test(
      'analyzeProject flags unused English keys as orphan strings',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        final libDir = Directory(p.join(tempDir.path, 'lib'));
        await l10nDir.create(recursive: true);
        await libDir.create(recursive: true);

        await _writeArbFile(l10nDir, _englishArb, {
          '@@locale': 'en',
          _helloKey: 'Hello',
          _unusedKey: 'Unused',
        });
        await File(p.join(libDir.path, 'main.dart')).writeAsString('''
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SampleWidget extends StatelessWidget {
  const SampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(l10n.$_helloKey);
  }
}
''');
        await File(
          p.join(l10nDir.path, 'app_localizations.dart'),
        ).writeAsString('''
class AppLocalizations {
  String get $_helloKey => 'Hello';
  String get $_unusedKey => 'Unused';
}
''');

        final result = delegate.analyzeProject(tempDir);

        expect(result, hasLength(_one));
        final issue = result.first;
        expect(issue.languageCode, equals('en'));
        expect(issue.languageName, equals('English'));
        expect(issue.missingCount, equals(_zero));
        expect(issue.totalCount, equals(_two));
        expect(
          issue.problemCounts[LocalizationTranslationProblemType.unusedKey],
          equals(_one),
        );
        expect(issue.details, hasLength(_one));
        expect(
          issue.details.first.problemType,
          equals(LocalizationTranslationProblemType.unusedKey),
        );
        expect(issue.details.first.key, equals(_unusedKey));
      },
    );

    test(
      'analyzeProject does not flag key used via AppLocalizations.of()!.key',
      () async {
        final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
        final libDir = Directory(p.join(tempDir.path, 'lib'));
        await l10nDir.create(recursive: true);
        await libDir.create(recursive: true);

        await _writeArbFile(l10nDir, _englishArb, {
          '@@locale': 'en',
          _helloKey: 'Hello',
        });
        await File(p.join(libDir.path, 'main.dart')).writeAsString('''
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void useKey(BuildContext context) {
  // null-assertion on a multi-line call
  final msg = AppLocalizations.of(
    // ignore: use_build_context_synchronously
    context,
  )!.$_helloKey;
  print(msg);
}
''');
        await File(
          p.join(l10nDir.path, 'app_localizations.dart'),
        ).writeAsString('''
class AppLocalizations {
  String get $_helloKey => 'Hello';
}
''');

        final result = delegate.analyzeProject(tempDir);

        expect(result, isEmpty);
      },
    );

    test('analyzeProject flags placeholder drift as missing', () async {
      final l10nDir = Directory(p.join(tempDir.path, _l10nRelativePath));
      await l10nDir.create(recursive: true);

      await _writeArbFile(l10nDir, _englishArb, {
        '@@locale': 'en',
        _greetingKey: 'Hello {$_namePlaceholder}',
      });
      await _writeArbFile(l10nDir, _spanishArb, {
        '@@locale': 'es',
        _greetingKey: 'Hola {$_otherPlaceholder}',
      });

      final result = delegate.analyzeProject(tempDir);

      expect(result, hasLength(_one));
      expect(result.first.languageCode, equals('es'));
      expect(result.first.missingCount, equals(_one));
      expect(result.first.totalCount, equals(_one));
    });

    test('coverage percentage calculation handles edge cases', () {
      // Test through project analysis with empty base file
      final issue = LocalizationIssue(
        languageCode: 'es',
        languageName: 'Spanish',
        missingCount: 0,
        totalCount: 0,
      );
      expect(
        issue.coveragePercentage,
        equals(_fullCoverage),
      ); // Empty case should be 100%

      final issue2 = LocalizationIssue(
        languageCode: 'fr',
        languageName: 'French',
        missingCount: 1,
        totalCount: _two,
      );
      expect(issue2.coveragePercentage, equals(_fiftyPercent));
    });

    group('fix mode', () {
      late Directory fixTempDir;

      setUp(() async {
        fixTempDir = await Directory.systemTemp.createTemp(
          'fcheck_localization_fix_test_',
        );
      });

      tearDown(() async {
        if (await fixTempDir.exists()) {
          await fixTempDir.delete(recursive: true);
        }
      });

      test('fix sorts ARB keys alphabetically', () async {
        final l10nDir = Directory(p.join(fixTempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        // Write keys in reverse alphabetical order.
        final arbFile = File(p.join(l10nDir.path, _englishArb));
        await arbFile.writeAsString('''
{
  "@@locale": "en",
  "welcome": "Welcome",
  "title": "Title",
  "hello": "Hello",
  "goodbye": "Goodbye"
}
''');

        final fixDelegate = LocalizationDelegate(fix: true);
        fixDelegate.analyzeProject(fixTempDir);

        final rawContent = arbFile.readAsStringSync();
        final decoded = jsonDecode(rawContent) as Map<String, dynamic>;
        final allKeys = decoded.keys.toList();
        // @@locale is kept at top.
        expect(allKeys.first, equals('@@locale'));
        final translatableKeys = allKeys
            .where((k) => !k.startsWith('@'))
            .toList();
        final sortedExpected = List<String>.from(translatableKeys)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        expect(translatableKeys, equals(sortedExpected));
      });

      test('fix keeps @key metadata paired with its base key', () async {
        final l10nDir = Directory(p.join(fixTempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        // Write keys in reverse order; each has a @key counterpart.
        final arbFile = File(p.join(l10nDir.path, _englishArb));
        await arbFile.writeAsString('''
{
  "@@locale": "en",
  "welcome": "Welcome",
  "@welcome": { "description": "Welcome message" },
  "appName": "MyApp",
  "@appName": { "description": "App name" }
}
''');

        final fixDelegate = LocalizationDelegate(fix: true);
        fixDelegate.analyzeProject(fixTempDir);

        final rawContent = arbFile.readAsStringSync();
        final decoded = jsonDecode(rawContent) as Map<String, dynamic>;
        final orderedKeys = decoded.keys.toList();

        // appName should come before welcome alphabetically.
        final appNameIndex = orderedKeys.indexOf('appName');
        final atAppNameIndex = orderedKeys.indexOf('@appName');
        final welcomeIndex = orderedKeys.indexOf('welcome');
        final atWelcomeIndex = orderedKeys.indexOf('@welcome');

        expect(appNameIndex, lessThan(welcomeIndex));
        // @key immediately follows its base key.
        expect(atAppNameIndex, equals(appNameIndex + _one));
        expect(atWelcomeIndex, equals(welcomeIndex + _one));
      });

      test('fix removes duplicate keys', () async {
        final l10nDir = Directory(p.join(fixTempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        // Write a file with an exact duplicate key.
        final arbFile = File(p.join(l10nDir.path, _englishArb));
        await arbFile.writeAsString('''
{
  "@@locale": "en",
  "cancel": "Cancel",
  "cancel": "Cancel",
  "ok": "OK"
}
''');

        final fixDelegate = LocalizationDelegate(fix: true);
        final issues = fixDelegate.analyzeProject(fixTempDir);

        // After fix there should be no duplicate issues.
        final duplicateIssues = issues
            .expand((issue) => issue.details)
            .where(
              (d) =>
                  d.problemType ==
                  LocalizationTranslationProblemType.duplicateKey,
            )
            .toList();
        expect(duplicateIssues, isEmpty);

        // The written file should contain 'cancel' exactly once.
        final rawContent = arbFile.readAsStringSync();
        final cancelCount = RegExp(
          r'"cancel"\s*:',
        ).allMatches(rawContent).length;
        expect(cancelCount, equals(_one));
      });

      test(
        'fix does not modify files that are already sorted and clean',
        () async {
          final l10nDir = Directory(p.join(fixTempDir.path, _l10nRelativePath));
          await l10nDir.create(recursive: true);

          const alreadySorted =
              '{\n'
              '  "@@locale": "en",\n'
              '  "appName": "MyApp",\n'
              '  "hello": "Hello"\n'
              '}';
          final arbFile = File(p.join(l10nDir.path, _englishArb));
          // Write without trailing newline to exercise the identity path when
          // the serialised output doesn't match the original whitespace exactly.
          await arbFile.writeAsString(alreadySorted);

          final fixDelegate = LocalizationDelegate(fix: true);
          fixDelegate.analyzeProject(fixTempDir);

          // The file content should still decode to the same logical map.
          final decoded =
              jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
          expect(decoded['appName'], equals('MyApp'));
          expect(decoded['hello'], equals('Hello'));
        },
      );

      test('fix leaves @@locale at the top', () async {
        final l10nDir = Directory(p.join(fixTempDir.path, _l10nRelativePath));
        await l10nDir.create(recursive: true);

        final arbFile = File(p.join(l10nDir.path, _englishArb));
        await arbFile.writeAsString('''
{
  "@@locale": "en",
  "zebra": "Zebra",
  "alpha": "Alpha"
}
''');

        final fixDelegate = LocalizationDelegate(fix: true);
        fixDelegate.analyzeProject(fixTempDir);

        final rawContent = arbFile.readAsStringSync();
        final decoded = jsonDecode(rawContent) as Map<String, dynamic>;
        expect(decoded.keys.first, equals('@@locale'));
        expect(decoded.keys.elementAt(_one), equals('alpha'));
        expect(decoded.keys.elementAt(_two), equals('zebra'));
      });
    });
  });
}
