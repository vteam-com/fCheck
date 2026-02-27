import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Collects documentation-policy issues from a single Dart file AST.
class DocumentationVisitor extends RecursiveAstVisitor<void> {
  static const int _maxShortStatementCount = 3;
  static const int _maxShortLineCount = 6;
  static const int _minComplexPrivateFunctionLineCount = 10;

  /// Creates a visitor for one file.
  DocumentationVisitor({
    required this.filePath,
    required this.content,
    required this.lines,
    required this.lineNumberForOffset,
  });

  /// File path currently analyzed.
  final String filePath;

  /// Raw file content used for ignore checks.
  final String content;

  /// Raw file lines.
  final List<String> lines;

  /// Offset-to-line mapper.
  final int Function(int offset) lineNumberForOffset;

  /// Issues found in this file.
  final List<DocumentationIssue> issues = <DocumentationIssue>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.toString();
    if (_isPublicName(className) &&
        !_hasDocumentationComment(node) &&
        !IgnoreConfig.isNodeIgnored(node, content, 'documentation')) {
      issues.add(
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedPublicClass,
          filePath: filePath,
          lineNumber: lineNumberForOffset(node.offset),
          subject: className,
        ),
      );
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit) {
      super.visitFunctionDeclaration(node);
      return;
    }

    final functionName = node.name.lexeme;
    if (functionName == 'main') {
      super.visitFunctionDeclaration(node);
      return;
    }

    if (IgnoreConfig.isNodeIgnored(node, content, 'documentation')) {
      super.visitFunctionDeclaration(node);
      return;
    }

    if (_isPublicName(functionName)) {
      if (!_hasDocumentationComment(node)) {
        issues.add(
          DocumentationIssue(
            type: DocumentationIssueType.undocumentedPublicFunction,
            filePath: filePath,
            lineNumber: lineNumberForOffset(node.offset),
            subject: functionName,
          ),
        );
      }
    } else if (_isComplexFunctionBody(node.functionExpression.body) &&
        !_hasAnyLeadingComment(node)) {
      issues.add(
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedComplexPrivateFunction,
          filePath: filePath,
          lineNumber: lineNumberForOffset(node.offset),
          subject: functionName,
        ),
      );
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (IgnoreConfig.isNodeIgnored(node, content, 'documentation')) {
      super.visitMethodDeclaration(node);
      return;
    }

    if (_hasOverrideAnnotation(node.metadata) || node.isOperator) {
      super.visitMethodDeclaration(node);
      return;
    }

    final methodName = node.name.lexeme;
    final className = node
        .thisOrAncestorOfType<ClassDeclaration>()
        ?.namePart
        .toString();
    final subject = className == null ? methodName : '$className.$methodName';

    if (_isPublicName(methodName)) {
      if (!_hasDocumentationComment(node)) {
        issues.add(
          DocumentationIssue(
            type: DocumentationIssueType.undocumentedPublicFunction,
            filePath: filePath,
            lineNumber: lineNumberForOffset(node.offset),
            subject: subject,
          ),
        );
      }
    } else if (_isComplexFunctionBody(node.body) &&
        !_hasAnyLeadingComment(node)) {
      issues.add(
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedComplexPrivateFunction,
          filePath: filePath,
          lineNumber: lineNumberForOffset(node.offset),
          subject: subject,
        ),
      );
    }

    super.visitMethodDeclaration(node);
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasDocumentationComment(AnnotatedNode node) {
    return node.documentationComment != null;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasAnyLeadingComment(AnnotatedNode node) {
    return node.documentationComment != null ||
        node.beginToken.precedingComments != null;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isPublicName(String name) {
    return !name.startsWith('_');
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isComplexFunctionBody(FunctionBody body) {
    if (body is EmptyFunctionBody || body is ExpressionFunctionBody) {
      return false;
    }

    if (body is! BlockFunctionBody) {
      return true;
    }

    final statementCount = body.block.statements.length;
    final lineCount = _countNonEmptyBodyLines(body);
    if (lineCount < _minComplexPrivateFunctionLineCount) {
      return false;
    }
    final complexityCounter = _ComplexityCounter();
    body.accept(complexityCounter);

    return statementCount > _maxShortStatementCount ||
        lineCount > _maxShortLineCount ||
        complexityCounter.controlFlowCount > 0;
  }

  /// Internal helper used by fcheck analysis and reporting.
  int _countNonEmptyBodyLines(FunctionBody body) {
    final startLine = lineNumberForOffset(body.offset).clamp(1, lines.length);
    final endOffset = body.end > 0 ? body.end - 1 : body.offset;
    final endLine = lineNumberForOffset(endOffset).clamp(1, lines.length);
    var nonEmpty = 0;
    for (var lineIndex = startLine - 1; lineIndex <= endLine - 1; lineIndex++) {
      if (lines[lineIndex].trim().isNotEmpty) {
        nonEmpty++;
      }
    }
    return nonEmpty;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasOverrideAnnotation(NodeList<Annotation> metadata) {
    for (final annotation in metadata) {
      if (annotation.name.name == 'override') {
        return true;
      }
    }
    return false;
  }
}

class _ComplexityCounter extends RecursiveAstVisitor<void> {
  int controlFlowCount = 0;

  @override
  void visitIfStatement(IfStatement node) {
    controlFlowCount++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    controlFlowCount++;
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    controlFlowCount++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    controlFlowCount++;
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    controlFlowCount++;
    super.visitSwitchStatement(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    controlFlowCount++;
    super.visitTryStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    controlFlowCount++;
    super.visitConditionalExpression(node);
  }
}
