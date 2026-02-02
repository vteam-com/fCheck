/// Length of the header and footer lines
final int deviderLength = 40;

/// Prints a formatted header/footer
void printDivider(String title, {bool downPointer = true, bool dot = false}) {
  title = ' $title ';
  String directionChar = downPointer ? '↓' : '↑';
  String sideLines = (dot ? '·' : '-') * (deviderLength - (title.length ~/ 2));

  print('$directionChar$sideLines$title$sideLines$directionChar');
}
