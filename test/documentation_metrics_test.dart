import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:test/test.dart';

void main() {
  test('documentation issues participate in compliance focus area', () {
    final metrics = ProjectMetrics(
      totalFolders: 1,
      totalFiles: 1,
      totalDartFiles: 1,
      totalLinesOfCode: 40,
      totalCommentLines: 4,
      fileMetrics: [
        FileMetrics(
          path: 'lib/main.dart',
          linesOfCode: 40,
          commentLines: 4,
          classCount: 1,
          isStatefulWidget: false,
        ),
      ],
      secretIssues: const [],
      hardcodedStringIssues: const [],
      magicNumberIssues: const [],
      sourceSortIssues: const [],
      layersIssues: const [],
      deadCodeIssues: const [],
      duplicateCodeIssues: const [],
      documentationIssues: const [
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedPublicClass,
          filePath: 'lib/main.dart',
          lineNumber: 2,
          subject: 'App',
        ),
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedPublicFunction,
          filePath: 'lib/main.dart',
          lineNumber: 10,
          subject: 'runApp',
        ),
      ],
      layersEdgeCount: 0,
      layersCount: 0,
      dependencyGraph: const {},
      projectName: 'example',
      version: '1.0.0',
      projectType: ProjectType.dart,
      documentationAnalyzerEnabled: true,
    );

    expect(metrics.complianceFocusAreaKey, equals('documentation'));
    expect(metrics.complianceFocusAreaIssueCount, equals(2));
  });
}
