import 'package:analyzer/dart/ast/ast.dart';

/// Utility for detecting ignore directives in Dart files.
class IgnoreConfig {
  /// Checks if a file should be ignored based on comment directives.
  ///
  /// This method checks for ignore patterns in the leading comment block
  /// of the file. The pattern should be: `// ignore: fcheck_<domain>`
  ///
  /// [content] The raw content of the file to check.
  /// [domain] The specific domain to check for (e.g., 'magic_numbers').
  ///
  /// Returns true if the file contains an ignore directive for the specified domain.
  static bool hasIgnoreDirective(String content, String domain) {
    // Check for the new format: // ignore: fcheck_<domain>
    final directivePattern = RegExp(
      r'^\s*//\s*ignore:\s*fcheck_' + domain + r'\s*$',
      caseSensitive: false,
      multiLine: true,
    );

    final lines = content.split('\n');
    final buffer = StringBuffer();
    bool inBlockComment = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();

      /// Length of the block comment terminator "*/".
      const int blockCommentEndLength = 2;

      if (inBlockComment) {
        buffer.writeln(trimmed);
        final endIndex = trimmed.indexOf('*/');
        if (endIndex != -1) {
          inBlockComment = false;
          final after =
              trimmed.substring(endIndex + blockCommentEndLength).trim();
          if (after.isNotEmpty) {
            break;
          }
        }
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith('//')) {
        buffer.writeln(trimmed);
        continue;
      }

      if (trimmed.startsWith('/*')) {
        buffer.writeln(trimmed);
        if (!trimmed.contains('*/')) {
          inBlockComment = true;
        } else {
          final after = trimmed.split('*/').last.trim();
          if (after.isNotEmpty) {
            break;
          }
        }
        continue;
      }

      break;
    }

    return directivePattern.hasMatch(buffer.toString());
  }

  /// Checks if a specific AST node is within an ignored section.
  ///
  /// This method traverses up the AST to check if any parent node is within
  /// an ignored section based on comment directives.
  ///
  /// [node] The AST node to check.
  /// [content] The raw content of the file.
  /// [domain] The specific domain to check for.
  ///
  /// Returns true if the node or any of its parents are within an ignored section.
  static bool isNodeIgnored(AstNode node, String content, String domain) {
    AstNode? current = node;
    while (current != null) {
      final offset = current.offset;
      final lineNumber = _getLineNumber(content, offset);
      final lineContent = _getLineContent(content, lineNumber);

      if (lineContent.contains('// ignore: fcheck_$domain')) {
        return true;
      }

      current = current.parent;
    }
    return false;
  }

  /// Calculates the 1-based line number for a given character offset.
  static int _getLineNumber(String content, int offset) {
    final lines = content.substring(0, offset).split('\n');
    return lines.length;
  }

  /// Retrieves the content of a specific line number.
  static String _getLineContent(String content, int lineNumber) {
    final lines = content.split('\n');
    if (lineNumber > 0 && lineNumber <= lines.length) {
      return lines[lineNumber - 1];
    }
    return '';
  }
}
