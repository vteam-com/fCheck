// ignore: fcheck_one_class_per_file

/// Normalized code snippet used for duplicate-code matching.
class DuplicateCodeSnippet {
  /// Path of the source file.
  final String filePath;

  /// 1-based line number where snippet starts.
  final int lineNumber;

  /// Symbol name owning this snippet.
  final String symbol;

  /// Symbol kind (`function`, `method`, or `constructor`).
  final String kind;

  /// Canonical parameter signature used to gate duplicate comparisons.
  final String parameterSignature;

  /// Non-empty body line count for this snippet.
  final int nonEmptyLineCount;

  /// Normalized token stream used for similarity matching.
  final List<String> normalizedTokens;

  /// Creates a snippet descriptor.
  const DuplicateCodeSnippet({
    required this.filePath,
    required this.lineNumber,
    required this.symbol,
    required this.kind,
    required this.parameterSignature,
    required this.nonEmptyLineCount,
    required this.normalizedTokens,
  });

  /// Number of normalized tokens in this snippet.
  int get tokenCount => normalizedTokens.length;
}

/// Per-file data collected for duplicate-code analysis.
class DuplicateCodeFileData {
  /// File path this data belongs to.
  final String filePath;

  /// Normalized snippets extracted from the file.
  final List<DuplicateCodeSnippet> snippets;

  /// Creates per-file duplicate-code data.
  const DuplicateCodeFileData({
    required this.filePath,
    required this.snippets,
  });
}
