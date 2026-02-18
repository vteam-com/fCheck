import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
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

  static const int _maxShortWidgetStringLength = 2;

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
    if (filePath.contains('lib/l10n/') ||
        filePath.contains('.g.dart') ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForHardcodedStrings,
        ) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreForFileDirectiveForHardcodedStrings,
        )) {
      return [];
    }

    final issues = <HardcodedStringIssue>[];

    if (focus == HardcodedStringFocus.flutterWidgets) {
      issues.addAll(_scanWidgetTextLiterals(context));
    }

    if (context.compilationUnit == null) {
      return issues;
    }

    final visitor = HardcodedStringVisitor(
      filePath,
      context.content,
      focus: focus,
      usesLocalization: usesLocalization,
    );
    context.compilationUnit!.accept(visitor);

    if (issues.isEmpty) {
      return visitor.foundIssues;
    }

    final seen = <String>{
      for (final issue in issues) '${issue.lineNumber}:${issue.value}',
    };
    for (final issue in visitor.foundIssues) {
      final key = '${issue.lineNumber}:${issue.value}';
      if (seen.add(key)) {
        issues.add(issue);
      }
    }

    return issues;
  }

  /// Scans fallback widget text literals when AST-based detection finds none.
  List<HardcodedStringIssue> _scanWidgetTextLiterals(
    AnalysisFileContext context,
  ) {
    final issues = <HardcodedStringIssue>[];
    final regex = RegExp(r'''\bText\s*\(\s*(['"])(.*?)\1''', dotAll: true);

    for (final match in regex.allMatches(context.content)) {
      final value = match.group(HardcodedStringUtils.minQuotedLength) ?? '';
      if (value.isEmpty || value.length <= _maxShortWidgetStringLength) {
        continue;
      }

      if (_isInterpolationOnlyString(value)) {
        continue;
      }

      if (_isTechnicalString(value)) {
        continue;
      }

      final matchText = match.group(0) ?? '';
      final valueOffsetInMatch = matchText.indexOf(value);
      final literalOffset =
          match.start + (valueOffsetInMatch < 0 ? 0 : valueOffsetInMatch);
      final lineNumber = context.getLineNumber(literalOffset);
      if (lineNumber <= 0 || lineNumber > context.lines.length) {
        continue;
      }

      final line = context.lines[lineNumber - 1];
      if (line.trimLeft().startsWith('//')) {
        continue;
      }

      if (_hasWidgetLintIgnoreComment(line) ||
          line.contains(IgnoreConfig.ignoreDirectiveForHardcodedStrings)) {
        continue;
      }

      if (lineNumber > 1) {
        final previousLine =
            context.lines[lineNumber - HardcodedStringUtils.minQuotedLength];
        if (_hasWidgetLintIgnoreComment(previousLine)) {
          continue;
        }
      }

      issues.add(
        HardcodedStringIssue(
          filePath: context.file.path,
          lineNumber: lineNumber,
          value: value,
        ),
      );
    }

    return issues;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasWidgetLintIgnoreComment(String line) {
    final ignorePatterns = [
      RegExp(r'//\s*ignore:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore_for_file:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore:\s*hardcoded.string', caseSensitive: false),
      RegExp(r'//\s*hardcoded.ok', caseSensitive: false),
    ];

    return ignorePatterns.any((pattern) => pattern.hasMatch(line));
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isInterpolationOnlyString(String value) {
    final String withoutInterpolations =
        HardcodedStringUtils.removeInterpolations(value);
    return !HardcodedStringUtils.containsMeaningfulText(withoutInterpolations);
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isTechnicalString(String value) {
    return HardcodedStringUtils.isTechnicalString(value);
  }
}
