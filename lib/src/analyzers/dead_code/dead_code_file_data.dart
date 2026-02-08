// ignore: fcheck_one_class_per_file
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';

/// Simple symbol metadata used for dead code analysis.
class DeadCodeSymbol {
  /// Symbol name as declared in source.
  final String name;

  /// 1-based line number of the declaration.
  final int lineNumber;

  /// Creates symbol metadata for dead code analysis.
  const DeadCodeSymbol({
    required this.name,
    required this.lineNumber,
  });
}

/// Per-file data collected for dead code analysis.
class DeadCodeFileData {
  /// The file path for this data.
  final String filePath;

  /// Whether this file contains a main() function.
  final bool hasMain;

  /// Dependencies (imports/exports/parts) resolved to file paths.
  final List<String> dependencies;

  /// Top-level class declarations in the file.
  final List<DeadCodeSymbol> classes;

  /// Top-level function declarations in the file.
  final List<DeadCodeSymbol> functions;

  /// All identifiers used in the file (excluding declarations).
  final Set<String> usedIdentifiers;

  /// Unused local variable issues found in the file.
  final List<DeadCodeIssue> unusedVariableIssues;

  /// Creates a per-file data snapshot for dead code analysis.
  const DeadCodeFileData({
    required this.filePath,
    required this.hasMain,
    required this.dependencies,
    required this.classes,
    required this.functions,
    required this.usedIdentifiers,
    required this.unusedVariableIssues,
  });
}
