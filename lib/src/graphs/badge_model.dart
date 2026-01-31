/// Directional enum for triangle badge orientation.
///
/// [west] - Triangle points left (for incoming dependencies)
/// [east] - Triangle points right (for outgoing dependencies)
enum BadgeDirection {
  /// direction of the triangle pointing left
  west,

  /// direction of the triangle pointing right
  east
}

/// A model representing a directional triangular badge for dependency visualization.
///
/// This class creates triangular badges that indicate the direction of dependencies:
/// - Incoming badges point west (left) and are blue
/// - Outgoing badges point east (right) and are green
///
/// The badges are rendered as SVG paths with rounded corners and contain
/// a count number showing the number of dependencies.
class BadgeModel {
  /// The center X coordinate of the badge
  final double cx;

  /// The center Y coordinate of the badge
  final double cy;

  /// The dependency count to display in the badge
  final int count;

  /// The direction the triangle should point
  final BadgeDirection direction;

  /// List of peer dependencies for tooltip display
  final List<String> peers;

  /// Whether this badge represents incoming dependencies
  final bool isIncoming;

  /// Creates a new BadgeModel instance.
  ///
  /// [cx] - Center X coordinate
  /// [cy] - Center Y coordinate
  /// [count] - Dependency count to display
  /// [direction] - Direction the triangle should point
  /// [isIncoming] - True for incoming dependencies, false for outgoing
  /// [peers] - Optional list of peer dependency names for tooltips
  const BadgeModel({
    required this.cx,
    required this.cy,
    required this.count,
    required this.direction,
    required this.isIncoming,
    this.peers = const [],
  });

  /// Gets the fill color for the badge based on direction.
  ///
  /// Returns blue (#3b82f6) for incoming dependencies,
  /// green (#10b981) for outgoing dependencies.
  String get color => isIncoming
      ? '#3b82f6'
      : '#10b981'; // blue for incoming, green for outgoing

  /// Gets the CSS class name for styling the badge.
  ///
  /// Used for applying hover effects and other CSS styling.
  String get cssClass => isIncoming ? 'incomingBadge' : 'outgoingBadge';

  /// Renders the badge as an SVG element.
  ///
  /// Creates a triangular badge with rounded corners, containing the count number.
  /// The triangle points in the specified direction with appropriate colors.
  ///
  /// Returns an empty string if count is 0 or less.
  ///
  /// The SVG structure includes:
  /// - A path element for the triangular shape with rounded corners
  /// - A text element showing the dependency count
  /// - An optional title element for hover tooltips showing peer dependencies
  String renderSvg() {
    if (count <= 0) {
      return '';
    }

    final tooltip = peers.isEmpty
        ? ''
        : List.generate(peers.length, (i) => '${i + 1}. ${peers[i]}')
            .join('\n');
    final pathData = _getTrianglePath();
    final textX = direction == BadgeDirection.west ? cx + 5 : cx - 5;

    return '''<g class="$cssClass">
  <path d="$pathData" fill="$color"/>
  <text x="$textX" y="${cy + 3}" text-anchor="middle" fill="white" font-size="8" font-weight="bold">$count</text>${tooltip.isNotEmpty ? '<title>$tooltip</title>' : ''}</g>''';
  }

  /// Generates the SVG path data for a triangle with rounded corners.
  ///
  /// Uses quadratic Bézier curves to create smooth rounded corners at the triangle points.
  /// The triangle size is 14x18 pixels with 3px corner radius.
  ///
  /// For west direction: Points left with the flat edge on the right
  /// For east direction: Points right with the flat edge on the left
  String _getTrianglePath() {
    const size = 14.0;
    const height = 18.0;
    const radius = 3.0;

    switch (direction) {
      case BadgeDirection.west:
        // Triangle pointing left (incoming) with rounded corners
        final left = cx - height / 2;
        final right = cx + height / 2;
        final top = cy - size / 2;
        final bottom = cy + size / 2;

        return 'M ${left + radius},$cy '
            'L ${right - radius},$top '
            'Q $right,$top $right,${top + radius} '
            'L $right,${bottom - radius} '
            'Q $right,$bottom ${right - radius},$bottom '
            'Z';

      case BadgeDirection.east:
        // Triangle pointing right (outgoing) with rounded corners
        final left = cx - height / 2;
        final right = cx + height / 2;
        final top = cy - size / 2;
        final bottom = cy + size / 2;

        return 'M ${right - radius},$cy '
            'L ${left + radius},$top '
            'Q $left,$top $left,${top + radius} '
            'L $left,${bottom - radius} '
            'Q $left,$bottom ${left + radius},$bottom '
            'Z';
    }
  }

  /// Creates an incoming badge pointing west (left).
  ///
  /// Incoming badges are blue and indicate dependencies flowing into the component.
  ///
  /// [cx] - Center X coordinate
  /// [cy] - Center Y coordinate
  /// [count] - Number of incoming dependencies
  /// [peers] - Optional list of source dependency names
  factory BadgeModel.incoming({
    required double cx,
    required double cy,
    required int count,
    required BadgeDirection direction,
    List<String> peers = const [],
  }) {
    return BadgeModel(
      cx: cx,
      cy: cy,
      count: count,
      direction: direction,
      isIncoming: true,
      peers: peers,
    );
  }

  /// Creates an outgoing badge pointing east (right).
  ///
  /// Outgoing badges are green and indicate dependencies flowing from the component.
  ///
  /// [cx] - Center X coordinate
  /// [cy] - Center Y coordinate
  /// [count] - Number of outgoing dependencies
  /// [peers] - Optional list of target dependency names
  factory BadgeModel.outgoing({
    required double cx,
    required double cy,
    required int count,
    required BadgeDirection direction,
    List<String> peers = const [],
  }) {
    return BadgeModel(
      cx: cx,
      cy: cy,
      count: count,
      direction: direction,
      isIncoming: false,
      peers: peers,
    );
  }
}
