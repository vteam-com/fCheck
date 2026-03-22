import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const Set<String> _testCaseFunctionNames = {'test', 'testWidgets'};

/// Counts `test()` and `testWidgets()` invocations within a parsed unit.
class TestCaseVisitor extends RecursiveAstVisitor<void> {
  /// Number of `test()` and `testWidgets()` invocations encountered.
  int testCaseCount = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_testCaseFunctionNames.contains(node.methodName.name)) {
      testCaseCount++;
    }
    super.visitMethodInvocation(node);
  }
}
