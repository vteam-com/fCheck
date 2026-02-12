import 'dart:io';

import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:path/path.dart' as p;

/// Aggregates project-level documentation requirements.
class DocumentationAnalyzer {
  /// Creates a documentation analyzer for [projectRoot].
  DocumentationAnalyzer({required this.projectRoot});

  /// Project root directory that must contain `README.md`.
  final Directory projectRoot;

  /// Returns merged per-file and project-level documentation issues.
  List<DocumentationIssue> analyze(List<DocumentationIssue> fileIssues) {
    final issues = <DocumentationIssue>[
      ...fileIssues,
      ..._collectProjectIssues(),
    ];

    issues.sort(_compareIssues);
    return issues;
  }

  /// Internal helper used by fcheck analysis and reporting.
  List<DocumentationIssue> _collectProjectIssues() {
    final readmeFile = File(p.join(projectRoot.path, 'README.md'));
    if (readmeFile.existsSync()) {
      return const <DocumentationIssue>[];
    }

    return <DocumentationIssue>[
      DocumentationIssue(
        type: DocumentationIssueType.missingReadme,
        filePath: readmeFile.path,
        subject: 'README.md',
      ),
    ];
  }

  /// Internal helper used by fcheck analysis and reporting.
  int _compareIssues(DocumentationIssue left, DocumentationIssue right) {
    final typeCompare = left.type.index.compareTo(right.type.index);
    if (typeCompare != 0) {
      return typeCompare;
    }

    final pathCompare = left.filePath.compareTo(right.filePath);
    if (pathCompare != 0) {
      return pathCompare;
    }

    final lineCompare = (left.lineNumber ?? 0).compareTo(right.lineNumber ?? 0);
    if (lineCompare != 0) {
      return lineCompare;
    }

    return left.subject.compareTo(right.subject);
  }
}
