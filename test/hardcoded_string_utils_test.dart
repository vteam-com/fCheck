import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart';
import 'package:test/test.dart';

void main() {
  group('HardcodedStringUtils', () {
    test('removeInterpolations removes \$name and \${} segments', () {
      expect(
        HardcodedStringUtils.removeInterpolations('Hello \$name'),
        equals('Hello '),
      );
      expect(
        HardcodedStringUtils.removeInterpolations('Value: \${user.id}'),
        equals('Value: '),
      );
    });

    test('removeInterpolations keeps escaped interpolation markers', () {
      expect(
        HardcodedStringUtils.removeInterpolations(r'Cost: \$5, tax: $tax'),
        equals(r'Cost: \$5, tax: '),
      );
      expect(
        HardcodedStringUtils.removeInterpolations(r'\$notInterpolation'),
        equals(r'\$notInterpolation'),
      );
    });

    test('isIdentifierChar matches Dart identifier characters', () {
      expect(HardcodedStringUtils.isIdentifierChar('a'), isTrue);
      expect(HardcodedStringUtils.isIdentifierChar('Z'), isTrue);
      expect(HardcodedStringUtils.isIdentifierChar('0'), isTrue);
      expect(HardcodedStringUtils.isIdentifierChar('_'), isTrue);
      expect(HardcodedStringUtils.isIdentifierChar('-'), isFalse);
      expect(HardcodedStringUtils.isIdentifierChar('.'), isFalse);
    });

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
        '/path/to/file',
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
