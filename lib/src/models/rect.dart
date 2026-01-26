/// Simple rectangle class for folder dimensions.
class Rect {
  /// Left position.
  final double x;

  /// Top position.
  final double y;

  /// Width of the rectangle.
  final double width;

  /// Height of the rectangle.
  final double height;

  /// Creates a rectangle from left, top, width, height.
  Rect.fromLTWH(this.x, this.y, this.width, this.height);
}
