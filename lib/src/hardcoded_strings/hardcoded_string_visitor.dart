import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'hardcoded_string_issue.dart';

/// A visitor that traverses the AST to detect hardcoded strings.
///
/// This class extends the analyzer's AST visitor to identify string literals
/// in Dart source code that may represent user-facing content that should be
/// localized. It intelligently filters out strings that are legitimately
/// hardcoded (imports, annotations, const declarations, etc.).
class HardcodedStringVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a new visitor for the specified file.
  ///
  /// [filePath] should be the path to the file being analyzed.
  /// [content] should be the full text content of the file.
  HardcodedStringVisitor(this.filePath, this.content);

  /// The file path being analyzed.
  final String filePath;

  /// The full text content of the file.
  final String content;

  /// The list of hardcoded string issues found during traversal.
  final List<HardcodedStringIssue> foundIssues = <HardcodedStringIssue>[];

  /// Visits a simple string literal node in the AST.
  ///
  /// This method is called for each simple string literal encountered during
  /// AST traversal. It analyzes the string to determine if it represents a
  /// potentially hardcoded user-facing string that should be localized.
  /// Various heuristics are used to filter out legitimate hardcoded strings
  /// such as imports, annotations, const declarations, etc.
  ///
  /// [node] The simple string literal node being visited.
  @override
  void visitSimpleStringLiteral(final SimpleStringLiteral node) {
    // Skip empty strings
    if (node.value.isEmpty) {
      return;
    }

    // Skip strings that are in import/part/library directives
    if (_isInDirective(node)) {
      return;
    }

    // Skip strings in annotations
    if (_isInAnnotation(node)) {
      return;
    }

    // Skip strings that are keys in Map literals (common for const maps)
    if (_isMapKey(node)) {
      return;
    }

    // Skip strings in const declarations
    if (_isInConstDeclaration(node)) {
      return;
    }

    // Skip strings in l10n calls (basic detection)
    if (_isInL10nCall(node)) {
      return;
    }

    // Skip strings in RegExp calls
    if (_isInRegExpCall(node)) {
      return;
    }

    // Skip strings in Key constructors
    if (_isInKey(node)) {
      return;
    }

    // Skip strings used as index in collections/maps
    if (_isIndex(node)) {
      return;
    }

    // Get line number
    final int lineNumber = _getLineNumber(node.offset);

    foundIssues.add(HardcodedStringIssue(
      filePath: filePath,
      lineNumber: lineNumber,
      value: node.value,
    ));
  }

  /// Checks if a string literal is within a directive (import/export/part).
  bool _isInDirective(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ImportDirective ||
          current is ExportDirective ||
          current is PartDirective ||
          current is PartOfDirective ||
          current is LibraryDirective) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within an annotation.
  bool _isInAnnotation(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Annotation) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is used as a key in a map literal.
  bool _isMapKey(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is MapLiteralEntry) {
      return parent.key == node;
    }
    return false;
  }

  /// Checks if a string literal is within a const declaration.
  bool _isInConstDeclaration(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final VariableDeclaration varDecl = current;
        if (varDecl.parent is VariableDeclarationList) {
          final VariableDeclarationList varList =
              varDecl.parent as VariableDeclarationList;
          if (varList.isConst) {
            return true;
          }
        }
      } else if (current is FieldDeclaration && current.fields.isConst) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within an AppLocalizations call.
  bool _isInL10nCall(final AstNode node) {
    // Basic detection for AppLocalizations calls
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        final Expression? target = invocation.target;
        if (target != null && target.toString().contains('AppLocalizations')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within a RegExp constructor or call.
  bool _isInRegExpCall(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        if (invocation.methodName.name == 'RegExp') {
          return true;
        }
      } else if (current is InstanceCreationExpression) {
        final InstanceCreationExpression creation = current;
        if (creation.constructorName.name?.name == 'RegExp') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within a Key constructor.
  bool _isInKey(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final InstanceCreationExpression creation = current;
        final String? constructorName = creation.constructorName.name?.name;
        if (constructorName == 'Key' ||
            constructorName == 'ValueKey' ||
            constructorName == 'ObjectKey' ||
            constructorName == null) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is used as an index in a collection.
  bool _isIndex(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is IndexExpression) {
      return parent.index == node;
    }
    return false;
  }

  /// Calculates the 1-based line number for a given character offset.
  int _getLineNumber(final int offset) {
    final List<String> lines = content.substring(0, offset).split('\n');
    return lines.length;
  }
}
