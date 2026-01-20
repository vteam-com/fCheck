import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'models.dart';
import 'utils.dart';

class AnalyzerEngine {
  final Directory projectDir;

  AnalyzerEngine(this.projectDir);

  ProjectMetrics analyze() {
    final dartFiles = FileUtils.listDartFiles(projectDir);
    final fileMetricsList = <FileMetrics>[];

    int totalLoc = 0;
    int totalComments = 0;

    for (var file in dartFiles) {
      final metrics = analyzeFile(file);
      fileMetricsList.add(metrics);
      totalLoc += metrics.linesOfCode;
      totalComments += metrics.commentLines;
    }

    return ProjectMetrics(
      totalFolders: FileUtils.countFolders(projectDir),
      totalFiles: FileUtils.countAllFiles(projectDir),
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: totalLoc,
      totalCommentLines: totalComments,
      fileMetrics: fileMetricsList,
    );
  }

  FileMetrics analyzeFile(File file) {
    final content = file.readAsStringSync();
    final result = parseString(content: content);
    final unit = result.unit;

    final visitor = _QualityVisitor();
    unit.accept(visitor);

    // Count lines of code and comments
    final lines = content.split('\n');
    int loc = lines.length;
    int commentLines = _countCommentLines(unit, lines);

    return FileMetrics(
      path: file.path,
      linesOfCode: loc,
      commentLines: commentLines,
      classCount: visitor.classCount,
      isStatefulWidget: visitor.hasStatefulWidget,
    );
  }

  int _countCommentLines(CompilationUnit unit, List<String> lines) {
    // This is a simplified comment counter.
    // The analyzer's beginToken/endToken are useful for more complex scenarios.
    // We'll count lines that contain comments.
    int count = 0;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('/*') ||
          trimmed.endsWith('*/')) {
        count++;
      } else if (trimmed.contains('//') || trimmed.contains('/*')) {
        // Part of the line is a comment
        count++;
      }
    }
    return count;
  }
}

class _QualityVisitor extends RecursiveAstVisitor<void> {
  int classCount = 0;
  bool hasStatefulWidget = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    classCount++;

    final superclass = node.extendsClause?.superclass.name2.lexeme;
    if (superclass == 'StatefulWidget') {
      hasStatefulWidget = true;
    }

    super.visitClassDeclaration(node);
  }
}
