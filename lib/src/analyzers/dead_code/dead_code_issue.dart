import 'dart:io';

import 'package:fcheck/src/input_output/issue_location_utils.dart';

/// The type of dead code issue detected.
enum DeadCodeIssueType {
  /// A file that is not reachable from any entry point.
  deadFile,

  /// A class declaration that is never referenced.
  deadClass,

  /// A function or method declaration that is never referenced.
  deadFunction,

  /// A local variable or parameter that is never referenced.
  unusedVariable,
}

/// Represents a dead code finding.
class DeadCodeIssue {
  static const int _ansiOrange = 208;
  static const Map<DeadCodeIssueType, String> _typeLabelsByIssueType = {
    DeadCodeIssueType.deadFile: 'dead file',
    DeadCodeIssueType.deadClass: 'dead class',
    DeadCodeIssueType.deadFunction: 'dead function',
    DeadCodeIssueType.unusedVariable: 'unused variable',
  };

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
  String get typeLabel => _typeLabelsByIssueType[type]!;

  @override
  String toString() => format();

  /// Returns a formatted issue line for CLI output.
  String format({int? lineNumberWidth}) =>
      _formatDetails(includeTypeLabel: true, lineNumberWidth: lineNumberWidth);

  /// Returns issue text for grouped dead-code sections.
  ///
  /// Group headings already describe the category, so this variant omits
  /// the repeated type label for each item.
  String formatGrouped({int? lineNumberWidth}) =>
      _formatDetails(includeTypeLabel: false, lineNumberWidth: lineNumberWidth);

  /// Formats dead-code issue details with or without the type label prefix.
  String _formatDetails({
    required bool includeTypeLabel,
    int? lineNumberWidth,
  }) {
    assertValidLineNumberWidth(lineNumberWidth);

    final location = _formatLocation();
    final ownerSuffix = owner == null || owner!.isEmpty ? '' : ' in $owner';
    if (name.isEmpty) {
      if (includeTypeLabel) {
        return '$location: $typeLabel$ownerSuffix';
      }
      return ownerSuffix.isEmpty ? location : '$location:$ownerSuffix';
    }

    final displayName = _formatName();
    if (includeTypeLabel) {
      return '$location: $typeLabel $displayName$ownerSuffix';
    }
    return '$location: $displayName$ownerSuffix';
  }

  /// Internal helper used by fcheck analysis and reporting.
  String _formatLocation() {
    return resolveIssueLocation(
      rawPath: filePath,
      lineNumber: lineNumber,
      strictPositiveLineNumber: true,
    );
  }

  /// Internal helper used by fcheck analysis and reporting.
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

  /// Internal helper used by fcheck analysis and reporting.
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
