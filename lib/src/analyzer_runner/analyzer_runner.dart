import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner_result.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';

/// Unified analyzer that performs single traversal and delegates to multiple analyzers.
class AnalyzerRunner {
  /// The root directory to analyze.
  final Directory projectDir;

  /// Glob patterns to exclude from analysis.
  final List<String> excludePatterns;

  /// List of analyzer delegates to run on each file.
  final List<AnalyzerDelegate> delegates;

  /// Whether to enable file context caching.
  final bool enableCaching;

  /// Cache for file contexts to avoid re-parsing in same analysis session.
  final Map<String, AnalysisFileContext> _contextCache = {};

  /// Creates a new unified file analyzer.
  AnalyzerRunner({
    required this.projectDir,
    this.excludePatterns = const [],
    this.delegates = const [],
    this.enableCaching = true,
  });

  /// Performs unified analysis of all files with single traversal.
  AnalysisRunnerResult analyzeAll() {
    // Single file discovery
    final dartFiles = FileUtils.listDartFiles(
      projectDir,
      excludePatterns: excludePatterns,
    );

    final Map<Type, List<dynamic>> allResults = {};
    final Map<Type, int> analyzerStats = {};

    // Process each file once, delegating to all analyzers
    for (final file in dartFiles) {
      final context = _getOrCreateContext(file);

      // Run all delegates on this file
      for (final delegate in delegates) {
        final result = delegate.analyzeFileWithContext(context);
        if (result != null) {
          final resultType = result.runtimeType;

          // Special handling for List types
          if (result is List) {
            if (result.isNotEmpty) {
              final listType = List<dynamic>;
              allResults.putIfAbsent(listType, () => <dynamic>[]);
              allResults[listType]!.addAll(result);

              analyzerStats.putIfAbsent(listType, () => 0);
              analyzerStats[listType] =
                  analyzerStats[listType]! + result.length;
            }
          } else {
            allResults.putIfAbsent(resultType, () => <dynamic>[]);
            allResults[resultType]!.add(result);

            analyzerStats.putIfAbsent(resultType, () => 0);
            analyzerStats[resultType] = analyzerStats[resultType]! + 1;
          }
        }
      }
    }

    return AnalysisRunnerResult(
      totalFiles: dartFiles.length,
      resultsByType: allResults,
      analyzerStats: analyzerStats,
    );
  }

  /// Gets or creates file analysis context with caching.
  AnalysisFileContext _getOrCreateContext(File file) {
    if (enableCaching && _contextCache.containsKey(file.path)) {
      return _contextCache[file.path]!;
    }

    final content = file.readAsStringSync();
    final lines = content.split('\n');

    final parseResult = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final context = AnalysisFileContext(
      file: file,
      content: content,
      parseResult: parseResult,
      lines: lines,
      compilationUnit: parseResult.unit,
      hasParseErrors: parseResult.errors.isNotEmpty,
    );

    if (enableCaching) {
      _contextCache[file.path] = context;
    }

    return context;
  }

  /// Clears the internal context cache.
  void clearCache() {
    _contextCache.clear();
  }
}
