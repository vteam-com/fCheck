import 'dart:io';

/// Length of the header and footer lines
final int dividerLength = 40;
const int _halfTitleLengthDivisor = 2;

bool get _supportsAnsiEscapes => stdout.supportsAnsiEscapes;

const int _ansiGreen = 32;
const int _ansiYellow = 33;
const int _ansiRed = 31;

String _colorize(String text, int colorCode) =>
    _supportsAnsiEscapes ? '\x1B[${colorCode}m$text\x1B[0m' : text;

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

/// Prints a formatted header/footer
void printDivider(String title, {bool downPointer = true, bool dot = false}) {
  title = ' $title ';
  String directionChar = downPointer ? '↓' : '↑';
  String sideLines = (dot ? '·' : '-') *
      (dividerLength - (title.length ~/ _halfTitleLengthDivisor));

  print('$directionChar$sideLines$title$sideLines$directionChar');
}
