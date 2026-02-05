import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import '../../models/class_visitor.dart';
import 'sort_members.dart';
import 'sort_issue.dart';
import 'sort_utils.dart';
import '../../models/file_utils.dart';

/// Analyzes Dart files for proper source code member ordering in Flutter classes
class SourceSortAnalyzer {
  /// Creates a new SourceSortAnalyzer.
  SourceSortAnalyzer();

  /// Analyzes a single file for source sorting issues.
  ///
  /// This method examines Flutter widget classes in the given file and checks
  /// if their members are properly sorted according to Flutter conventions.
  ///
  /// [file] The Dart file to analyze.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to the file.
  ///
  /// Returns a list of [SourceSortIssue] objects representing any sorting
  /// issues found in Flutter classes within the file.
  List<SourceSortIssue> analyzeFile(File file, {bool fix = false}) {
    final List<SourceSortIssue> issues = <SourceSortIssue>[];

    try {
      final String content = file.readAsStringSync();

      final ParseStringResult result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      if (result.errors.isNotEmpty) {
        // Skip files with parse errors
        return issues;
      }

      final CompilationUnit compilationUnit = result.unit;
      final ClassVisitor classVisitor = ClassVisitor();
      compilationUnit.accept(classVisitor);

      for (final ClassDeclaration classNode in classVisitor.targetClasses) {
        // In analyzer AST, class members are accessed directly
        // ignore: deprecated_member_use
        final NodeList<ClassMember> members = classNode.members;
        if (members.isEmpty) {
          continue;
        }

        final MemberSorter sorter = MemberSorter(content, members);
        final String sortedBody = sorter.getSortedBody();

        // Find the body boundaries
        // ignore: deprecated_member_use
        final int classBodyStart = classNode.leftBracket.offset + 1;
        // ignore: deprecated_member_use
        final int classBodyEnd = classNode.rightBracket.offset;
        final String originalBody = content.substring(
          classBodyStart,
          classBodyEnd,
        );

        // Check if the body needs sorting
        if (SortUtils.bodiesDiffer(sortedBody, originalBody)) {
          final int lineNumber = _getLineNumber(content, classNode.offset);
          final className = classNode.namePart.toString();

          if (fix) {
            // Write the sorted content back to the file
            final sortedContent = content.substring(0, classBodyStart) +
                sortedBody +
                content.substring(classBodyEnd);
            file.writeAsStringSync(sortedContent);
            print('✅ Fixed sorting for class $className in ${file.path}');
          } else {
            // Report the issue
            issues.add(
              SourceSortIssue(
                filePath: file.path,
                className: className,
                lineNumber: lineNumber,
                description: 'Class members are not properly sorted',
              ),
            );
          }
        }
      }
    } catch (e) {
      // Skip files that can't be analyzed
    }

    return issues;
  }

  /// Analyzes a directory for source sorting issues.
  ///
  /// This method recursively scans the directory tree and analyzes all
  /// Dart files found, excluding example/, test/, tool/, and build directories.
  /// Only Flutter widget classes are checked for proper member sorting.
  ///
  /// [directory] The root directory to scan for Dart files.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  ///
  /// Returns a list of all [SourceSortIssue] objects found across
  /// all analyzed files in the directory.
  List<SourceSortIssue> analyzeDirectory(
    Directory directory, {
    bool fix = false,
    List<String> excludePatterns = const [],
  }) {
    final List<SourceSortIssue> allIssues = <SourceSortIssue>[];

    final List<File> dartFiles = FileUtils.listDartFiles(
      directory,
      excludePatterns: excludePatterns,
    );
    for (final File file in dartFiles) {
      allIssues.addAll(analyzeFile(file, fix: fix));
    }

    return allIssues;
  }

  /// Get the line number for a given offset in the content
  int _getLineNumber(String content, int offset) {
    int lineNumber = 1;
    for (int i = 0; i < offset && i < content.length; i++) {
      if (content[i] == '\n') {
        lineNumber++;
      }
    }
    return lineNumber;
  }
}
