import 'package:fcheck/src/input_output/issue_location_utils.dart';

/// Categories emitted by the documentation analyzer.
enum DocumentationIssueType {
  /// Project root does not contain a `README.md`.
  missingReadme,

  /// Public class declaration has no doc comment.
  undocumentedPublicClass,

  /// Public function or method has no doc comment.
  undocumentedPublicFunction,

  /// Complex private function or method has no leading comment.
  undocumentedComplexPrivateFunction,
}

/// Represents a documentation-policy violation.
class DocumentationIssue {
  /// Issue category.
  final DocumentationIssueType type;

  /// Source file path related to the issue.
  final String filePath;

  /// Optional 1-based line number.
  final int? lineNumber;

  /// Optional symbol or subject name (for example class/function/README.md).
  final String subject;

  /// Creates a new documentation issue.
  const DocumentationIssue({
    required this.type,
    required this.filePath,
    required this.subject,
    this.lineNumber,
  });

  /// Human-readable issue label used in CLI output.
  String get typeLabel {
    switch (type) {
      case DocumentationIssueType.missingReadme:
        return 'missing required project documentation';
      case DocumentationIssueType.undocumentedPublicClass:
        return 'public class is missing documentation';
      case DocumentationIssueType.undocumentedPublicFunction:
        return 'public function is missing documentation';
      case DocumentationIssueType.undocumentedComplexPrivateFunction:
        return 'complex private function is missing documentation';
    }
  }

  /// Formats this issue as a report line.
  String format({int? lineNumberWidth}) {
    assertValidLineNumberWidth(lineNumberWidth);
    final location = resolveIssueLocation(
      rawPath: filePath,
      lineNumber: lineNumber,
    );
    final subjectSuffix = subject.isEmpty ? '' : ' "$subject"';
    return '$location: $typeLabel$subjectSuffix';
  }

  @override
  String toString() => format();

  /// Converts this issue to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'subject': subject,
      };
}
