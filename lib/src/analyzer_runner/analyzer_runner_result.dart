import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';

/// Results container for unified analysis.
class AnalysisRunnerResult {
  /// Total number of files analyzed.
  final int totalFiles;

  /// Results grouped by analyzer type.
  final Map<Type, List<dynamic>> resultsByType;

  /// Statistics for each analyzer type.
  final Map<Type, int> analyzerStats;

  /// Shared analysis contexts keyed by normalized file path.
  final Map<String, AnalysisFileContext> contextsByPath;

  /// Creates a new unified analysis result.
  AnalysisRunnerResult({
    required this.totalFiles,
    required this.resultsByType,
    required this.analyzerStats,
    required this.contextsByPath,
  });

  /// Gets results of specific type.
  T? getResults<T>() {
    final typeResults = resultsByType[T];
    if (typeResults == null) return null;

    // For List types, we need to cast each element
    return typeResults as T;
  }
}
