/// Aggregated static test-consumption counts used by project metrics.
class TestConsumptionSummary {
  /// Relative project paths imported directly by test files.
  final List<String> importedPaths;

  /// Relative project paths considered transitively consumed by tests.
  final List<String> consumedPaths;

  /// Total lines of code across consumed files.
  final int linesOfCode;

  /// Total class count across consumed files.
  final int classCount;

  /// Total method count across consumed files.
  final int methodCount;

  /// Total top-level function count across consumed files.
  final int topLevelFunctionCount;

  /// Creates a test-consumption summary from aggregated project metrics.
  const TestConsumptionSummary({
    required this.importedPaths,
    required this.consumedPaths,
    required this.linesOfCode,
    required this.classCount,
    required this.methodCount,
    required this.topLevelFunctionCount,
  });

  /// Creates an empty summary when no test-driven dependencies are found.
  const TestConsumptionSummary.empty()
    : importedPaths = const <String>[],
      consumedPaths = const <String>[],
      linesOfCode = 0,
      classCount = 0,
      methodCount = 0,
      topLevelFunctionCount = 0;
}
