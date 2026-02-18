import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('library code does not write to console output directly', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];

    for (final file in dartFiles) {
      final parsed = parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      );
      final visitor = _ConsoleOutputVisitor();
      parsed.unit.accept(visitor);

      for (final call in visitor.calls) {
        final location = parsed.lineInfo.getLocation(call.offset);
        final relativePath = p.relative(
          file.path,
          from: Directory.current.path,
        );
        violations.add(
          '$relativePath:${location.lineNumber}:${location.columnNumber} ${call.description}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Only bin/fcheck.dart should write console output.\n'
          '${violations.join('\n')}',
    );
  });
}

class _ConsoleOutputVisitor extends RecursiveAstVisitor<void> {
  final List<_ConsoleCall> calls = <_ConsoleCall>[];

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier && function.name == 'print') {
      calls.add(_ConsoleCall(node.offset, 'print()'));
    }

    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final targetName = _consoleTargetName(node.target);
    final methodName = node.methodName.name;
    final isConsoleWrite =
        targetName != null &&
        (targetName == 'stdout' || targetName == 'stderr') &&
        (methodName == 'write' || methodName == 'writeln');

    if (isConsoleWrite) {
      calls.add(_ConsoleCall(node.offset, '$targetName.$methodName()'));
    }

    super.visitMethodInvocation(node);
  }

  String? _consoleTargetName(Expression? target) {
    if (target is SimpleIdentifier) {
      return target.name;
    }
    if (target is PrefixedIdentifier) {
      return target.identifier.name;
    }
    return null;
  }
}

class _ConsoleCall {
  final int offset;
  final String description;

  _ConsoleCall(this.offset, this.description);
}
