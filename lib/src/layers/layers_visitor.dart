import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A visitor that traverses the AST to collect import/export references.
///
/// This class extends the analyzer's AST visitor to identify import and export
/// directives in Dart source code. It collects all the files that each Dart
/// file depends on through imports and exports.
class LayersVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a new visitor for the specified file.
  ///
  /// [filePath] should be the path to the file being analyzed.
  LayersVisitor(this.filePath);

  /// The file path being analyzed.
  final String filePath;

  /// The list of files that this file imports or exports.
  final List<String> dependencies = <String>[];

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

  /// Checks if a URI string represents a Dart file import/export.
  ///
  /// Returns true if the URI is a relative path ending with .dart or
  /// a package: import that would resolve to a Dart file.
  ///
  /// [uri] The URI string to check.
  bool _isDartFile(String uri) {
    // Skip dart: imports (core library imports)
    if (uri.startsWith('dart:')) {
      return false;
    }

    // Include package: imports and relative imports
    return uri.endsWith('.dart') || uri.startsWith('package:');
  }

  /// Resolves a dependency URI to an absolute file path.
  ///
  /// For relative imports, resolves against the current file's directory.
  /// For package: imports, returns the URI as-is (simplified resolution).
  ///
  /// [uri] The import/export URI.
  /// [currentFile] The path of the file containing the import/export.
  String _resolveDependency(String uri, String currentFile) {
    if (uri.startsWith('package:')) {
      // For package imports, we use the URI as the dependency key
      // In a real implementation, this would resolve to actual file paths
      return uri;
    } else {
      // For relative imports, resolve relative to the current file
      final currentDir = currentFile.substring(0, currentFile.lastIndexOf('/'));
      if (uri.startsWith('./')) {
        return '$currentDir/${uri.substring(2)}';
      } else if (uri.startsWith('../')) {
        // Handle parent directory traversal
        var resolvedPath = currentDir;
        var remainingUri = uri;
        while (remainingUri.startsWith('../')) {
          resolvedPath =
              resolvedPath.substring(0, resolvedPath.lastIndexOf('/'));
          remainingUri = remainingUri.substring(3);
        }
        return '$resolvedPath/$remainingUri';
      } else {
        return '$currentDir/$uri';
      }
    }
  }
}
