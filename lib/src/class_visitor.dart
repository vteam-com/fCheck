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
}
