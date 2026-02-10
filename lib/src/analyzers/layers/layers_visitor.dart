import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/shared/dependency_uri_utils.dart';

/// A visitor that traverses the AST to collect import/export references and entry points.
///
/// This class extends the analyzer's AST visitor to identify import and export
/// directives in Dart source code. It collects all the files that each Dart
/// file depends on through imports and exports, and identifies entry points
/// (files containing main() functions).
class LayersVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a new visitor for the specified file.
  ///
  /// [filePath] should be the path to the file being analyzed.
  /// [rootPath] should be the root directory of the project.
  /// [packageName] should be the name of the package from pubspec.yaml.
  LayersVisitor(this.filePath, this.rootPath, this.packageName);

  /// The file path being analyzed.
  final String filePath;

  /// The root path of the project.
  final String rootPath;

  /// The package name from pubspec.yaml.
  final String packageName;

  /// The list of files that this file imports or exports.
  final List<String> dependencies = <String>[];

  /// Whether this file contains a main() function (entry point).
  bool hasMainFunction = false;

  /// Visits an import directive node in the AST.
  ///
  /// This method is called for each import directive encountered during
  /// AST traversal. It extracts the imported file path and adds it to
  /// the dependencies list.
  ///
  /// [node] The import directive node being visited.
  @override
  void visitImportDirective(ImportDirective node) {
    _addDirectiveDependencies(node.uri.stringValue, node.configurations);
    super.visitImportDirective(node);
  }

  /// Visits an export directive node in the AST.
  ///
  /// This method is called for each export directive encountered during
  /// AST traversal. It extracts the exported file path and adds it to
  /// the dependencies list.
  ///
  /// [node] The export directive node being visited.
  @override
  void visitExportDirective(ExportDirective node) {
    _addDirectiveDependencies(node.uri.stringValue, node.configurations);
    super.visitExportDirective(node);
  }

  /// Visits a function declaration node in the AST.
  ///
  /// This method is called for each function declaration. It checks if
  /// the function is named 'main' to identify entry points.
  ///
  /// [node] The function declaration node being visited.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme == 'main') {
      hasMainFunction = true;
    }
    super.visitFunctionDeclaration(node);
  }

  void _addDirectiveDependencies(
    String? uri,
    List<Configuration> configurations,
  ) {
    _addDependencyIfDart(uri);
    if (configurations.isEmpty) {
      return;
    }
    for (final configuration in configurations) {
      _addDependencyIfDart(configuration.uri.stringValue);
    }
  }

  void _addDependencyIfDart(String? uri) {
    addResolvedProjectDartDependency(
      uri: uri,
      packageName: packageName,
      filePath: filePath,
      rootPath: rootPath,
      dependencies: dependencies,
    );
  }
}
