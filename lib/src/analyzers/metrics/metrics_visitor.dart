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
    stringLiteralCount++;
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    stringLiteralCount++;
    super.visitInterpolationString(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    numberLiteralCount++;
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    numberLiteralCount++;
    super.visitDoubleLiteral(node);
  }
}
