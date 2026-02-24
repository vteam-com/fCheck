part of 'export_svg_code_size.dart';

class _ClassGroup {
  final String label;
  final String sourcePath;
  final int size;
  final List<CodeSizeArtifact> callables;

  const _ClassGroup({
    required this.label,
    required this.sourcePath,
    required this.size,
    required this.callables,
  });
}

class _WeightedNode {
  final String id;
  final int weight;

  _WeightedNode({required this.id, required this.weight});
}

class _Rect {
  final double x;
  final double y;
  final double width;
  final double height;

  const _Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class _FolderTreeNode {
  final String name;
  final String path;
  final Map<String, _FolderTreeNode> children = <String, _FolderTreeNode>{};
  final List<CodeSizeArtifact> files = <CodeSizeArtifact>[];

  _FolderTreeNode({required this.name, required this.path});

  /// Returns the sum of LOC for files directly inside this folder node.
  int get directFileSize =>
      files.fold<int>(0, (sum, file) => sum + file.linesOfCode);

  /// Returns recursive LOC for this folder including descendants.
  int get totalSize =>
      directFileSize +
      children.values.fold<int>(0, (sum, child) => sum + child.totalSize);

  /// Indicates whether this folder contains files or child folders.
  bool get hasEntries => files.isNotEmpty || children.isNotEmpty;
}

class _FolderEntry {
  final String id;
  final String label;
  final String path;
  final int size;
  final _FolderTreeNode? folder;

  const _FolderEntry.folder({
    required this.id,
    required this.label,
    required this.path,
    required this.size,
    required this.folder,
  });

  const _FolderEntry.file({
    required this.id,
    required this.label,
    required this.path,
    required this.size,
  }) : folder = null;

  /// Whether this entry represents a folder rather than a file.
  bool get isFolder => folder != null;
}
