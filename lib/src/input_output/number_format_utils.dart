/// Formats an integer with comma separators for thousands grouping.
String formatCount(int value) {
  const int thousandsGroupSize = 3;
  final absValue = value.abs();
  final digits = absValue.toString();
  if (digits.length <= thousandsGroupSize) {
    return value.toString();
  }

  final remainder = digits.length % thousandsGroupSize;
  final firstGroupLength = remainder == 0 ? thousandsGroupSize : remainder;
  final buffer = StringBuffer()..write(digits.substring(0, firstGroupLength));

  for (var i = firstGroupLength; i < digits.length; i += thousandsGroupSize) {
    buffer
      ..write(',')
      ..write(digits.substring(i, i + thousandsGroupSize));
  }

  final formatted = buffer.toString();
  return value < 0 ? '-$formatted' : formatted;
}
