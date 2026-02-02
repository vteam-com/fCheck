// ignore: fcheck_one_class_per_file
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/config/config_ignore_directives.dart';

/// Context containing pre-analyzed file data shared across analyzers.
class AnalysisFileContext {
  /// The file being analyzed.
  final File file;

  /// The raw content of the file.
  final String content;

  /// The parse result from Dart analyzer.
  final ParseStringResult parseResult;

  /// The parsed AST compilation unit.
  final CompilationUnit? compilationUnit;

  /// The file content split into lines.
  final List<String> lines;

  /// Whether the file has parse errors.
  final bool hasParseErrors;

  /// Creates a new file analysis context.
  AnalysisFileContext({
    required this.file,
    required this.content,
    required this.parseResult,
    required this.lines,
    this.compilationUnit,
    required this.hasParseErrors,
  });

  /// Gets line number for a given character offset.
  int getLineNumber(int offset) {
    int lineNumber = 1;
    for (int i = 0; i < offset && i < content.length; i++) {
      if (content[i] == '\n') {
        lineNumber++;
      }
    }
    return lineNumber;
  }

  /// Checks if file has ignore directive for specific analyzer.
  bool hasIgnoreDirective(String analyzerName) {
    return ConfigIgnoreDirectives.hasIgnoreDirective(content, analyzerName);
  }
}

/// Interface for analyzers that work with unified file context.
abstract class AnalyzerDelegate {
  /// Analyzes a single file using the pre-parsed context.
  /// Returns analyzer-specific issues or results.
  dynamic analyzeFileWithContext(AnalysisFileContext context);
}
