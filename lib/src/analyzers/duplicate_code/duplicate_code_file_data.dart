import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_file_snippet.dart';

/// Per-file data collected for duplicate-code analysis.
class DuplicateCodeFileData {
  /// File path this data belongs to.
  final String filePath;

  /// Normalized snippets extracted from the file.
  final List<DuplicateCodeSnippet> snippets;

  /// Creates per-file duplicate-code data.
  const DuplicateCodeFileData({required this.filePath, required this.snippets});
}
