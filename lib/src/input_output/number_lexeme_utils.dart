const int _hexPrefixLength = 2;
const int _hexRadix = 16;

/// Parses a numeric lexeme into a double when possible.
///
/// Supports:
/// - decimal/scientific forms handled by [double.tryParse]
/// - signed hexadecimal integer forms like `0xA`, `-0x1`, `+0xFF`
double? parseNumericLexeme(String raw) {
  final trimmed = raw.trim().replaceAll('_', '');
  final parsed = double.tryParse(trimmed);
  if (parsed != null) {
    return parsed;
  }

  final sign = trimmed.startsWith('-')
      ? -1
      : trimmed.startsWith('+')
      ? 1
      : 1;
  final unsigned = (trimmed.startsWith('-') || trimmed.startsWith('+'))
      ? trimmed.substring(1)
      : trimmed;
  final lower = unsigned.toLowerCase();
  if (lower.startsWith('0x')) {
    final hexValue = int.tryParse(
      lower.substring(_hexPrefixLength),
      radix: _hexRadix,
    );
    if (hexValue != null) {
      return sign * hexValue.toDouble();
    }
  }

  return null;
}
