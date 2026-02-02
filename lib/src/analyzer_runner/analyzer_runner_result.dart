/// Results container for unified analysis.
class AnalysisRunnerResult {
  /// Total number of files analyzed.
  final int totalFiles;

  /// Results grouped by analyzer type.
  final Map<Type, List<dynamic>> resultsByType;

  /// Statistics for each analyzer type.
  final Map<Type, int> analyzerStats;

  /// Creates a new unified analysis result.
  AnalysisRunnerResult({
    required this.totalFiles,
    required this.resultsByType,
    required this.analyzerStats,
  });

  /// Gets results of specific type.
  T? getResults<T>() {
    final typeResults = resultsByType[T];
    if (typeResults == null) return null;

    // For List types, we need to cast each element
    return typeResults as T;
  }

  /// Gets count of results for specific analyzer type.
  int getResultCount<T>() {
    return analyzerStats[T] ?? 0;
  }
}
