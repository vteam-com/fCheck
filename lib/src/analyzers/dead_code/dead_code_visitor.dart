import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_file_data.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:path/path.dart' as p;

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
        !IgnoreConfig.isNodeIgnored(node, content, 'dead_code')) {
      functions.add(DeadCodeSymbol(
        name: functionName,
        lineNumber: lineNumberForOffset(node.offset),
      ));
    }

    final treatParametersAsUsed =
        node.functionExpression.body is EmptyFunctionBody;
    _pushScope(
      functionName,
      treatParametersAsUsed: treatParametersAsUsed,
    );
    super.visitFunctionDeclaration(node);
    _popScope();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final treatParametersAsUsed =
        _hasOverrideAnnotation(node.metadata) || node.body is EmptyFunctionBody;
    _pushScope(
      node.name.lexeme,
      treatParametersAsUsed: treatParametersAsUsed,
    );
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
      classes.add(DeadCodeSymbol(
        name: className,
        lineNumber: lineNumberForOffset(node.offset),
      ));
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

  void _pushScope(
    String? ownerName, {
    bool treatParametersAsUsed = false,
  }) {
    _scopes.add(
      _VariableScope(
        ownerName: ownerName,
        treatParametersAsUsed: treatParametersAsUsed,
      ),
    );
  }

  String? _currentOwnerName() {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final ownerName = _scopes[i].ownerName;
      if (ownerName != null && ownerName.isNotEmpty) {
        return ownerName;
      }
    }
    return null;
  }

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

  void _markUsed(String name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final scope = _scopes[i];
      if (scope.declared.containsKey(name)) {
        scope.used.add(name);
        return;
      }
    }
  }

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

  bool _isTypeIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is NamedType) {
      return parent.name.lexeme == node.name;
    }
    return false;
  }

  bool _shouldIgnoreVariableName(String name) {
    if (name.isEmpty) {
      return true;
    }
    if (name == '_') {
      return true;
    }
    return false;
  }

  bool _hasOverrideAnnotation(List<Annotation> metadata) {
    for (final annotation in metadata) {
      final name = annotation.name;
      if (name is SimpleIdentifier && name.name == 'override') {
        return true;
      }
      if (name is PrefixedIdentifier && name.identifier.name == 'override') {
        return true;
      }
    }
    return false;
  }

  String _stripTypeParameters(String name) {
    final typeStart = name.indexOf('<');
    if (typeStart == -1) {
      return name;
    }
    return name.substring(0, typeStart).trimRight();
  }

  bool _isDartFile(String uri) {
    if (uri.startsWith('dart:')) {
      return false;
    }
    if (uri.startsWith('package:') &&
        !uri.startsWith('package:$packageName/')) {
      return false;
    }
    if (uri.startsWith('package:$packageName/')) {
      return uri.endsWith('.dart');
    }
    return uri.endsWith('.dart');
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
    if (uri == null || !_isDartFile(uri)) {
      return;
    }
    dependencies.add(_resolveDependency(uri, filePath));
  }

  String _resolveDependency(String uri, String currentFile) {
    if (uri.startsWith('package:$packageName/')) {
      final packagePath = uri.substring('package:$packageName/'.length);
      return p.join(rootPath, 'lib', packagePath);
    }

    final currentDir = currentFile.substring(0, currentFile.lastIndexOf('/'));
    if (uri.startsWith('./')) {
      return '$currentDir/${uri.substring(_relativeCurrentDirPrefixLength)}';
    } else if (uri.startsWith('../')) {
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

  static const int _relativeCurrentDirPrefixLength = 2;
  static const int _relativeParentDirPrefixLength = 3;
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
