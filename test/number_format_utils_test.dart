import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:test/test.dart';

void main() {
  group('formatCount', () {
    test('formats small numbers without separators', () {
      expect(formatCount(0), equals('0'));
      expect(formatCount(999), equals('999'));
    });

    test('formats large numbers with separators', () {
      expect(formatCount(1000), equals('1,000'));
      expect(formatCount(1234567), equals('1,234,567'));
    });

    test('formats negative numbers with separators', () {
      expect(formatCount(-1234), equals('-1,234'));
    });
  });
}
