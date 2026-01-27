import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Finds classes that we want to sort: StatelessWidget, StatefulWidget, or
/// State<...> classes (the typical Flutter patterns).
class ClassVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a new ClassVisitor for finding Flutter widget classes.
  ClassVisitor();

  /// The list of class declarations found that extend Flutter widget classes.
  ///
  /// This list contains [ClassDeclaration] nodes for classes that extend
  /// StatelessWidget, StatefulWidget, or State classes, which are the
  /// Flutter classes that should have their members sorted.
  final List<ClassDeclaration> targetClasses = <ClassDeclaration>[];

  /// Visits a class declaration node in the AST.
  ///
  /// This method is called for each class declaration encountered during
  /// AST traversal. It checks if the class extends StatelessWidget,
  /// StatefulWidget, or State classes, and if so, adds it to the
  /// [targetClasses] list for member sorting.
  ///
  /// [node] The class declaration node being visited.
  @override
  void visitClassDeclaration(final ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final String superName = extendsClause.superclass.toString();
      // Match StatelessWidget, StatefulWidget, or State (including generics: State<MyWidget>)
      if (superName == 'StatelessWidget' ||
          superName == 'StatefulWidget' ||
          superName == 'State' ||
          superName.startsWith('State<')) {
        targetClasses.add(node);
      }
    }
    super.visitClassDeclaration(node);
  }

  /// Visits an adjacent strings node.
  ///
  /// This method is called when visiting [AdjacentStrings] AST nodes.
  /// It continues the traversal by calling the superclass implementation.
  @override
  void visitAdjacentStrings(final AdjacentStrings node) {
    super.visitAdjacentStrings(node);
  }

  /// Visits an annotated node.
  ///
  /// This method is called when visiting [AnnotatedNode] AST nodes.
  /// It continues the traversal by calling the superclass implementation.
  @override
  void visitAnnotatedNode(final AnnotatedNode node) {
    super.visitAnnotatedNode(node);
  }

  /// Visits an annotation node.
  ///
  /// This method is called when visiting [Annotation] AST nodes.
  /// It continues the traversal by calling the superclass implementation.
  @override
  void visitAnnotation(final Annotation node) {
    super.visitAnnotation(node);
  }

  /// Visits an argument list node.
  ///
  /// This method is called when visiting [ArgumentList] AST nodes.
  /// It continues the traversal by calling the superclass implementation.
  @override
  void visitArgumentList(final ArgumentList node) {
    super.visitArgumentList(node);
  }

  /// Visits an as expression node.
  ///
  /// This method is called when visiting [AsExpression] AST nodes.
  /// It continues the traversal by calling the superclass implementation.
  @override
  void visitAsExpression(final AsExpression node) {
    super.visitAsExpression(node);
  }
}
