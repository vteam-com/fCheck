import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_runner_result.dart';
import 'package:fcheck/src/input_output/file_utils.dart';

/// Unified analyzer that performs single traversal and delegates to multiple analyzers.
class AnalyzerRunner {
  /// The root directory to analyze.
  final Directory projectDir;

  /// Glob patterns to exclude from analysis.
  final List<String> excludePatterns;

  /// List of analyzer delegates to run on each file.
  final List<AnalyzerDelegate> delegates;

  /// Pre-discovered Dart files to analyze.
  final List<File>? dartFiles;

  /// Whether to enable file context caching.
  final bool enableCaching;

  /// Cache for file contexts to avoid re-parsing in same analysis session.
  final Map<String, AnalysisFileContext> _contextCache = {};

  /// Creates a new unified file analyzer.
  AnalyzerRunner({
    required this.projectDir,
    this.excludePatterns = const [],
    this.delegates = const [],
    this.dartFiles,
    this.enableCaching = true,
  });

  /// Performs unified analysis of all files with single traversal.
  AnalysisRunnerResult analyzeAll() {
    final filesToAnalyze =
        dartFiles ??
        FileUtils.listDartFiles(projectDir, excludePatterns: excludePatterns);

    final Map<Type, List<dynamic>> allResults = {};
    final Map<Type, int> analyzerStats = {};
    final contextsByPath = <String, AnalysisFileContext>{};

    // Process each file once, delegating to all analyzers
    for (final file in filesToAnalyze) {
      final context = _getOrCreateContext(file);
      contextsByPath[file.path] = context;

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
      totalFiles: filesToAnalyze.length,
      resultsByType: allResults,
      analyzerStats: analyzerStats,
      contextsByPath: contextsByPath,
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
      throwIfDiagnostics: false,
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
}
