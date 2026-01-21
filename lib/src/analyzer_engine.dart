import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'hardcoded_strings/hardcoded_string_analyzer.dart';
import 'sort/sort.dart';
import 'metrics/project_metrics.dart';
import 'utils.dart';

/// The main engine for analyzing Flutter/Dart project quality.
///
/// This class provides comprehensive analysis of Dart projects, examining
/// code metrics, comment ratios, and compliance with coding standards.
/// It uses the Dart analyzer to parse source code and extract meaningful
/// quality metrics.
class AnalyzerEngine {
  /// The root directory of the project to analyze.
  final Directory projectDir;

  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// Creates a new analyzer engine for the specified project directory.
  ///
  /// [projectDir] should point to the root of a Flutter/Dart project.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  AnalyzerEngine(this.projectDir, {this.fix = false});

  /// Analyzes the entire project and returns comprehensive quality metrics.
  ///
  /// This method:
  /// - Finds all Dart files in the project
  /// - Analyzes each file individually
  /// - Aggregates metrics across all files
  /// - Returns a [ProjectMetrics] object with the complete analysis
  ///
  /// Returns a [ProjectMetrics] instance containing aggregated quality metrics
  /// for the entire project.
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

    // Analyze for hardcoded strings
    final hardcodedStringAnalyzer = HardcodedStringAnalyzer();
    final hardcodedStringIssues =
        hardcodedStringAnalyzer.analyzeDirectory(projectDir);

    // Analyze for source sorting issues
    final sourceSortAnalyzer = SourceSortAnalyzer();
    final sourceSortIssues =
        sourceSortAnalyzer.analyzeDirectory(projectDir, fix: fix);

    return ProjectMetrics(
      totalFolders: FileUtils.countFolders(projectDir),
      totalFiles: FileUtils.countAllFiles(projectDir),
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: totalLoc,
      totalCommentLines: totalComments,
      fileMetrics: fileMetricsList,
      hardcodedStringIssues: hardcodedStringIssues,
      sourceSortIssues: sourceSortIssues,
    );
  }

  /// Analyzes a single Dart file and returns its quality metrics.
  ///
  /// This method parses the file using the Dart analyzer and extracts:
  /// - Lines of code count
  /// - Comment lines count
  /// - Number of classes declared
  /// - Whether it contains StatefulWidget classes
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a [FileMetrics] instance with the analysis results for this file.
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

  /// Counts the number of comment lines in a Dart file.
  ///
  /// This is a simplified implementation that counts lines containing
  /// comment markers (//, /*, */). For more accurate comment counting,
  /// the analyzer's token stream could be used.
  ///
  /// [unit] The parsed compilation unit (currently unused in this implementation).
  /// [lines] The raw lines of the file.
  ///
  /// Returns the number of lines that contain comments.
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

/// A visitor that traverses the AST to collect quality metrics.
///
/// This internal visitor class extends the analyzer's AST visitor to
/// count class declarations and detect StatefulWidget usage in Dart files.
/// It accumulates metrics during the AST traversal process.
class _QualityVisitor extends RecursiveAstVisitor<void> {
  /// The total number of class declarations found in the visited file.
  int classCount = 0;

  /// Whether any of the classes in the file extend StatefulWidget.
  ///
  /// This affects the "one class per file" rule compliance, as StatefulWidget
  /// files are allowed to have up to 2 classes (widget + state).
  bool hasStatefulWidget = false;

  /// Visits a class declaration node in the AST.
  ///
  /// This method is called for each class declaration encountered during
  /// AST traversal. It increments the class count and checks if the class
  /// extends StatefulWidget.
  ///
  /// [node] The class declaration node being visited.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.toString();

    // Only count public classes for the "one class per file" rule
    // Private classes (starting with _) are implementation details
    if (!className.startsWith('_')) {
      classCount++;
    }

    final superclass = node.extendsClause?.superclass.toString();
    if (superclass == 'StatefulWidget') {
      hasStatefulWidget = true;
    }

    super.visitClassDeclaration(node);
  }
}
