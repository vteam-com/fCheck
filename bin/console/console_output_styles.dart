part of 'console_output.dart';

/// Prints fatal analysis error and stack trace details.
///
/// This keeps CLI failures transparent for local debugging and CI logs.
void printAnalysisError(Object error, StackTrace stack) {
  print(AppStrings.analysisErrorLine(error));
  print(stack);
}

/// Length of the header and footer lines
final int dividerLength = 37;
const int _halfTitleLengthDivisor = 2;

const int _ansiGreen = 32;
const int _ansiGreenBright = 92;
const int _ansiYellow = 33;
const int _ansiYellowBright = 93;
const int _ansiOrange = 33;
const String _ansiOrangeCode = '38;5;208';
const int _ansiRed = 31;
const int _ansiRedBright = 91;
const int _ansiGray = 90;
const int _ansiWhiteBright = 97;
final RegExp _leadingStatusTagPattern = RegExp(
  r'^(\s*)(?:\x1B\[[0-9;]*m)?\[(?:✓|!|✗|-)\](?:\x1B\[[0-9;]*m)?\s*',
);

String _colorize(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[${colorCode}m$text\x1B[0m' : text;

String _colorizeWithCode(String text, String colorCode) =>
    supportsCliAnsiColors ? '\x1B[${colorCode}m$text\x1B[0m' : text;

String _colorizeBold(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[1;${colorCode}m$text\x1B[0m' : text;

/// Removes leading status markers (e.g. `[✓]`, `[!]`, `[✗]`, `[-]`).
String _withoutLeadingStatusTag(String line) {
  final match = _leadingStatusTagPattern.firstMatch(line);
  if (match == null) {
    return line;
  }
  final leadingWhitespace = match.group(1) ?? '';
  final rest = line.substring(match.end);
  return '$leadingWhitespace$rest';
}

/// Status markers styled like `flutter doctor`.
///
/// These are intentionally short and suitable for console output.
String okTag() => _colorize('[✓]', _ansiGreen);

/// Warning marker styled like `flutter doctor`.
///
/// This remains readable even without ANSI color support.
String warnTag() => _colorize('[!]', _ansiYellow);

/// Failure marker styled like `flutter doctor`.
///
/// The label uses a single-width glyph for alignment.
String failTag() => _colorize('[✗]', _ansiRed);

/// Informational marker for skipped checks.
String skipTag() => _colorize('[-]', _ansiGray);

/// Builds a formatted divider line for console headers/footers.
///
/// [title] is centered between repeated side characters.
/// [downPointer] controls arrow direction (`↓` vs `↑`).
/// [dot] switches from `-` to `·` style separators.
String dividerLine(String title, {bool? downPointer, bool dot = false}) {
  title = ' $title ';
  final lineType = dot ? '·' : '-';
  final directionChar = downPointer == null
      ? lineType
      : downPointer == true
      ? '↓'
      : '↑';
  final sideLines =
      lineType * (dividerLength - (title.length ~/ _halfTitleLengthDivisor));

  String lineAndTitle = '$sideLines$title$sideLines';

  if (lineAndTitle.length % _halfTitleLengthDivisor == 0) {
    lineAndTitle += lineType;
  }

  return _colorize('$directionChar$lineAndTitle$directionChar', _ansiGray);
}
