import 'package:analyzer/dart/ast/ast.dart';

/// Utility for detecting ignore directives in Dart files.
class IgnoreConfig {
  /// `// ignore: fcheck_layers` directive used to skip layers checks.
  static const String ignoreDirectiveForLayers = '// ignore: fcheck_layers';

  /// `// ignore: fcheck_hardcoded_strings` directive used to skip checks.
  static const String ignoreDirectiveForHardcodedStrings =
      '// ignore: fcheck_hardcoded_strings';

  /// `// ignore: fcheck_magic_numbers` directive used to skip checks.
  static const String ignoreDirectiveForMagicNumbers =
      '// ignore: fcheck_magic_numbers';

  /// `// ignore: fcheck_secrets` directive used to skip secret scans.
  static const String ignoreDirectiveForSecrets = '// ignore: fcheck_secrets';

  /// `// ignore: fcheck_dead_code` directive used to skip dead code checks.
  static const String ignoreDirectiveForDeadCode =
      '// ignore: fcheck_dead_code';

  /// `// ignore: fcheck_duplicate_code` directive used to skip checks.
  static const String ignoreDirectiveForDuplicateCode =
      '// ignore: fcheck_duplicate_code';

  /// `// ignore: fcheck_one_class_per_file` directive used to skip checks.
  static const String ignoreDirectiveForOneClassPerFile =
      '// ignore: fcheck_one_class_per_file';

  /// `// ignore_for_file: avoid_hardcoded_strings_in_widgets` directive.
  static const String ignoreForFileDirectiveForHardcodedStrings =
      '// ignore_for_file: avoid_hardcoded_strings_in_widgets';

  static final RegExp _lineIgnorePattern = RegExp(
    r'^\s*ignore\s*:\s*(.+)$',
    caseSensitive: false,
  );
  static const int _lineCommentPrefixLength = 2;
  static final RegExp _fcheckDirectiveTokenPattern = RegExp(
    r'\bfcheck_[a-z_]+\b',
    caseSensitive: false,
  );

  /// Checks for a top-of-file ignore directive matching [expectedComment].
  ///
  /// The directive must appear in the leading comment block(s) at the top of
  /// the file (before any code). Pass the full expected line, for example:
  /// - `// ignore: fcheck_magic_numbers`
  /// - `// ignore_for_file: avoid_hardcoded_strings_in_widgets`
  static bool hasIgnoreForFileDirective(
    String content,
    String expectedComment,
  ) {
    final trimmed = expectedComment.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final directivePattern = RegExp(
      _buildExpectedCommentPattern(trimmed),
      caseSensitive: false,
      multiLine: true,
    );

    final commentBlock = _collectLeadingCommentBlock(content);
    return directivePattern.hasMatch(commentBlock);
  }

  /// Counts `// ignore: fcheck_*` directives in [content].
  ///
  /// This includes both top-of-file and inline ignore comments.
  /// If a single ignore line contains multiple `fcheck_*` tokens, each token
  /// contributes to the count.
  static int countFcheckIgnoreDirectives(String content) {
    var count = 0;
    final lines = content.split('\n');
    for (final line in lines) {
      final commentStart = line.indexOf('//');
      if (commentStart < 0) {
        continue;
      }

      final comment = line.substring(commentStart + _lineCommentPrefixLength);
      final match = _lineIgnorePattern.firstMatch(comment);
      if (match == null) {
        continue;
      }

      final directives = match.group(1) ?? '';
      count += _fcheckDirectiveTokenPattern.allMatches(directives).length;
    }
    return count;
  }

  static String _buildExpectedCommentPattern(String expectedComment) {
    var working = expectedComment;
    if (working.startsWith('//')) {
      working = working.substring(_lineCommentPrefixLength);
    }
    working = working.trimLeft();

    final buffer = StringBuffer(r'^\s*//\s*');
    for (var i = 0; i < working.length; i++) {
      final ch = working[i];
      if (ch.trim().isEmpty) {
        buffer.write(r'\s*');
        continue;
      }
      if (ch == ':') {
        buffer.write(r'\s*:\s*');
        continue;
      }
      buffer.write(RegExp.escape(ch));
    }
    buffer.write(r'\s*$');
    return buffer.toString();
  }

  static String _collectLeadingCommentBlock(String content) {
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

    return buffer.toString();
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
