import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:fcheck/src/analyzers/sorted/sort_utils.dart';
import 'package:fcheck/src/models/class_visitor.dart';

const int _minimumImportsToSort = 2;
const int _importGroupDart = 0;
const int _importGroupPackage = 1;
const int _importGroupOtherAbsolute = 2;
const int _importGroupRelative = 3;

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

    if (isGeneratedDartFilePath(context.file.path) ||
        context.hasParseErrors ||
        context.compilationUnit == null) {
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

      if (fix) {
        _sortImportsInFile(context.file.path);
      }
    } catch (_) {
      // Skip files that can't be analyzed.
    }

    return issues;
  }

  /// Reorders file import directives to match analyzer directive ordering.
  ///
  /// Imports are grouped by URI kind (`dart:`, `package:`, other absolute,
  /// relative) and sorted alphabetically inside each group.
  void _sortImportsInFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return;
    }

    final originalContent = file.readAsStringSync();
    final parseResult = parseString(
      content: originalContent,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parseResult.errors.isNotEmpty) {
      return;
    }

    final imports = parseResult.unit.directives.whereType<ImportDirective>();
    final originalImports = imports.toList(growable: false);
    if (originalImports.length < _minimumImportsToSort) {
      return;
    }

    final sortedImports = [...originalImports]
      ..sort((a, b) {
        final uriA = a.uri.stringValue ?? '';
        final uriB = b.uri.stringValue ?? '';
        final groupComparison = _importGroupPriority(
          uriA,
        ).compareTo(_importGroupPriority(uriB));
        if (groupComparison != 0) {
          return groupComparison;
        }
        return _compareDirectiveUris(uriA, uriB);
      });

    var changed = false;
    for (var i = 0; i < originalImports.length; i++) {
      if (originalImports[i] != sortedImports[i]) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }

    final sortedImportText = _buildImportSection(sortedImports);
    final start = originalImports.first.offset;
    final end = originalImports.last.end;
    final updatedContent =
        originalContent.substring(0, start) +
        sortedImportText +
        originalContent.substring(end);
    file.writeAsStringSync(updatedContent);
  }

  /// Builds the replacement import section text with blank lines between groups.
  String _buildImportSection(List<ImportDirective> sortedImports) {
    final buffer = StringBuffer();
    int? previousGroup;

    for (final directive in sortedImports) {
      final uri = directive.uri.stringValue ?? '';
      final group = _importGroupPriority(uri);
      if (previousGroup != null && group != previousGroup) {
        buffer.writeln();
      }
      buffer.writeln(directive.toSource());
      previousGroup = group;
    }

    return buffer.toString().trimRight();
  }

  /// Returns the import group priority used for analyzer-style ordering.
  int _importGroupPriority(String uri) {
    if (uri.startsWith('dart:')) {
      return _importGroupDart;
    }
    if (uri.startsWith('package:')) {
      return _importGroupPackage;
    }
    if (uri.contains(':')) {
      return _importGroupOtherAbsolute;
    }
    return _importGroupRelative;
  }

  /// Compares import URIs using the same package/path ordering used by linter.
  int _compareDirectiveUris(String a, String b) {
    final indexA = a.indexOf('/');
    final indexB = b.indexOf('/');
    if (indexA == -1 || indexB == -1) {
      return a.compareTo(b);
    }
    final packageComparison = a
        .substring(0, indexA)
        .compareTo(b.substring(0, indexB));
    if (packageComparison != 0) {
      return packageComparison;
    }
    return a.substring(indexA + 1).compareTo(b.substring(indexB + 1));
  }
}
