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

class _ArtifactWarningSummary {
  final int warningCount;
  final bool hasDeadArtifact;
  final bool hasHardError;
  final Map<String, int> warningTypeCounts;

  const _ArtifactWarningSummary({
    required this.warningCount,
    required this.hasDeadArtifact,
    required this.hasHardError,
    required this.warningTypeCounts,
  });

  static const empty = _ArtifactWarningSummary(
    warningCount: 0,
    hasDeadArtifact: false,
    hasHardError: false,
    warningTypeCounts: <String, int>{},
  );

  /// Returns `true` when this artifact has any warning or dead-artifact flag.
  bool get hasWarnings => warningCount > 0 || hasDeadArtifact;
}

class _ArtifactWarningIndex {
  final Map<String, _ArtifactWarningSummary> fileWarnings;
  final Map<String, _ArtifactWarningSummary> classWarnings;
  final Map<String, _ArtifactWarningSummary> callableWarnings;

  const _ArtifactWarningIndex({
    required this.fileWarnings,
    required this.classWarnings,
    required this.callableWarnings,
  });

  static const empty = _ArtifactWarningIndex(
    fileWarnings: <String, _ArtifactWarningSummary>{},
    classWarnings: <String, _ArtifactWarningSummary>{},
    callableWarnings: <String, _ArtifactWarningSummary>{},
  );

  /// Returns warning summary for a file path.
  _ArtifactWarningSummary fileForPath(String filePath) =>
      fileWarnings[filePath] ?? _ArtifactWarningSummary.empty;

  /// Returns warning summary for a class by file path and class name.
  _ArtifactWarningSummary classFor(String filePath, String className) =>
      classWarnings['$filePath|$className'] ?? _ArtifactWarningSummary.empty;

  /// Returns warning summary for a callable using its stable identifier.
  _ArtifactWarningSummary callableForStableId(String stableId) =>
      callableWarnings[stableId] ?? _ArtifactWarningSummary.empty;

  /// Iterates all warning summaries across file/class/callable scopes.
  Iterable<_ArtifactWarningSummary> get allSummaries sync* {
    yield* fileWarnings.values;
    yield* classWarnings.values;
    yield* callableWarnings.values;
  }
}
