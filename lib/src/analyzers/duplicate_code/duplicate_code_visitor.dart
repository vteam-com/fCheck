import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_file_data.dart';

/// Collects normalized executable snippets for duplicate-code analysis.
class DuplicateCodeVisitor extends RecursiveAstVisitor<void> {
  /// Default minimum normalized token count required for a snippet.
  static const int defaultMinTokenCount = 20;

  /// Default minimum non-empty line count required for a snippet.
  static const int defaultMinNonEmptyLineCount = 10;

  static final RegExp _identifierPattern = RegExp(r'^[A-Za-z_]\w*$');

  static final RegExp _numberPattern = RegExp(
    r'^(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)$',
  );

  static final RegExp _stringPattern = RegExp(
    r'^(?:"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27)$',
    dotAll: true,
  );

  static final RegExp _tokenPattern = RegExp(
    r'[A-Za-z_]\w*|0x[0-9A-Fa-f]+|\d+(?:\.\d+)?|'
    r'==|!=|<=|>=|=>|&&|\|\||\+\+|--|\+=|-=|\*=|/=|%=|~/=|<<=|>>=|>>>=|&=|\|=|\^=|'
    r'[-+*/%&|^~!<>]=?|[{}()\[\].,;:?]|'
    r'"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27',
  );

  static final Set<String> _dartKeywords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'base',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'Function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };

  /// Creates a duplicate code visitor.
  DuplicateCodeVisitor({
    required this.filePath,
    required this.lineNumberForOffset,
    required this.lines,
    this.minTokenCount = defaultMinTokenCount,
    this.minNonEmptyLineCount = defaultMinNonEmptyLineCount,
  });

  /// Current file path.
  final String filePath;

  /// Offset-to-line mapper.
  final int Function(int offset) lineNumberForOffset;

  /// Raw source lines for the current file.
  final List<String> lines;

  /// Minimum token count for a snippet to be eligible.
  final int minTokenCount;

  /// Minimum non-empty body lines required for a snippet to be eligible.
  final int minNonEmptyLineCount;

  /// Collected snippets.
  final List<DuplicateCodeSnippet> snippets = <DuplicateCodeSnippet>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addSnippet(
      symbol: node.name.lexeme,
      kind: 'function',
      offset: node.offset,
      parameters: node.functionExpression.parameters,
      body: node.functionExpression.body,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addSnippet(
      symbol: node.name.lexeme,
      kind: 'method',
      offset: node.offset,
      parameters: node.parameters,
      body: node.body,
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final constructorName = node.name?.lexeme;
    final typeName = node.typeName?.toSource() ?? 'constructor';
    final symbol = constructorName == null || constructorName.isEmpty
        ? typeName
        : '$typeName.$constructorName';

    _addSnippet(
      symbol: symbol,
      kind: 'constructor',
      offset: node.offset,
      parameters: node.parameters,
      body: node.body,
    );
    super.visitConstructorDeclaration(node);
  }

  void _addSnippet({
    required String symbol,
    required String kind,
    required int offset,
    required FormalParameterList? parameters,
    required FunctionBody body,
  }) {
    if (body is EmptyFunctionBody) {
      return;
    }

    final normalizedTokens = _normalizeTokens(body.toSource());
    if (normalizedTokens.length < minTokenCount) {
      return;
    }
    final nonEmptyLineCount = _countNonEmptyBodyLines(body);
    if (nonEmptyLineCount < minNonEmptyLineCount) {
      return;
    }
    final parameterSignature = _buildParameterSignature(parameters);

    snippets.add(
      DuplicateCodeSnippet(
        filePath: filePath,
        lineNumber: lineNumberForOffset(offset),
        symbol: symbol,
        kind: kind,
        parameterSignature: parameterSignature,
        nonEmptyLineCount: nonEmptyLineCount,
        normalizedTokens: normalizedTokens,
      ),
    );
  }

  List<String> _normalizeTokens(String source) {
    final tokens = <String>[];

    for (final match in _tokenPattern.allMatches(source)) {
      final raw = match.group(0);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      if (_stringPattern.hasMatch(raw)) {
        tokens.add('<str>');
        continue;
      }

      if (_numberPattern.hasMatch(raw)) {
        tokens.add('<num>');
        continue;
      }

      if (_identifierPattern.hasMatch(raw) && !_dartKeywords.contains(raw)) {
        tokens.add('<id>');
        continue;
      }

      tokens.add(raw);
    }

    return tokens;
  }

  String _buildParameterSignature(FormalParameterList? parameterList) {
    if (parameterList == null) {
      return '';
    }

    return parameterList.parameters.map(_buildParameterDescriptor).join('|');
  }

  String _buildParameterDescriptor(FormalParameter parameter) {
    final kind = _parameterKindLabel(parameter);
    var current = parameter;
    var hasDefaultValue = false;

    if (current is DefaultFormalParameter) {
      hasDefaultValue = current.defaultValue != null;
      current = current.parameter;
    }

    final defaultMarker = hasDefaultValue ? '=default' : '';
    return '$kind:${_describeParameter(current)}$defaultMarker';
  }

  String _parameterKindLabel(FormalParameter parameter) {
    if (parameter.isRequiredNamed) {
      return 'required_named';
    }
    if (parameter.isOptionalNamed) {
      return 'optional_named';
    }
    if (parameter.isOptionalPositional) {
      return 'optional_positional';
    }
    return 'required_positional';
  }

  String _describeParameter(FormalParameter parameter) {
    if (parameter is SimpleFormalParameter) {
      return 'simple:${parameter.keyword?.lexeme ?? ''}:${_compactSource(parameter.type)}';
    }

    if (parameter is FieldFormalParameter) {
      return 'field:${parameter.keyword?.lexeme ?? ''}:${_compactSource(parameter.type)}:'
          '${_compactSource(parameter.typeParameters)}:${_buildParameterSignature(parameter.parameters)}'
          '${parameter.question == null ? '' : '?'}';
    }

    if (parameter is SuperFormalParameter) {
      return 'super:${parameter.keyword?.lexeme ?? ''}:${_compactSource(parameter.type)}:'
          '${_compactSource(parameter.typeParameters)}:${_buildParameterSignature(parameter.parameters)}'
          '${parameter.question == null ? '' : '?'}';
    }

    if (parameter is FunctionTypedFormalParameter) {
      return 'function_typed:${parameter.keyword?.lexeme ?? ''}:${_compactSource(parameter.returnType)}:'
          '${_compactSource(parameter.typeParameters)}:${_buildParameterSignature(parameter.parameters)}'
          '${parameter.question == null ? '' : '?'}';
    }

    return parameter.runtimeType.toString();
  }

  String _compactSource(AstNode? node) {
    if (node == null) {
      return '';
    }
    return node.toSource().replaceAll(RegExp(r'\s+'), '');
  }

  int _countNonEmptyBodyLines(FunctionBody body) {
    final startLine = lineNumberForOffset(body.offset);
    final endLine = lineNumberForOffset(body.end);
    if (startLine <= 0 || endLine <= 0 || startLine > lines.length) {
      return 0;
    }
    final safeEndLine = endLine > lines.length ? lines.length : endLine;

    var count = 0;
    for (var lineIndex = startLine - 1; lineIndex < safeEndLine; lineIndex++) {
      final trimmed = lines[lineIndex].trim();
      if (trimmed.isEmpty || trimmed == '{' || trimmed == '}') {
        continue;
      }
      count++;
    }
    return count;
  }
}
