import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/models/ignore_config.dart';

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

  /// Offset-to-line lookup built once per file.
  late final int Function(int offset) _lineNumberForOffset =
      IgnoreConfig.newlineLineNumberLookup(content);

  /// Lines carrying `// ignore: fcheck_magic_numbers`, collected once per file.
  late final Set<int> _ignoredLineNumbers =
      IgnoreConfig.collectIgnoredLineNumbers(
        content.split('\n'),
        'magic_numbers',
      );

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

  /// Internal helper used by fcheck analysis and reporting.
  void _inspectLiteral(num? value, String literalText, AstNode node) {
    if (value == null) {
      return;
    }

    if (_allowedValues.contains(value)) {
      return;
    }

    if (_isInAnnotation(node) ||
        _isInConstDeclaration(node) ||
        _isInStaticConstDeclaration(node) ||
        _isInFinalIntDeclaration(node) ||
        _isInsideConstExpression(node) ||
        IgnoreConfig.isNodeIgnoredWithLines(
          node,
          ignoredLineNumbers: _ignoredLineNumbers,
          lineNumberForOffset: _lineNumberForOffset,
        )) {
      return;
    }

    final lineNumber = _getLineNumber(node.offset);

    foundIssues.add(
      MagicNumberIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        value: literalText,
      ),
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
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

  /// Internal helper used by fcheck analysis and reporting.
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

  /// Internal helper used by fcheck analysis and reporting.
  /// Internal helper used by fcheck analysis and reporting.
  bool _isInsideConstExpression(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
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

  /// Internal helper used by fcheck analysis and reporting.
  bool _isInStaticConstDeclaration(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FieldDeclaration &&
          current.isStatic &&
          current.fields.isConst) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isInFinalIntDeclaration(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        if (current.parent is VariableDeclarationList) {
          final list = current.parent as VariableDeclarationList;
          if (list.isFinal &&
              (list.type?.toString() == 'int' ||
                  list.type?.toString() == 'double' ||
                  list.type?.toString() == 'num')) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  int _getLineNumber(int offset) => _lineNumberForOffset(offset);
}
