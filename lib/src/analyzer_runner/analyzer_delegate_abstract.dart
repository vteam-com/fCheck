import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';

/// Interface for analyzers that work with unified file context.
abstract class AnalyzerDelegate {
  /// Analyzes a single file using the pre-parsed context.
  /// Returns analyzer-specific issues or results.
  dynamic analyzeFileWithContext(AnalysisFileContext context);
}
