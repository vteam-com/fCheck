import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:fcheck/src/analyzers/sorted/sort_utils.dart';
import 'package:fcheck/src/models/class_visitor.dart';

/// Delegate adapter for source sorting.
class SourceSortDelegate implements AnalyzerDelegate {
  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// Creates a new SourceSortDelegate.
  ///
  /// [fix] if true, automatically fixes sorting issues by writing sorted code
  /// back to files.
  SourceSortDelegate({this.fix = false});

  /// Analyzes a file for source sorting issues using the unified context.
  ///
  /// This method examines Flutter widget classes in the given file context and
  /// checks if their members are properly sorted according to Flutter
  /// conventions.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [SourceSortIssue] objects representing any sorting
  /// issues found in Flutter classes within the file.
  @override
  List<SourceSortIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final issues = <SourceSortIssue>[];

    if (context.hasParseErrors || context.compilationUnit == null) {
      return issues;
    }

    try {
      final classVisitor = ClassVisitor();
      context.compilationUnit!.accept(classVisitor);

      for (final ClassDeclaration classNode in classVisitor.targetClasses) {
        // ignore: deprecated_member_use
        final NodeList<ClassMember> members = classNode.members;
        if (members.isEmpty) {
          continue;
        }

        final sorter = MemberSorter(context.content, members);
        final sortedBody = sorter.getSortedBody();

        // Find the body boundaries.
        // ignore: deprecated_member_use
        final classBodyStart = classNode.leftBracket.offset + 1;
        // ignore: deprecated_member_use
        final classBodyEnd = classNode.rightBracket.offset;
        final originalBody = context.content.substring(
          classBodyStart,
          classBodyEnd,
        );

        // Check if the body needs sorting.
        if (SortUtils.bodiesDiffer(sortedBody, originalBody)) {
          if (fix) {
            // Write the sorted content back to the file.
            final sortedContent =
                context.content.substring(0, classBodyStart) +
                sortedBody +
                context.content.substring(classBodyEnd);
            context.file.writeAsStringSync(sortedContent);
          } else {
            // Report the issue.
            issues.add(
              SourceSortIssue(
                filePath: context.file.path,
                className: classNode.namePart.toString(),
                lineNumber: context.getLineNumber(classNode.offset),
                description: 'Class members are not properly sorted',
              ),
            );
          }
        }
      }
    } catch (_) {
      // Skip files that can't be analyzed.
    }

    return issues;
  }
}
