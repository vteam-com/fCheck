part of 'export_svg_code_size.dart';

/// Produces a binary treemap layout for [nodes] within [bounds].
///
/// Nodes are sorted by descending weight and recursively partitioned.
Map<String, _Rect> _layoutTreemap(List<_WeightedNode> nodes, _Rect bounds) {
  if (nodes.isEmpty || bounds.width <= 0 || bounds.height <= 0) {
    return const <String, _Rect>{};
  }

  final normalized =
      nodes.where((node) => node.weight > 0).toList(growable: false)
        ..sort((a, b) => b.weight.compareTo(a.weight));
  if (normalized.isEmpty) {
    return const <String, _Rect>{};
  }

  final output = <String, _Rect>{};
  _binaryTreemap(normalized, bounds, output);
  return output;
}

/// Recursively assigns rectangles to [nodes] using weighted binary splits.
///
/// The larger side of [rect] is chosen as split axis to keep rectangles less
/// skewed and improve label readability.
void _binaryTreemap(
  List<_WeightedNode> nodes,
  _Rect rect,
  Map<String, _Rect> output,
) {
  if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) {
    return;
  }
  if (nodes.length == 1) {
    output[nodes.first.id] = rect;
    return;
  }

  final total = nodes.fold<int>(0, (sum, node) => sum + node.weight);
  if (total <= 0) {
    return;
  }

  final half = total / _binarySplitHalfRatio;
  var prefix = 0;
  var splitIndex = 1;
  for (var i = 0; i < nodes.length - 1; i++) {
    prefix += nodes[i].weight;
    splitIndex = i + 1;
    if (prefix >= half) {
      break;
    }
  }

  final left = nodes.sublist(0, splitIndex);
  final right = nodes.sublist(splitIndex);
  final leftWeight = left.fold<int>(0, (sum, node) => sum + node.weight);
  final ratio = (leftWeight / total).clamp(0.0, 1.0);

  if (rect.width >= rect.height) {
    final splitWidth = rect.width * ratio;
    _binaryTreemap(
      left,
      _Rect(x: rect.x, y: rect.y, width: splitWidth, height: rect.height),
      output,
    );
    _binaryTreemap(
      right,
      _Rect(
        x: rect.x + splitWidth,
        y: rect.y,
        width: rect.width - splitWidth,
        height: rect.height,
      ),
      output,
    );
    return;
  }

  final splitHeight = rect.height * ratio;
  _binaryTreemap(
    left,
    _Rect(x: rect.x, y: rect.y, width: rect.width, height: splitHeight),
    output,
  );
  _binaryTreemap(
    right,
    _Rect(
      x: rect.x,
      y: rect.y + splitHeight,
      width: rect.width,
      height: rect.height - splitHeight,
    ),
    output,
  );
}
