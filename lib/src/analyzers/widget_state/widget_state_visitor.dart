import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/widget_state/widget_state_file_data.dart';
import 'package:path/path.dart' as p;

/// Collects what the widget `State` analysis reads from one Dart file: its
/// classes, the types it writes, its calls of a widget's `createState()`
/// and its part files.
class WidgetStateVisitor extends RecursiveAstVisitor<void> {
  /// The method of a stateful widget making its `State`.
  static const String _createState = 'createState';

  /// Path of the visited file.
  final String filePath;

  /// Maps a character offset to its 1-based line.
  final int Function(int offset) lineNumberForOffset;

  /// Lines ending with `// ignore: fcheck_widget_state`.
  final Set<int> ignoredLineNumbers;

  /// The classes the file declares.
  final List<WidgetStateClass> classes = [];

  /// The types the file writes, in source order.
  final List<WidgetStateReference> typeUses = [];

  /// The file's `createState()` calls, each naming its widget.
  final List<WidgetStateReference> stateMakers = [];

  /// Normalized paths of the file's part files.
  final List<String> partPaths = [];

  /// The type or widget naming each local, by name, in source order.
  final Map<String, String> _localTypes = {};

  /// Creates a visitor for the file at [filePath].
  WidgetStateVisitor({
    required this.filePath,
    required this.lineNumberForOffset,
    required this.ignoredLineNumbers,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass;
    classes.add((
      name: node.namePart.typeName.lexeme,
      superclass: superclass?.name.lexeme,
      typeArgument: switch (superclass?.typeArguments?.arguments.firstOrNull) {
        NamedType(:final name) => name.lexeme,
        _ => null,
      },
      lineNumber: _lineOf(node),
      isIgnored: _isIgnored(node),
    ));
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == _createState) {
      if (_widgetOf(node.target) case final widget?) {
        stateMakers.add(_reference(widget, node));
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    typeUses.add(_reference(node.name.lexeme, node));
    super.visitNamedType(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null && !uri.contains(':')) {
      partPaths.add(p.normalize(p.join(p.dirname(filePath), uri)));
    }
    super.visitPartDirective(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final type = switch (node.parent) {
      VariableDeclarationList(type: NamedType(:final name)) => name.lexeme,
      _ => _widgetOf(node.initializer),
    };
    if (type != null) {
      _localTypes[node.name.lexeme] = type;
    }
    super.visitVariableDeclaration(node);
  }

  /// Whether [node], or a node around it, starts on an ignored line.
  bool _isIgnored(AstNode node) {
    if (ignoredLineNumbers.isEmpty) {
      return false;
    }
    for (AstNode? current = node; current != null; current = current.parent) {
      if (ignoredLineNumbers.contains(_lineOf(current))) {
        return true;
      }
    }
    return false;
  }

  /// The 1-based line [node] starts on: for a declaration, the line of its
  /// keyword or name, after its doc comment and annotations.
  int _lineOf(AstNode node) => lineNumberForOffset(
    node is AnnotatedNode
        ? node.firstTokenAfterCommentAndMetadata.offset
        : node.offset,
  );

  /// The reference to [name] written at [node].
  WidgetStateReference _reference(String name, AstNode node) => (
    name: name,
    offset: node.offset,
    lineNumber: _lineOf(node),
    isIgnored: _isIgnored(node),
  );

  /// The widget [expression] builds, by name, read without resolving:
  /// built in place (`Foo()`), or a local given one or typed as one; null
  /// when it builds none it can tell.
  String? _widgetOf(Expression? expression) => switch (expression) {
    InstanceCreationExpression(:final constructorName) =>
      constructorName.type.name.lexeme,
    // `Foo()`, read without resolving, is an invocation
    MethodInvocation(target: null, :final methodName) => methodName.name,
    SimpleIdentifier(:final name) => _localTypes[name],
    _ => null,
  };
}
