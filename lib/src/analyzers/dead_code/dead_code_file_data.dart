import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_symbol.dart';

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

  /// Method declarations in classes/mixins/enums/extensions.
  final List<DeadCodeSymbol> methods;

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
    required this.methods,
    required this.usedIdentifiers,
    required this.unusedVariableIssues,
  });
}
