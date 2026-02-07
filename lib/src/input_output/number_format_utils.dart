/// Formats an integer with comma separators for thousands grouping.
String formatCount(int value) {
  final absValue = value.abs();
  final digits = absValue.toString();
  if (digits.length <= 3) {
    return value.toString();
  }

  final firstGroupLength = digits.length % 3 == 0 ? 3 : digits.length % 3;
  final buffer = StringBuffer()..write(digits.substring(0, firstGroupLength));

  for (var i = firstGroupLength; i < digits.length; i += 3) {
    buffer
      ..write(',')
      ..write(digits.substring(i, i + 3));
  }

  final formatted = buffer.toString();
  return value < 0 ? '-$formatted' : formatted;
}
