/// Represents duplicated code detected between two code blocks.
class DuplicateCodeIssue {
  static const int _percentageMultiplier = 100;
  static const int _windowsRootPrefixLength = 3;
  static final RegExp _windowsAbsolutePathPattern = RegExp(r'^[A-Za-z]:/');

  /// Path of the first code block.
  final String firstFilePath;

  /// 1-based line number of the first code block.
  final int firstLineNumber;

  /// Symbol name for the first code block.
  final String firstSymbol;

  /// Path of the second code block.
  final String secondFilePath;

  /// 1-based line number of the second code block.
  final int secondLineNumber;

  /// Symbol name for the second code block.
  final String secondSymbol;

  /// Similarity ratio in the range [0.0, 1.0].
  final double similarity;

  /// Number of compared non-empty lines used for this duplicate pair.
  final int lineCount;

  /// Creates a duplicate code issue.
  DuplicateCodeIssue({
    required this.firstFilePath,
    required this.firstLineNumber,
    required this.firstSymbol,
    required this.secondFilePath,
    required this.secondLineNumber,
    required this.secondSymbol,
    required this.similarity,
    required this.lineCount,
  });

  /// Returns similarity as percentage value.
  double get similarityPercent => similarity * _percentageMultiplier;

  /// Returns similarity percentage rounded down to an integer.
  int get similarityPercentRoundedDown => similarityPercent.floor();

  @override
  String toString() => format();

  /// Returns a formatted issue line for CLI output.
  String format({
    int? similarityPercentWidth,
    int? lineCountWidth,
  }) {
    final (displayFirstPath, displaySecondPath) =
        _stripCommonAbsolutePrefix(firstFilePath, secondFilePath);
    final lineLabel = lineCount == 1 ? 'line' : 'lines';
    final similarityText = similarityPercentWidth == null
        ? '$similarityPercentRoundedDown'
        : similarityPercentRoundedDown.toString().padLeft(
              similarityPercentWidth,
            );
    final lineCountText = lineCountWidth == null
        ? '$lineCount'
        : lineCount.toString().padLeft(lineCountWidth);
    return '$similarityText% ($lineCountText $lineLabel) '
        '$displayFirstPath:$firstLineNumber <-> '
        '$displaySecondPath:$secondLineNumber '
        '($firstSymbol, $secondSymbol)';
  }

  (String firstPath, String secondPath) _stripCommonAbsolutePrefix(
    String firstPath,
    String secondPath,
  ) {
    final normalizedFirst = firstPath.replaceAll('\\', '/');
    final normalizedSecond = secondPath.replaceAll('\\', '/');

    final firstRoot = _rootPrefix(normalizedFirst);
    final secondRoot = _rootPrefix(normalizedSecond);
    if (firstRoot == null || secondRoot == null || firstRoot != secondRoot) {
      return (firstPath, secondPath);
    }

    final firstSegments =
        normalizedFirst.substring(firstRoot.length).split('/');
    final secondSegments =
        normalizedSecond.substring(secondRoot.length).split('/');

    var commonCount = 0;
    final maxCommon = firstSegments.length < secondSegments.length
        ? firstSegments.length
        : secondSegments.length;
    while (commonCount < maxCommon &&
        firstSegments[commonCount] == secondSegments[commonCount]) {
      commonCount++;
    }

    if (commonCount == 0) {
      return (firstPath, secondPath);
    }

    final strippedFirst = firstSegments.sublist(commonCount).join('/');
    final strippedSecond = secondSegments.sublist(commonCount).join('/');

    return (
      strippedFirst.isEmpty ? _fallbackPath(normalizedFirst) : strippedFirst,
      strippedSecond.isEmpty ? _fallbackPath(normalizedSecond) : strippedSecond,
    );
  }

  String? _rootPrefix(String normalizedPath) {
    if (normalizedPath.startsWith('/')) {
      return '/';
    }

    if (normalizedPath.length >= _windowsRootPrefixLength &&
        _windowsAbsolutePathPattern.hasMatch(normalizedPath)) {
      return normalizedPath.substring(0, _windowsRootPrefixLength);
    }

    return null;
  }

  String _fallbackPath(String normalizedPath) {
    final parts = normalizedPath.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        return parts[i];
      }
    }
    return normalizedPath;
  }

  /// Converts this issue to JSON.
  Map<String, dynamic> toJson() => {
        'firstFilePath': firstFilePath,
        'firstLineNumber': firstLineNumber,
        'firstSymbol': firstSymbol,
        'secondFilePath': secondFilePath,
        'secondLineNumber': secondLineNumber,
        'secondSymbol': secondSymbol,
        'similarity': similarity,
        'lineCount': lineCount,
      };
}
