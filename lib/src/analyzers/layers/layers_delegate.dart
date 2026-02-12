import 'dart:io';

import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/layers/layers_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Delegate adapter for layers analysis.
class LayersDelegate implements AnalyzerDelegate {
  /// The root directory of the project.
  final Directory rootDirectory;

  /// The package name for dependency resolution.
  final String packageName;

  /// Creates a new LayersDelegate.
  ///
  /// [rootDirectory] The project root directory.
  /// [packageName] The package name from pubspec.yaml.
  LayersDelegate(this.rootDirectory, this.packageName);

  /// Analyzes a file for layers dependencies using the unified context.
  ///
  /// This method extracts import/export dependencies and entry point status
  /// for layers architecture analysis.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a map containing 'dependencies' (list of file paths) and
  /// 'isEntryPoint' (boolean indicating if file has main() function).
  @override
  Map<String, dynamic> analyzeFileWithContext(AnalysisFileContext context) {
    if (context.hasIgnoreForFileDirective(
      IgnoreConfig.ignoreDirectiveForLayers,
    )) {
      return {
        'filePath': context.file.path,
        'dependencies': <String>[],
        'isEntryPoint': false,
      };
    }

    if (context.hasParseErrors || context.compilationUnit == null) {
      return {
        'filePath': context.file.path,
        'dependencies': <String>[],
        'isEntryPoint': false,
      };
    }

    final visitor = LayersVisitor(
      context.file.path,
      rootDirectory.path,
      packageName,
    );
    context.compilationUnit!.accept(visitor);

    return {
      'filePath': context.file.path,
      'dependencies': visitor.dependencies,
      'isEntryPoint': visitor.hasMainFunction,
    };
  }
}
