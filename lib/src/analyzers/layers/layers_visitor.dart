import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:path/path.dart' as p;

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
    final uri = node.uri.stringValue;
    if (uri != null && _isDartFile(uri)) {
      dependencies.add(_resolveDependency(uri, filePath));
    }
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
    final uri = node.uri.stringValue;
    if (uri != null && _isDartFile(uri)) {
      dependencies.add(_resolveDependency(uri, filePath));
    }
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

  /// Checks if a URI string represents a Dart file import/export within the project.
  ///
  /// For layer analysis, considers relative imports and package: imports within the current package.
  /// Ignores external package imports and core library imports.
  ///
  /// [uri] The URI string to check.
  bool _isDartFile(String uri) {
    // Skip dart: imports (core library imports)
    if (uri.startsWith('dart:')) {
      return false;
    }

    // Skip external package: imports (not in current package)
    if (uri.startsWith('package:') &&
        !uri.startsWith('package:$packageName/')) {
      return false;
    }

    // Include package: imports for the current package
    if (uri.startsWith('package:$packageName/')) {
      return uri.endsWith('.dart');
    }

    // Include relative imports ending with .dart
    return uri.endsWith('.dart');
  }

  /// Resolves a dependency URI to an absolute file path.
  ///
  /// For package: imports, resolves to the lib/ directory.
  /// For relative imports, resolves against the current file's directory.
  ///
  /// [uri] The import/export URI (relative path or package: URI).
  /// [currentFile] The path of the file containing the import/export.
  /// The length of the relative current directory prefix ("./").
  static const int _relativeCurrentDirPrefixLength = 2;

  /// The length of the relative parent directory prefix ("../").
  static const int _relativeParentDirPrefixLength = 3;

  /// Resolves a dependency URI to an absolute file path.
  ///
  /// For package: imports, resolves to the lib/ directory.
  /// For relative imports, resolves against the current file's directory.
  ///
  /// [uri] The import/export URI (relative path or package: URI).
  /// [currentFile] The path of the file containing the import/export.
  String _resolveDependency(String uri, String currentFile) {
    if (uri.startsWith('package:$packageName/')) {
      // Package import: resolve to lib/ directory
      final packagePath = uri.substring('package:$packageName/'.length);
      return p.join(rootPath, 'lib', packagePath);
    }

    // For relative imports, resolve relative to the current file
    final currentDir = currentFile.substring(0, currentFile.lastIndexOf('/'));
    if (uri.startsWith('./')) {
      return '$currentDir/${uri.substring(_relativeCurrentDirPrefixLength)}';
    } else if (uri.startsWith('../')) {
      // Handle parent directory traversal
      var resolvedPath = currentDir;
      var remainingUri = uri;
      while (remainingUri.startsWith('../')) {
        resolvedPath = resolvedPath.substring(0, resolvedPath.lastIndexOf('/'));
        remainingUri = remainingUri.substring(_relativeParentDirPrefixLength);
      }
      return '$resolvedPath/$remainingUri';
    } else {
      return '$currentDir/$uri';
    }
  }
}
