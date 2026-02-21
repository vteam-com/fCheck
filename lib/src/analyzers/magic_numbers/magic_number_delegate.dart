import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_visitor.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for magic number analysis.
class MagicNumberDelegate implements AnalyzerDelegate {
  /// Analyzes a file for magic numbers using the unified context.
  ///
  /// This method uses the pre-parsed AST to identify numeric literals that
  /// should be replaced with named constants.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [MagicNumberIssue] objects representing
  /// magic number issues found in the file.
  @override
  List<MagicNumberIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final filePath = context.file.path;

    if (_shouldSkipFile(filePath) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForMagicNumbers,
        )) {
      return [];
    }

    if (context.hasParseErrors || context.compilationUnit == null) {
      return [];
    }

    final visitor = MagicNumberVisitor(filePath, context.content);
    context.compilationUnit!.accept(visitor);

    return visitor.foundIssues;
  }

  /// Checks if a file should be skipped during magic number analysis.
  ///
  /// Skips localization files and generated files that typically contain
  /// numeric values that are not magic numbers.
  ///
  /// [path] The file path to check.
  ///
  /// Returns true if the file should be skipped.
  bool _shouldSkipFile(String path) {
    return isLibL10nPath(path) || isGeneratedDartFilePath(path);
  }
}
