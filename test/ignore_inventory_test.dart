import 'dart:io';

import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_inventory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String _magicNumbersToken = 'fcheck_magic_numbers';
const String _hardcodedStringsToken = 'fcheck_hardcoded_strings';
const String _hardcodedStringsLegacyToken =
    'avoid_hardcoded_strings_in_widgets';
const int _one = 1;
const int _two = 2;
const int _three = 3;

void main() {
  group('collectIgnoreInventory', () {
    late Directory tempDir;
    late FcheckConfig config;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_inventory_test_');
      config = FcheckConfig.loadForInputDirectory(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns empty inventory when no Dart files exist', () {
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, isEmpty);
      expect(inventory.configExcludePatterns, isEmpty);
      expect(inventory.analyzersDisabled, isEmpty);
      expect(inventory.analyzersIgnoredLegacy, isEmpty);
    });

    test(
      'returns empty inventory for Dart files with no ignore directives',
      () {
        File(p.join(tempDir.path, 'main.dart')).writeAsStringSync('''
void main() {
  final x = 42;
}
''');

        final inventory = collectIgnoreInventory(
          rootDirectory: tempDir,
          fcheckConfig: config,
        );

        expect(inventory.dartCommentDirectives, isEmpty);
      },
    );

    test('collects inline ignore directive from a Dart file', () {
      File(p.join(tempDir.path, 'widget.dart')).writeAsStringSync('''
void main() {
  final x = 42; // ignore: fcheck_magic_numbers
}
''');

      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_one));
      final d = inventory.dartCommentDirectives.first;
      expect(d.token, equals(_magicNumbersToken));
      expect(d.line, equals(_two));
      expect(d.path, endsWith('widget.dart'));
    });

    test('collects ignore_for_file hardcoded-strings legacy directive', () {
      File(p.join(tempDir.path, 'screen.dart')).writeAsStringSync('''
// ignore_for_file: avoid_hardcoded_strings_in_widgets
void build() {}
''');

      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_one));
      expect(
        inventory.dartCommentDirectives.first.token,
        equals(_hardcodedStringsLegacyToken),
      );
    });

    test('collects multiple tokens from multiple files', () {
      File(p.join(tempDir.path, 'a.dart')).writeAsStringSync('''
// ignore: fcheck_magic_numbers
void a() {}
''');
      File(p.join(tempDir.path, 'b.dart')).writeAsStringSync('''
void b() {
  final s = "hi"; // ignore: fcheck_hardcoded_strings
}
''');

      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_two));
      final tokens = inventory.dartCommentDirectives.map((d) => d.token);
      expect(tokens, containsAll([_magicNumbersToken, _hardcodedStringsToken]));
    });

    test('collects multiple tokens from one ignore line', () {
      File(p.join(tempDir.path, 'multi.dart')).writeAsStringSync('''
void fn() {
  final x = 1; // ignore: fcheck_magic_numbers, fcheck_hardcoded_strings
}
''');

      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_two));
    });

    test('directives are sorted by path then by line then by token', () {
      File(p.join(tempDir.path, 'b.dart')).writeAsStringSync('''
void b() {
  final x = 1; // ignore: fcheck_magic_numbers
}
''');
      File(p.join(tempDir.path, 'a.dart')).writeAsStringSync('''
// ignore: fcheck_hardcoded_strings
void a() {}
''');

      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_two));
      // 'a.dart' sorts before 'b.dart'
      expect(inventory.dartCommentDirectives.first.path, endsWith('a.dart'));
    });
  });

  // ------------------------------------------------------------
  // IgnoreInventory (model)
  // ------------------------------------------------------------
  group('IgnoreInventory', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_inventory_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('dartCommentDirectivesByType groups directives by token', () {
      File(p.join(tempDir.path, 'foo.dart')).writeAsStringSync('''
void fn() {
  final x = 1; // ignore: fcheck_magic_numbers
  final s = ""; // ignore: fcheck_hardcoded_strings
  final y = 2; // ignore: fcheck_magic_numbers
}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      final byType = inventory.dartCommentDirectivesByType;
      expect(
        byType.keys,
        containsAll([_magicNumbersToken, _hardcodedStringsToken]),
      );
      expect(byType[_magicNumbersToken], hasLength(_two));
      expect(byType[_hardcodedStringsToken], hasLength(_one));
    });

    test('dartCommentDirectivesByType returns sorted keys', () {
      File(p.join(tempDir.path, 'foo.dart')).writeAsStringSync('''
void fn() {
  final x = 1; // ignore: fcheck_magic_numbers
  final s = ""; // ignore: fcheck_hardcoded_strings
  final q = 0; // ignore: fcheck_layers
}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      final keys = inventory.dartCommentDirectivesByType.keys.toList();
      final sortedKeys = [...keys]..sort();
      expect(keys, equals(sortedKeys));
    });

    test('toJson() returns expected top-level keys', () {
      File(p.join(tempDir.path, 'foo.dart')).writeAsStringSync('''
// ignore: fcheck_magic_numbers
void fn() {}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      final json = inventory.toJson();
      expect(
        json.keys,
        containsAll([
          'configFilePath',
          'config',
          'dartCommentDirectives',
          'groupedByType',
          'totals',
        ]),
      );
      expect((json['totals']! as Map)['dartCommentDirectives'], equals(_one));
    });

    test('configFilePath is null when no .fcheck file exists', () {
      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.configFilePath, isNull);
    });

    test('configFilePath is relative path when .fcheck file exists', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('');
      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.configFilePath, equals('.fcheck'));
    });
  });

  // ------------------------------------------------------------
  // IgnoreDirectiveLocation
  // ------------------------------------------------------------
  group('IgnoreDirectiveLocation', () {
    test('toJson() returns all fields correctly', () {
      File(
        p.join(
          Directory.systemTemp.createTempSync('fcheck_directive_test_').path,
          'file.dart',
        ),
      ).writeAsStringSync('''
void fn() {
  final x = 99; // ignore: fcheck_magic_numbers
}
''');

      final tempDir2 = Directory.systemTemp.createTempSync('fcheck_dir2_');
      addTearDown(() => tempDir2.deleteSync(recursive: true));

      File(p.join(tempDir2.path, 'sample.dart')).writeAsStringSync('''
void fn() {
  final x = 99; // ignore: fcheck_magic_numbers
}
''');
      final config = FcheckConfig.loadForInputDirectory(tempDir2);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir2,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_one));
      final json = inventory.dartCommentDirectives.first.toJson();

      expect(json['path'], isA<String>());
      expect(json['line'], isA<int>());
      expect(json['token'], equals(_magicNumbersToken));
      expect(json['rawLine'], isA<String>());
      expect(json.keys, containsAll(['path', 'line', 'token', 'rawLine']));
    });
  });

  // ------------------------------------------------------------
  // _collectDartIgnoreDirectives coverage via collectIgnoreInventory
  // ------------------------------------------------------------
  group('_collectDartIgnoreDirectives edge cases', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_directives_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('ignores lines with no // comment', () {
      File(p.join(tempDir.path, 'no_comment.dart')).writeAsStringSync('''
void fn() {
  final x = 42;
}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, isEmpty);
    });

    test('ignores non-fcheck ignore tokens', () {
      File(p.join(tempDir.path, 'other.dart')).writeAsStringSync('''
void fn() {
  final x = 42; // ignore: missing_required_param
}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, isEmpty);
    });

    test('collects three different tokens from the same file', () {
      File(p.join(tempDir.path, 'mixed.dart')).writeAsStringSync('''
// ignore: fcheck_magic_numbers
// ignore: fcheck_hardcoded_strings
void fn() {
  // ignore: fcheck_layers
  return;
}
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final inventory = collectIgnoreInventory(
        rootDirectory: tempDir,
        fcheckConfig: config,
      );

      expect(inventory.dartCommentDirectives, hasLength(_three));
    });
  });
}
