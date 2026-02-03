/// Length of the header and footer lines
final int dividerLength = 40;
const int _halfTitleLengthDivisor = 2;

/// Prints a formatted header/footer
void printDivider(String title, {bool downPointer = true, bool dot = false}) {
  title = ' $title ';
  String directionChar = downPointer ? '↓' : '↑';
  String sideLines = (dot ? '·' : '-') *
      (dividerLength - (title.length ~/ _halfTitleLengthDivisor));

  print('$directionChar$sideLines$title$sideLines$directionChar');
}
