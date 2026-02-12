import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for per-file documentation checks.
class DocumentationDelegate implements AnalyzerDelegate {
  @override
  List<DocumentationIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final filePath = context.file.path;
    if (_shouldSkipFile(filePath) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForDocumentation,
        ) ||
        context.hasParseErrors ||
        context.compilationUnit == null) {
      return [];
    }

    final visitor = DocumentationVisitor(
      filePath: filePath,
      content: context.content,
      lines: context.lines,
      lineNumberForOffset: context.getLineNumber,
    );
    context.compilationUnit!.accept(visitor);
    return visitor.issues;
  }

  bool _shouldSkipFile(String path) {
    return path.contains('lib/l10n/') || path.contains('.g.dart');
  }
}
