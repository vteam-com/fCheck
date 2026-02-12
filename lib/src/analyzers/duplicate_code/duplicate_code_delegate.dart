import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_file_data.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for duplicate code analysis.
class DuplicateCodeDelegate implements AnalyzerDelegate {
  /// Default minimum normalized tokens required for duplicate snippets.
  static const int defaultMinTokenCount = 20;

  /// Default minimum non-empty lines required for duplicate snippets.
  static const int defaultMinNonEmptyLineCount = 10;

  /// Creates a duplicate-code delegate.
  DuplicateCodeDelegate({
    this.minTokenCount = defaultMinTokenCount,
    this.minNonEmptyLineCount = defaultMinNonEmptyLineCount,
  });

  /// Minimum normalized tokens required for snippet comparison.
  final int minTokenCount;

  /// Minimum non-empty lines required for snippet comparison.
  final int minNonEmptyLineCount;

  /// Collects duplicate-code snippets for a single file.
  @override
  DuplicateCodeFileData? analyzeFileWithContext(AnalysisFileContext context) {
    final filePath = context.file.path;
    if (_shouldSkipFile(filePath) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForDuplicateCode,
        ) ||
        context.hasParseErrors ||
        context.compilationUnit == null) {
      return null;
    }

    final visitor = DuplicateCodeVisitor(
      filePath: filePath,
      lineNumberForOffset: context.getLineNumber,
      lines: context.lines,
      minTokenCount: minTokenCount,
      minNonEmptyLineCount: minNonEmptyLineCount,
    );

    context.compilationUnit!.accept(visitor);
    if (visitor.snippets.isEmpty) {
      return null;
    }

    return DuplicateCodeFileData(
      filePath: filePath,
      snippets: visitor.snippets,
    );
  }

  bool _shouldSkipFile(String path) {
    return path.contains('lib/l10n/') || path.contains('.g.dart');
  }
}
