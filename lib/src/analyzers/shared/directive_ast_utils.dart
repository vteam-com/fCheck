import 'package:analyzer/dart/ast/ast.dart';

/// Returns true when [node] sits inside a directive (import/export/part/library).
///
/// Directive literals carry URIs rather than user-facing or countable content,
/// so analyzers exclude them from string and literal inventory results.
bool isInDirective(AstNode node) {
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
