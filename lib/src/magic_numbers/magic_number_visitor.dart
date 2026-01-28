import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'magic_number_issue.dart';

/// AST visitor that flags numeric literals that look like magic numbers.
class MagicNumberVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a visitor for the provided file content.
  MagicNumberVisitor(this.filePath, this.content);

  /// Path of the file being analyzed.
  final String filePath;

  /// Raw content of the file for line number lookups.
  final String content;

  /// Issues discovered during traversal.
  final List<MagicNumberIssue> foundIssues = <MagicNumberIssue>[];

  static const Set<num> _allowedValues = {0, 1, -1};

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    _inspectLiteral(node.value, node.literal.lexeme, node);
    super.visitDoubleLiteral(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    _inspectLiteral(node.value, node.literal.lexeme, node);
    super.visitIntegerLiteral(node);
  }

  void _inspectLiteral(num? value, String literalText, AstNode node) {
    if (value == null) {
      return;
    }

    if (_allowedValues.contains(value)) {
      return;
    }

    if (_isInAnnotation(node) ||
        _isInConstDeclaration(node) ||
        _isInsideConstExpression(node)) {
      return;
    }

    final lineNumber = _getLineNumber(node.offset);

    foundIssues.add(MagicNumberIssue(
      filePath: filePath,
      lineNumber: lineNumber,
      value: literalText,
    ));
  }

  bool _isInAnnotation(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Annotation) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInConstDeclaration(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        if (current.parent is VariableDeclarationList) {
          final list = current.parent as VariableDeclarationList;
          if (list.isConst) {
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

  bool _isInsideConstExpression(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression && current.isConst) {
        return true;
      }
      if (current is ListLiteral && current.isConst) {
        return true;
      }
      if (current is SetOrMapLiteral && current.isConst) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  int _getLineNumber(int offset) {
    final lines = content.substring(0, offset).split('\n');
    return lines.length;
  }
}
