import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';

/// Per-file code-size analysis output.
class CodeSizeFileData {
  /// Analyzed source file path.
  final String filePath;

  /// Collected class/function/method artifacts from the file.
  final List<CodeSizeArtifact> artifacts;

  /// Creates code-size file analysis data.
  const CodeSizeFileData({
    required this.filePath,
    required this.artifacts,
  });
}
