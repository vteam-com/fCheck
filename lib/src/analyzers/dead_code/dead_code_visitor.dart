// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_symbol.dart';
import 'package:fcheck/src/analyzers/shared/dependency_uri_utils.dart';
import 'package:fcheck/src/models/ignore_config.dart';

/// Collects dead code inputs and unused variable issues for a single file.
class DeadCodeVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a visitor for collecting dead code data in a single file.
  DeadCodeVisitor({
    required this.filePath,
    required this.rootPath,
    required this.packageName,
    required this.content,
    required this.lineNumberForOffset,
  });

  /// Absolute path of the file being analyzed.
  final String filePath;

  /// Root directory used to resolve relative imports.
  final String rootPath;

  /// Package name used to resolve package: imports.
  final String packageName;

  /// File contents for ignore configuration checks.
  final String content;

  /// Maps AST offsets to 1-based line numbers.
  final int Function(int offset) lineNumberForOffset;

  /// Resolved Dart file dependencies for this file.
  final List<String> dependencies = <String>[];

  /// Top-level class declarations found in the file.
  final List<DeadCodeSymbol> classes = <DeadCodeSymbol>[];

  /// Top-level function declarations found in the file.
  final List<DeadCodeSymbol> functions = <DeadCodeSymbol>[];

  /// Method declarations found in classes/mixins/enums/extensions.
  final List<DeadCodeSymbol> methods = <DeadCodeSymbol>[];

  /// Unused local variable issues found in the file.
  final List<DeadCodeIssue> unusedVariableIssues = <DeadCodeIssue>[];

  /// Identifiers used in the file (excluding declarations).
  final Set<String> usedIdentifiers = <String>{};

  /// Whether the file defines a `main()` entry point.
  bool hasMain = false;

  final List<_VariableScope> _scopes = <_VariableScope>[];

  @override
  void visitImportDirective(ImportDirective node) {
    _addDirectiveDependencies(node.uri.stringValue, node.configurations);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _addDirectiveDependencies(node.uri.stringValue, node.configurations);
    super.visitExportDirective(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    _addDirectiveDependencies(node.uri.stringValue, const []);
    super.visitPartDirective(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final functionName = node.name.lexeme;
    if (functionName == 'main') {
      hasMain = true;
    }

    if (node.parent is CompilationUnit &&
        !IgnoreConfig.isNodeIgnored(node, content, 'dead_code') &&
        !_hasPreviewAnnotation(node.metadata)) {
      functions.add(
        DeadCodeSymbol(
          name: functionName,
          lineNumber: lineNumberForOffset(node.offset),
        ),
      );
    }

    final treatParametersAsUsed =
        node.functionExpression.body is EmptyFunctionBody;
    _pushScope(functionName, treatParametersAsUsed: treatParametersAsUsed);
    super.visitFunctionDeclaration(node);
    _popScope();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code') &&
        !_hasOverrideAnnotation(node.metadata) &&
        !_hasPreviewAnnotation(node.metadata) &&
        !_isAbstractMethod(node)) {
      methods.add(
        DeadCodeSymbol(
          name: node.name.lexeme,
          lineNumber: lineNumberForOffset(node.offset),
          owner: _resolveMethodOwner(node),
        ),
      );
    }

    final treatParametersAsUsed =
        _hasOverrideAnnotation(node.metadata) || node.body is EmptyFunctionBody;
    _pushScope(node.name.lexeme, treatParametersAsUsed: treatParametersAsUsed);
    super.visitMethodDeclaration(node);
    _popScope();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final treatParametersAsUsed = node.body is EmptyFunctionBody;
    _pushScope(
      node.name?.lexeme ?? 'constructor',
      treatParametersAsUsed: treatParametersAsUsed,
    );
    super.visitConstructorDeclaration(node);
    _popScope();
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _pushScope('anonymous');
    super.visitFunctionExpression(node);
    _popScope();
  }

  @override
  void visitBlock(Block node) {
    _pushScope(_currentOwnerName());
    super.visitBlock(node);
    _popScope();
  }

  @override
  void visitForStatement(ForStatement node) {
    _pushScope(_currentOwnerName());
    super.visitForStatement(node);
    _popScope();
  }

  @override
  void visitCatchClause(CatchClause node) {
    _pushScope('catch');
    final exception = node.exceptionParameter;
    if (exception != null) {
      _declareVariable(exception.name.lexeme, exception, isParameter: true);
    }
    final stackTrace = node.stackTraceParameter;
    if (stackTrace != null) {
      _declareVariable(stackTrace.name.lexeme, stackTrace, isParameter: true);
    }
    super.visitCatchClause(node);
    _popScope();
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      final className = _stripTypeParameters(node.namePart.toString());
      classes.add(
        DeadCodeSymbol(
          name: className,
          lineNumber: lineNumberForOffset(node.offset),
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_isLocalVariable(node) &&
        !IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(node.name.lexeme, node);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(node.name.lexeme, node);
    }
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final identifier = node.name;
    if (identifier != null &&
        !IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(identifier.lexeme, node, isParameter: true);
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(
        node.name.lexeme,
        node,
        isParameter: true,
        markUsed: true,
      );
    }
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(node.name.lexeme, node, isParameter: true);
    }
    super.visitFunctionTypedFormalParameter(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    if (!IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      _declareVariable(
        node.name.lexeme,
        node,
        isParameter: true,
        markUsed: true,
      );
    }
    super.visitSuperFormalParameter(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isTypeIdentifier(node)) {
      usedIdentifiers.add(node.name);
      super.visitSimpleIdentifier(node);
      return;
    }

    if (!node.inDeclarationContext()) {
      usedIdentifiers.add(node.name);
      if (_isVariableUsage(node)) {
        _markUsed(node.name);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    usedIdentifiers.add(node.name.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _recordOperatorUsage(node.operator.lexeme);
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _recordOperatorUsage(node.operator.lexeme);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _recordOperatorUsage(node.operator.lexeme);
    super.visitPostfixExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _recordCompoundAssignmentUsage(node.operator.lexeme);
    if (node.leftHandSide is IndexExpression) {
      usedIdentifiers.add('[]=');
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    usedIdentifiers.add('[]');
    super.visitIndexExpression(node);
  }

  /// Pushes a variable scope for function/class-local dead-code tracking.
  void _pushScope(String? ownerName, {bool treatParametersAsUsed = false}) {
    _scopes.add(
      _VariableScope(
        ownerName: ownerName,
        treatParametersAsUsed: treatParametersAsUsed,
      ),
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
  String? _currentOwnerName() {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final ownerName = _scopes[i].ownerName;
      if (ownerName != null && ownerName.isNotEmpty) {
        return ownerName;
      }
    }
    return null;
  }

  /// Internal helper used by fcheck analysis and reporting.
  void _popScope() {
    if (_scopes.isEmpty) {
      return;
    }
    final scope = _scopes.removeLast();
    for (final entry in scope.declared.entries) {
      if (!scope.used.contains(entry.key)) {
        final info = entry.value;
        unusedVariableIssues.add(
          DeadCodeIssue(
            type: DeadCodeIssueType.unusedVariable,
            filePath: filePath,
            lineNumber: info.lineNumber,
            name: info.name,
            owner: info.ownerName,
          ),
        );
      }
    }
  }

  /// Registers a newly declared local variable or parameter in current scope.
  void _declareVariable(
    String name,
    AstNode node, {
    bool isParameter = false,
    bool markUsed = false,
  }) {
    if (_scopes.isEmpty) {
      return;
    }
    if (_shouldIgnoreVariableName(name)) {
      return;
    }
    final scope = _scopes.last;
    if (scope.declared.containsKey(name)) {
      return;
    }
    scope.declared[name] = _VariableInfo(
      name: name,
      lineNumber: lineNumberForOffset(node.offset),
      ownerName: scope.ownerName,
      isParameter: isParameter,
    );
    if (markUsed || (isParameter && scope.treatParametersAsUsed)) {
      scope.used.add(name);
    }
  }

  /// Internal helper used by fcheck analysis and reporting.
  void _markUsed(String name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final scope = _scopes[i];
      if (scope.declared.containsKey(name)) {
        scope.used.add(name);
        return;
      }
    }
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isLocalVariable(VariableDeclaration node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FieldDeclaration ||
          current is TopLevelVariableDeclaration) {
        return false;
      }
      if (current is FunctionBody || current is CompilationUnit) {
        return true;
      }
      current = current.parent;
    }
    return true;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isVariableUsage(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is Label) {
      return false;
    }
    if (parent is NamedExpression && parent.name.label == node) {
      return false;
    }
    if (parent is PrefixedIdentifier && parent.identifier == node) {
      return false;
    }
    if (parent is PropertyAccess && parent.propertyName == node) {
      return false;
    }
    if (parent is MethodInvocation && parent.methodName == node) {
      if (parent.target != null) {
        return false;
      }
    }
    return true;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isTypeIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is NamedType) {
      return parent.name.lexeme == node.name;
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _shouldIgnoreVariableName(String name) {
    if (name.isEmpty) {
      return true;
    }
    if (name == '_') {
      return true;
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasOverrideAnnotation(List<Annotation> metadata) {
    return _hasAnnotationNamed(metadata, 'override');
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasPreviewAnnotation(List<Annotation> metadata) {
    return _hasAnnotationNamed(metadata, 'Preview');
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _hasAnnotationNamed(List<Annotation> metadata, String annotationName) {
    for (final annotation in metadata) {
      final name = annotation.name;
      if (name is SimpleIdentifier && name.name == annotationName) {
        return true;
      }
      if (name is PrefixedIdentifier &&
          name.identifier.name == annotationName) {
        return true;
      }
    }
    return false;
  }

  /// Internal helper used by fcheck analysis and reporting.
  bool _isAbstractMethod(MethodDeclaration node) {
    return node.body is EmptyFunctionBody;
  }

  /// Internal helper used by fcheck analysis and reporting.
  String? _resolveMethodOwner(MethodDeclaration node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) {
        return current.name.lexeme;
      }
      if (current is EnumDeclaration) {
        return current.name.lexeme;
      }
      if (current is MixinDeclaration) {
        return current.name.lexeme;
      }
      if (current is ExtensionDeclaration) {
        return current.name?.lexeme ?? 'extension';
      }
      current = current.parent;
    }
    return null;
  }

  /// Internal helper used by fcheck analysis and reporting.
  String _stripTypeParameters(String name) {
    final typeStart = name.indexOf('<');
    if (typeStart == -1) {
      return name;
    }
    return name.substring(0, typeStart).trimRight();
  }

  /// Records usage of an operator method name from expression syntax.
  void _recordOperatorUsage(String operatorLexeme) {
    switch (operatorLexeme) {
      case '++':
        usedIdentifiers.add('+');
        return;
      case '--':
        usedIdentifiers.add('-');
        return;
      case '+':
      case '-':
      case '*':
      case '/':
      case '~/':
      case '%':
      case '>':
      case '>=':
      case '<':
      case '<=':
      case '==':
      case '&':
      case '|':
      case '^':
      case '<<':
      case '>>':
      case '>>>':
      case '~':
      case '[]':
      case '[]=':
        usedIdentifiers.add(operatorLexeme);
        return;
      default:
        return;
    }
  }

  /// Maps compound assignment syntax to operator method names.
  void _recordCompoundAssignmentUsage(String assignmentOperator) {
    switch (assignmentOperator) {
      case '=':
      case '??=':
        return;
      case '+=':
        usedIdentifiers.add('+');
        return;
      case '-=':
        usedIdentifiers.add('-');
        return;
      case '*=':
        usedIdentifiers.add('*');
        return;
      case '/=':
        usedIdentifiers.add('/');
        return;
      case '~/=':
        usedIdentifiers.add('~/');
        return;
      case '%=':
        usedIdentifiers.add('%');
        return;
      case '&=':
        usedIdentifiers.add('&');
        return;
      case '|=':
        usedIdentifiers.add('|');
        return;
      case '^=':
        usedIdentifiers.add('^');
        return;
      case '<<=':
        usedIdentifiers.add('<<');
        return;
      case '>>=':
        usedIdentifiers.add('>>');
        return;
      case '>>>=':
        usedIdentifiers.add('>>>');
        return;
      default:
        return;
    }
  }

  /// Adds dependencies declared through import/export/part directives.
  void _addDirectiveDependencies(
    String? uri,
    List<Configuration> configurations,
  ) {
    addDirectiveDartDependencies(
      uri: uri,
      configurations: configurations,
      packageName: packageName,
      filePath: filePath,
      rootPath: rootPath,
      dependencies: dependencies,
    );
  }
}

class _VariableScope {
  _VariableScope({
    required this.ownerName,
    required this.treatParametersAsUsed,
  });

  final String? ownerName;
  final bool treatParametersAsUsed;
  final Map<String, _VariableInfo> declared = <String, _VariableInfo>{};
  final Set<String> used = <String>{};
}

class _VariableInfo {
  _VariableInfo({
    required this.name,
    required this.lineNumber,
    required this.ownerName,
    required this.isParameter,
  });

  final String name;
  final int lineNumber;
  final String? ownerName;
  final bool isParameter;
}
