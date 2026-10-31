import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for hardcoded string analysis.
class HardcodedStringDelegate implements AnalyzerDelegate {
  /// Creates a delegate for hardcoded string analysis.
  ///
  /// [focus] controls which string literals are considered (Flutter widgets,
  /// Dart print output, or general).
  /// [usesLocalization] whether the project uses localization.
  HardcodedStringDelegate({
    this.focus = HardcodedStringFocus.general,
    this.usesLocalization = false,
  });

  /// Focus mode used by the hardcoded string visitor.
  final HardcodedStringFocus focus;

  /// Whether the project uses localization.
  final bool usesLocalization;

  /// Analyzes a file for hardcoded strings using the unified context.
  ///
  /// This method uses the pre-parsed AST to identify string literals that may
  /// be user-facing content that should be localized.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [HardcodedStringIssue] objects representing
  /// potential hardcoded strings found in the file.
  @override
  List<HardcodedStringIssue> analyzeFileWithContext(
    AnalysisFileContext context,
  ) {
    final filePath = context.file.path;

    // Skip l10n generated files and files with ignore directive
    if (isLibL10nPath(filePath) ||
        isGeneratedDartFilePath(filePath) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForHardcodedStrings,
        ) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreForFileDirectiveForHardcodedStrings,
        )) {
      return [];
    }

    if (context.compilationUnit == null) {
      return [];
    }

    final visitor = HardcodedStringVisitor(
      filePath,
      context.content,
      focus: focus,
      usesLocalization: usesLocalization,
    );
    context.compilationUnit!.accept(visitor);
    return visitor.foundIssues;
  }
}
