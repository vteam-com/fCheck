part of 'export_svg_folders.dart';

/// Represents a folder in the hierarchy.
class FolderNode {
  /// Folder display name.
  final String name;

  /// Full path of the folder relative to the analyzed root.
  final String fullPath;

  /// Child folders.
  final List<FolderNode> children;

  /// Files contained directly in this folder.
  final List<String> files;

  /// Number of incoming folder-level dependencies.
  int incoming = 0;

  /// Number of outgoing folder-level dependencies.
  int outgoing = 0;

  /// Whether this is a virtual folder for loose files.
  final bool isVirtual;

  /// Creates a folder node.
  FolderNode(
    this.name,
    this.fullPath,
    this.children,
    this.files, {
    this.isVirtual = false,
  });
}

/// Captures file label rendering data so we can draw after edges.
class _FileVisual {
  final String path;
  final String name;
  final double textX;
  final double textY;
  final double badgeX;
  final double badgeY;
  final double panelX;
  final double panelWidth;
  final int incoming;
  final int outgoing;
  final List<String> incomingPeers;
  final List<String> outgoingPeers;
  final String? severityClassSuffix;
  final String tooltipTitle;

  _FileVisual({
    required this.path,
    required this.name,
    required this.textX,
    required this.textY,
    required this.badgeX,
    required this.badgeY,
    required this.panelX,
    required this.panelWidth,
    required this.incoming,
    required this.outgoing,
    required this.incomingPeers,
    required this.outgoingPeers,
    required this.severityClassSuffix,
    required this.tooltipTitle,
  });
}

/// Captures folder title info to render above edges.
class _TitleVisual {
  final double x;
  final double y;
  final String text;
  final double maxWidth;
  _TitleVisual(this.x, this.y, this.text, this.maxWidth);
}

const double _titleLineHeight = 16.0;
const double _edgeLaneStepWidth = stackedEdgeLaneStepWidth;
const double _fileLaneBaseOffset = -14.0;
const double _folderLaneBaseOffset = 0.0;
const double _folderGraphEdgeLanePadding = 0.0;
const double _folderGraphEdgeLaneBaseWidth = 0.0;
const double _folderGraphBaseFolderWidth = 260.0;
const double _folderGraphFolderPadding = 24.0;
const double _folderGraphChildIndent = 40.0;
const double _folderGraphChildSpacing = 24.0;
const double _folderGraphMargin = 80.0;
const double _folderGraphHeaderHeight = 32.0;
const double _folderGraphFileItemHeight = 22.0;
const double _folderGraphFileItemSpacing = 10.0;
const double _folderGraphFileTopPadding = 20.0;
const double _folderGraphFilesToChildrenSpacing = 16.0;
const double _folderGraphCharToPixelFactor = 6.0;
const double _folderGraphLabelPadding = 12.0;

/// Represents a folder-to-folder dependency edge.
class _FolderEdge {
  final String sourceFolder;
  final String targetFolder;
  _FolderEdge(this.sourceFolder, this.targetFolder);
}

/// Represents a file-to-file dependency edge.
class _FileEdge {
  final String sourceFile;
  final String targetFile;
  _FileEdge(this.sourceFile, this.targetFile);
}

class _FolderGraphLayoutContext {
  final String commonRoot;
  final Map<String, List<String>> relativeGraph;
  final Map<String, String> originalPathByRelative;
  final Set<String> knownRelativeFiles;
  final FolderNode rootNode;
  final List<_FolderEdge> folderDependencies;
  final Map<String, Map<String, int>> folderMetrics;
  final Map<String, Map<String, int>> fileMetrics;
  final Map<String, int> folderLevels;
  final Map<String, Point<double>> folderPositions;
  final Map<String, Rect> folderDimensions;
  final List<FolderNode> drawOrder;
  final Map<String, int> depthMap;
  final double totalWidth;
  final double totalHeight;
  final double leftLaneGutterX;
  final double rightLaneGutterX;

  const _FolderGraphLayoutContext({
    required this.commonRoot,
    required this.relativeGraph,
    required this.originalPathByRelative,
    required this.knownRelativeFiles,
    required this.rootNode,
    required this.folderDependencies,
    required this.folderMetrics,
    required this.fileMetrics,
    required this.folderLevels,
    required this.folderPositions,
    required this.folderDimensions,
    required this.drawOrder,
    required this.depthMap,
    required this.totalWidth,
    required this.totalHeight,
    required this.leftLaneGutterX,
    required this.rightLaneGutterX,
  });
}
