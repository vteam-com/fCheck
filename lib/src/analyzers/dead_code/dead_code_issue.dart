import 'dart:io';

/// The type of dead code issue detected.
enum DeadCodeIssueType {
  /// A file that is not reachable from any entry point.
  deadFile,

  /// A class declaration that is never referenced.
  deadClass,

  /// A top-level function declaration that is never referenced.
  deadFunction,

  /// A local variable or parameter that is never referenced.
  unusedVariable,
}

/// Represents a dead code finding.
class DeadCodeIssue {
  static const int _ansiOrange = 208;

  /// The type of dead code detected.
  final DeadCodeIssueType type;

  /// The file path where the issue was detected.
  final String filePath;

  /// Optional line number for the issue location (1-based).
  final int? lineNumber;

  /// Name of the declaration or symbol.
  final String name;

  /// Optional owner context (e.g., function or class name for variables).
  final String? owner;

  /// Creates a new dead code issue.
  DeadCodeIssue({
    required this.type,
    required this.filePath,
    required this.name,
    this.lineNumber,
    this.owner,
  });

  /// Human-readable label for the issue type.
  String get typeLabel {
    switch (type) {
      case DeadCodeIssueType.deadFile:
        return 'dead file';
      case DeadCodeIssueType.deadClass:
        return 'dead class';
      case DeadCodeIssueType.deadFunction:
        return 'dead function';
      case DeadCodeIssueType.unusedVariable:
        return 'unused variable';
    }
  }

  @override
  String toString() => format();

  /// Returns a formatted issue line for CLI output.
  String format({int? lineNumberWidth}) {
    final formattedLineNumber = lineNumber != null && lineNumber! > 0
        ? (lineNumberWidth == null
            ? '$lineNumber'
            : lineNumber!.toString().padLeft(lineNumberWidth))
        : null;
    final location = formattedLineNumber == null
        ? filePath
        : '$filePath:$formattedLineNumber';
    final ownerSuffix = owner == null || owner!.isEmpty ? '' : ' in $owner';
    if (name.isEmpty) {
      return '$location: $typeLabel$ownerSuffix';
    }
    final displayName = _formatName();
    return '$location: $typeLabel $displayName$ownerSuffix';
  }

  String _formatName() {
    if (name.isEmpty) {
      return name;
    }
    switch (type) {
      case DeadCodeIssueType.deadFunction:
        return _formatSymbol('$name(...)');
      case DeadCodeIssueType.deadClass:
      case DeadCodeIssueType.unusedVariable:
        return _formatSymbol(name);
      case DeadCodeIssueType.deadFile:
        return name;
    }
  }

  String _formatSymbol(String value) => _colorize('"$value"');

  String _colorize(String text) {
    if (!stdout.supportsAnsiEscapes) {
      return text;
    }
    return '\x1B[1;38;5;${_ansiOrange}m$text\x1B[0m';
  }

  /// Converts this issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'name': name,
        'owner': owner,
      };
}
