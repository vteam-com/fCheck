import 'dart:io';

import 'package:fcheck/src/analyzers/documentation/documentation_analyzer.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentationAnalyzer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_docs_analyzer_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('adds README issue when README.md is missing', () {
      final analyzer = DocumentationAnalyzer(projectRoot: tempDir);

      final issues = analyzer.analyze(const []);

      expect(issues.length, equals(1));
      expect(issues.first.type, equals(DocumentationIssueType.missingReadme));
      expect(issues.first.subject, equals('README.md'));
    });

    test('does not add README issue when README.md exists', () {
      File('${tempDir.path}/README.md').writeAsStringSync('# Test Project');
      final analyzer = DocumentationAnalyzer(projectRoot: tempDir);

      final issues = analyzer.analyze(const []);

      expect(issues, isEmpty);
    });

    test('keeps per-file issues and sorts deterministically', () {
      final analyzer = DocumentationAnalyzer(projectRoot: tempDir);
      final inputIssues = [
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedPublicFunction,
          filePath: 'lib/b.dart',
          lineNumber: 8,
          subject: 'runB',
        ),
        DocumentationIssue(
          type: DocumentationIssueType.undocumentedPublicClass,
          filePath: 'lib/a.dart',
          lineNumber: 4,
          subject: 'A',
        ),
      ];

      final issues = analyzer.analyze(inputIssues);

      expect(issues.length, equals(3));
      expect(issues[0].type, equals(DocumentationIssueType.missingReadme));
      expect(
        issues[1].type,
        equals(DocumentationIssueType.undocumentedPublicClass),
      );
      expect(
        issues[2].type,
        equals(DocumentationIssueType.undocumentedPublicFunction),
      );
    });
  });
}
