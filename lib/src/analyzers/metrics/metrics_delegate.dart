import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_file_data.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_visitor.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for project metrics analysis.
class MetricsDelegate implements AnalyzerDelegate {
  /// Whether to globally ignore the "one class per file" rule.
  final bool globallyIgnoreOneClassPerFile;

  /// Creates a new metrics delegate.
  MetricsDelegate({
    this.globallyIgnoreOneClassPerFile = false,
  });

  @override
  MetricsFileData analyzeFileWithContext(AnalysisFileContext context) {
    final hasIgnoreDirective = context.hasIgnoreForFileDirective(
      IgnoreConfig.ignoreDirectiveForOneClassPerFile,
    );
    final ignoreOneClassPerFile =
        hasIgnoreDirective || globallyIgnoreOneClassPerFile;

    // Skip files with parse errors
    if (context.hasParseErrors || context.compilationUnit == null) {
      return MetricsFileData(
        metrics: FileMetrics(
          path: context.file.path,
          linesOfCode: 0,
          commentLines: 0,
          classCount: 0,
          isStatefulWidget: false,
          ignoreOneClassPerFile: ignoreOneClassPerFile,
        ),
        fcheckIgnoreDirectiveCount: IgnoreConfig.countFcheckIgnoreDirectives(
          context.content,
          compilationUnit: context.compilationUnit,
        ),
      );
    }

    final unit = context.compilationUnit!;
    final lines = context.lines;
    final nonEmptyLineCount =
        lines.where((line) => line.trim().isNotEmpty).length;
    final commentLines = _countCommentLines(unit, lines);
    final visitor = MetricsQualityVisitor();
    unit.accept(visitor);

    return MetricsFileData(
      metrics: FileMetrics(
        path: context.file.path,
        linesOfCode: nonEmptyLineCount,
        commentLines: commentLines,
        classCount: visitor.classCount,
        functionCount: visitor.functionCount,
        topLevelFunctionCount: visitor.topLevelFunctionCount,
        methodCount: visitor.methodCount,
        stringLiteralCount: visitor.stringLiteralCount,
        numberLiteralCount: visitor.numberLiteralCount,
        isStatefulWidget: visitor.hasStatefulWidget,
        ignoreOneClassPerFile: ignoreOneClassPerFile,
      ),
      fcheckIgnoreDirectiveCount: IgnoreConfig.countFcheckIgnoreDirectives(
        context.content,
        compilationUnit: unit,
      ),
    );
  }

  /// Counts the number of comment lines in a Dart file.
  int _countCommentLines(CompilationUnit unit, List<String> lines) {
    if (lines.isEmpty) {
      return 0;
    }

    final lineStarts = _buildLineStartOffsets(lines);
    final commentedLines = <int>{};

    var token = unit.beginToken;
    while (true) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        final startLine = _lineForOffset(lineStarts, comment.offset);
        final endLine = _lineForOffset(
          lineStarts,
          comment.end > 0 ? comment.end - 1 : comment.offset,
        );
        for (var line = startLine; line <= endLine; line++) {
          commentedLines.add(line);
        }
        comment = comment.next;
      }

      final nextToken = token.next;
      if (nextToken == null || identical(nextToken, token)) {
        break;
      }
      token = nextToken;
    }

    return commentedLines.length;
  }

  /// Builds zero-based absolute start offsets for each line in [lines].
  List<int> _buildLineStartOffsets(List<String> lines) {
    final starts = List<int>.filled(lines.length, 0);
    var offset = 0;
    for (var i = 0; i < lines.length; i++) {
      starts[i] = offset;
      offset += lines[i].length + 1;
    }
    return starts;
  }

  /// Converts a source [offset] into a 1-based line number using [lineStarts].
  int _lineForOffset(List<int> lineStarts, int offset) {
    if (offset <= 0) {
      return 1;
    }

    var low = 0;
    var high = lineStarts.length - 1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      if (lineStarts[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final lineIndex = high.clamp(0, lineStarts.length - 1);
    return lineIndex + 1;
  }
}
