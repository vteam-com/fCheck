import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart';
import 'package:test/test.dart';

void main() {
  group('HardcodedStringUtils', () {
    test('containsMeaningfulText detects alphanumeric content', () {
      expect(HardcodedStringUtils.containsMeaningfulText(''), isFalse);
      expect(HardcodedStringUtils.containsMeaningfulText('   '), isFalse);
      expect(HardcodedStringUtils.containsMeaningfulText('---'), isFalse);
      expect(HardcodedStringUtils.containsMeaningfulText('abc'), isTrue);
      expect(HardcodedStringUtils.containsMeaningfulText('123'), isTrue);
    });

    test('isTechnicalString identifies common technical patterns', () {
      const positives = [
        'https://example.com',
        'user@example.com',
        '#FFAABB',
        '123',
        '12.5ms',
        'MY_CONST_VALUE',
        'snake_case_value',
        'getBluetoothState',
        '/path/to/file',
        'assets/images/icon.png',
        '../config/app.json',
        'rooms//invitees',
        '?mode=&room=&players=',
        r'C:\temp\app.log',
        'file.dart',
        'name.ext',
        'build-01',
      ];

      for (final value in positives) {
        expect(HardcodedStringUtils.isTechnicalString(value), isTrue);
      }
    });

    test('isTechnicalString ignores plain phrases', () {
      expect(HardcodedStringUtils.isTechnicalString('Hello world'), isFalse);
      expect(HardcodedStringUtils.isTechnicalString('PlainText'), isFalse);
    });
  });
}
