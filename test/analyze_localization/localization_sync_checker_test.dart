import 'dart:io';

import 'package:fcheck/src/analyzers/localization/localization_sync_checker.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The generated class gen-l10n writes for [keys].
String _generated(
  List<String> keys, {
  String extra = '',
  String statics = '',
}) =>
    '''
abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => null;
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  $statics
${keys.map((key) => '  String get $key;').join('\n')}
  String greeting(String name);
}

class _AppLocalizationsDelegate {}

AppLocalizations lookupAppLocalizations(Locale locale) => throw '';
$extra
''';

void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('fcheck_l10n_sync_');
    Directory(p.join(projectDir.path, 'lib', 'l10n'))
        .createSync(recursive: true);
  });

  tearDown(() => projectDir.deleteSync(recursive: true));

  void write(String name, String content) =>
      File(p.join(projectDir.path, 'lib', 'l10n', name))
          .writeAsStringSync(content);

  test('is in sync when every key is in the template ARB file', () {
    write('app_en.arb', '{"title": "Concerts", "greeting": "Hi {name}"}');
    write('app_localizations.dart', _generated(['title']));

    final sync = const LocalizationSyncChecker().check(projectDir)!;

    expect(sync.isInSync, isTrue);
    expect(sync.outputClass, 'AppLocalizations');
  });

  test('reports keys and code written by hand', () {
    write('app_en.arb', '{"title": "Concerts"}');
    write(
      'app_localizations.dart',
      _generated(
        ['title', 'cancel'],
        statics:
            'static Locale resolvePreferredLocale() => const Locale("en");',
        extra: 'extension AppLocalizationsExtension on BuildContext {}',
      ),
    );

    final sync = const LocalizationSyncChecker().check(projectDir)!;

    expect(sync.isInSync, isFalse);
    expect(sync.generatedOnlyKeys, ['cancel', 'greeting']);
    expect(sync.handWrittenMembers, [
      'resolvePreferredLocale',
      'extension AppLocalizationsExtension',
    ]);
  });

  test('reports template keys the generated class lacks', () {
    write('app_en.arb', '{"title": "Concerts", "greeting": "Hi", "venue": ""}');
    write('app_localizations.dart', _generated(['title']));

    final sync = const LocalizationSyncChecker().check(projectDir)!;

    expect(sync.isInSync, isFalse);
    expect(sync.missingKeys, ['venue']);
    expect(sync.generatedOnlyKeys, isEmpty);
  });

  test('reports instance members gen-l10n does not write', () {
    write('app_en.arb', '{"title": "Concerts", "greeting": "Hi"}');
    write(
      'app_localizations.dart',
      _generated(
        ['title'],
        statics: '''
  AppLocalizations.fallback();
  final String localeName;
  int retries = 0;
  bool isReady() => true;
  String shout() => title.toUpperCase();''',
      ),
    );

    final sync = const LocalizationSyncChecker().check(projectDir)!;

    expect(sync.handWrittenMembers, [
      'AppLocalizations.fallback',
      'retries',
      'isReady',
      'shout',
    ]);
    expect(sync.generatedOnlyKeys, isEmpty);
    expect(sync.missingKeys, isEmpty);
  });

  test('has nothing to compare without a generated class', () {
    write('app_en.arb', '{"title": "Concerts"}');

    expect(const LocalizationSyncChecker().check(projectDir), isNull);
  });

  test('has nothing to compare when the generated file lacks the class', () {
    write('app_en.arb', '{"title": "Concerts"}');
    write('app_localizations.dart', '');

    expect(const LocalizationSyncChecker().check(projectDir), isNull);
  });
}
