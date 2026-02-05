/// Shared helpers for hardcoded string analysis.
class HardcodedStringUtils {
  /// Minimum quote length for non-empty string literals.
  static const int minQuotedLength = 2;

  /// Offset from `$` to the next character when parsing interpolation.
  static const int dollarSignOffset = 1;

  /// ASCII code start for digits.
  static const int asciiDigitStart = 48;

  /// ASCII code end for digits.
  static const int asciiDigitEnd = 57;

  /// ASCII code start for uppercase letters.
  static const int asciiUpperStart = 65;

  /// ASCII code end for uppercase letters.
  static const int asciiUpperEnd = 90;

  /// ASCII code start for lowercase letters.
  static const int asciiLowerStart = 97;

  /// ASCII code end for lowercase letters.
  static const int asciiLowerEnd = 122;

  /// Removes interpolation segments from a string literal's content.
  static String removeInterpolations(String source) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (char == r'$' && (i == 0 || source[i - 1] != r'\')) {
        if (i + dollarSignOffset < source.length &&
            source[i + dollarSignOffset] == '{') {
          i += minQuotedLength;
          var depth = 1;
          while (i < source.length && depth > 0) {
            final current = source[i];
            if (current == '{') {
              depth++;
            } else if (current == '}') {
              depth--;
            }
            i++;
          }
          continue;
        }

        i += dollarSignOffset;
        while (i < source.length && isIdentifierChar(source[i])) {
          i++;
        }
        continue;
      }

      buffer.write(char);
      i++;
    }

    return buffer.toString();
  }

  /// Returns true if [char] can appear in a Dart identifier.
  static bool isIdentifierChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= asciiDigitStart && code <= asciiDigitEnd) || // 0-9
        (code >= asciiUpperStart && code <= asciiUpperEnd) || // A-Z
        (code >= asciiLowerStart && code <= asciiLowerEnd) || // a-z
        char == '_';
  }

  /// Returns true if [text] contains any alphanumeric characters.
  static bool containsMeaningfulText(String text) {
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final isAlphaNumeric =
          (code >= asciiDigitStart && code <= asciiDigitEnd) ||
              (code >= asciiUpperStart && code <= asciiUpperEnd) ||
              (code >= asciiLowerStart && code <= asciiLowerEnd);
      if (isAlphaNumeric) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if [value] matches common technical string patterns.
  static bool isTechnicalString(String value) {
    final technicalPatterns = [
      RegExp(r'^\w+://'),
      RegExp(r'^[\w\-\.]+@[\w\-\.]+\.\w+'),
      RegExp(r'^#[0-9A-Fa-f]{3,8}'),
      RegExp(r'^\d+(\.\d+)?[a-zA-Z]*'),
      RegExp(r'^[A-Z][A-Z0-9]*_[A-Z0-9_]*'),
      RegExp(r'^[a-z]+_[a-z_]+'),
      RegExp(r'^/[\w/\-\.]*'),
      RegExp(r'^\w+\.\w+'),
      RegExp(r'^[\w\-]+\.[\w]+'),
      RegExp(r'^[a-zA-Z0-9]*[_\-0-9]+[a-zA-Z0-9_\-]*'),
    ];

    return technicalPatterns.any((pattern) => pattern.hasMatch(value.trim()));
  }
}
