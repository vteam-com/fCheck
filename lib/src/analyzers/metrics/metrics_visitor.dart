import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A visitor that traverses the AST to collect quality metrics.
class MetricsQualityVisitor extends RecursiveAstVisitor<void> {
  /// The total number of public class declarations found in the visited file.
  int classCount = 0;

  /// Whether any of the classes in the file extend StatefulWidget.
  bool hasStatefulWidget = false;

  /// The total number of functions and methods found.
  int functionCount = 0;

  /// The total number of top-level functions found.
  int topLevelFunctionCount = 0;

  /// The total number of methods found.
  int methodCount = 0;

  /// The total number of string literals found.
  int stringLiteralCount = 0;

  /// The total number of numeric literals found.
  int numberLiteralCount = 0;

  /// Frequency map of normalized string literal values in the visited file.
  final Map<String, int> stringLiteralFrequencies = <String, int>{};

  /// Frequency map of numeric literal lexemes in the visited file.
  final Map<String, int> numberLiteralFrequencies = <String, int>{};

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.toString();

    // Only count public classes for the "one class per file" rule
    if (!className.startsWith('_')) {
      classCount++;
    }

    final superclass = node.extendsClause?.superclass.toString();
    if (superclass == 'StatefulWidget') {
      hasStatefulWidget = true;
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    topLevelFunctionCount++;
    functionCount++;
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    methodCount++;
    functionCount++;
    super.visitMethodDeclaration(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (_isInDirective(node)) {
      super.visitSimpleStringLiteral(node);
      return;
    }
    stringLiteralCount++;
    _incrementFrequency(stringLiteralFrequencies, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    if (_isInDirective(node)) {
      super.visitInterpolationString(node);
      return;
    }
    stringLiteralCount++;
    _incrementFrequency(stringLiteralFrequencies, node.value);
    super.visitInterpolationString(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    numberLiteralCount++;
    _incrementFrequency(numberLiteralFrequencies, node.literal.lexeme);
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    numberLiteralCount++;
    _incrementFrequency(numberLiteralFrequencies, node.literal.lexeme);
    super.visitDoubleLiteral(node);
  }

  void _incrementFrequency(Map<String, int> frequencies, String key) {
    frequencies[key] = (frequencies[key] ?? 0) + 1;
  }

  /// Returns true when [node] belongs to a directive URI context.
  ///
  /// Directive literals (imports/exports/parts/library) are excluded from
  /// literal inventory metrics.
  bool _isInDirective(AstNode node) {
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
}
