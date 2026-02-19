/// Thresholds for marking code-size artifacts as oversized.
class CodeSizeThresholds {
  /// Default maximum LOC for file artifacts.
  static const int defaultMaxFileLoc = 900;

  /// Default maximum LOC for class artifacts.
  static const int defaultMaxClassLoc = 800;

  /// Default maximum LOC for function artifacts.
  static const int defaultMaxFunctionLoc = 700;

  /// Default maximum LOC for method artifacts.
  static const int defaultMaxMethodLoc = 500;

  /// Maximum LOC for file artifacts.
  final int maxFileLoc;

  /// Maximum LOC for class artifacts.
  final int maxClassLoc;

  /// Maximum LOC for function artifacts.
  final int maxFunctionLoc;

  /// Maximum LOC for method artifacts.
  final int maxMethodLoc;

  /// Creates code-size thresholds.
  const CodeSizeThresholds({
    this.maxFileLoc = defaultMaxFileLoc,
    this.maxClassLoc = defaultMaxClassLoc,
    this.maxFunctionLoc = defaultMaxFunctionLoc,
    this.maxMethodLoc = defaultMaxMethodLoc,
  });

  /// Converts thresholds to JSON.
  Map<String, dynamic> toJson() => {
    'maxFileLoc': maxFileLoc,
    'maxClassLoc': maxClassLoc,
    'maxFunctionLoc': maxFunctionLoc,
    'maxMethodLoc': maxMethodLoc,
  };
}
