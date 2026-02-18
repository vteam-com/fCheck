import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_file_data.dart';

/// Delegate collecting LOC size artifacts for classes and callables.
class CodeSizeDelegate implements AnalyzerDelegate {
  @override
  CodeSizeFileData analyzeFileWithContext(AnalysisFileContext context) {
    if (context.hasParseErrors || context.compilationUnit == null) {
      return CodeSizeFileData(filePath: context.file.path, artifacts: const []);
    }

    final visitor = _CodeSizeVisitor(context);
    context.compilationUnit!.accept(visitor);

    return CodeSizeFileData(
      filePath: context.file.path,
      artifacts: visitor.artifacts,
    );
  }
}

class _CodeSizeVisitor extends RecursiveAstVisitor<void> {
  final AnalysisFileContext _context;
  final List<CodeSizeArtifact> artifacts = <CodeSizeArtifact>[];

  String? _currentClassName;

  _CodeSizeVisitor(this._context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previousClass = _currentClassName;
    // ignore: deprecated_member_use
    final className = node.name.lexeme;
    _currentClassName = className;
    _addArtifact(
      kind: CodeSizeArtifactKind.classDeclaration,
      name: className,
      node: node,
    );
    super.visitClassDeclaration(node);
    _currentClassName = previousClass;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addArtifact(
      kind: CodeSizeArtifactKind.function,
      name: node.name.lexeme,
      node: node,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addArtifact(
      kind: CodeSizeArtifactKind.method,
      name: node.name.lexeme,
      node: node,
      ownerName: _currentClassName,
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final className = _currentClassName ?? 'unknown';
    final constructorName = node.name?.lexeme;
    final displayName = constructorName == null || constructorName.isEmpty
        ? className
        : '$className.$constructorName';
    _addArtifact(
      kind: CodeSizeArtifactKind.method,
      name: displayName,
      node: node,
      ownerName: className,
    );
    super.visitConstructorDeclaration(node);
  }

  /// Adds a code-size artifact for [node] when its non-empty LOC is positive.
  ///
  /// Line numbers come from analyzer line info and are stored as inclusive
  /// start/end boundaries for reporting and visualization output.
  void _addArtifact({
    required CodeSizeArtifactKind kind,
    required String name,
    required AstNode node,
    String? ownerName,
  }) {
    final lineInfo = _context.parseResult.lineInfo;
    final startLine = lineInfo.getLocation(node.offset).lineNumber;
    final endOffset = node.end > node.offset ? node.end - 1 : node.offset;
    final endLine = lineInfo.getLocation(endOffset).lineNumber;
    final loc = _countNonEmptyLines(startLine: startLine, endLine: endLine);
    if (loc <= 0) {
      return;
    }

    artifacts.add(
      CodeSizeArtifact(
        kind: kind,
        name: name,
        filePath: _context.file.path,
        linesOfCode: loc,
        startLine: startLine,
        endLine: endLine,
        ownerName: ownerName,
      ),
    );
  }

  /// Counts non-empty lines between [startLine] and [endLine], inclusive.
  ///
  /// The range is clamped to available source lines to keep counting robust
  /// for partially malformed nodes.
  int _countNonEmptyLines({required int startLine, required int endLine}) {
    if (_context.lines.isEmpty) {
      return 0;
    }
    final clampedStart = startLine.clamp(1, _context.lines.length);
    final clampedEnd = endLine.clamp(clampedStart, _context.lines.length);
    var count = 0;
    for (var index = clampedStart - 1; index <= clampedEnd - 1; index++) {
      if (_context.lines[index].trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }
}
