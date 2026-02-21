import 'dart:io';

import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_file_data.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for dead code analysis.
class DeadCodeDelegate implements AnalyzerDelegate {
  /// The project root directory (containing pubspec.yaml).
  final Directory projectRoot;

  /// Package name from pubspec.yaml.
  final String packageName;

  /// Creates a new dead code delegate.
  DeadCodeDelegate({required this.projectRoot, required this.packageName});

  /// Collects dead code metadata for a single file.
  ///
  /// Returns [DeadCodeFileData] or null if the file should be skipped.
  @override
  DeadCodeFileData? analyzeFileWithContext(AnalysisFileContext context) {
    if (context.hasParseErrors || context.compilationUnit == null) {
      return null;
    }
    final ignoredForDeadCode = context.hasIgnoreForFileDirective(
      IgnoreConfig.ignoreDirectiveForDeadCode,
    );
    final suppressDeclarationsAndIssues =
        ignoredForDeadCode || isGeneratedDartFilePath(context.file.path);

    final visitor = DeadCodeVisitor(
      filePath: context.file.path,
      rootPath: projectRoot.path,
      packageName: packageName,
      content: context.content,
      lineNumberForOffset: context.getLineNumber,
    );

    context.compilationUnit!.accept(visitor);

    return DeadCodeFileData(
      filePath: context.file.path,
      hasMain: visitor.hasMain,
      dependencies: visitor.dependencies,
      classes: suppressDeclarationsAndIssues ? const [] : visitor.classes,
      functions: suppressDeclarationsAndIssues ? const [] : visitor.functions,
      methods: suppressDeclarationsAndIssues ? const [] : visitor.methods,
      usedIdentifiers: visitor.usedIdentifiers,
      unusedVariableIssues: suppressDeclarationsAndIssues
          ? const []
          : visitor.unusedVariableIssues,
    );
  }
}
