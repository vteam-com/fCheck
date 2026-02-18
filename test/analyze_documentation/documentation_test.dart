import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_analyzer.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_delegate.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:test/test.dart';

AnalysisFileContext _contextForFile(File file) {
  final content = file.readAsStringSync();
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return AnalysisFileContext(
    file: file,
    content: content,
    parseResult: parseResult,
    lines: content.split('\n'),
    compilationUnit: parseResult.unit,
    hasParseErrors: parseResult.errors.isNotEmpty,
  );
}

List<DocumentationIssue> _analyzeFile(
  DocumentationDelegate delegate,
  File file,
) {
  return delegate.analyzeFileWithContext(_contextForFile(file));
}

void main() {
  group('DocumentationIssue', () {
    test('formats with line number when present', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedPublicFunction,
        filePath: 'lib/main.dart',
        lineNumber: 12,
        subject: 'runApp',
      );

      expect(
        issue.format(),
        equals(
          'lib/main.dart:12: public function is missing documentation "runApp"',
        ),
      );
    });

    test('serializes toJson with all fields', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.missingReadme,
        filePath: '/project/README.md',
        subject: 'README.md',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'missingReadme',
          'filePath': '/project/README.md',
          'lineNumber': null,
          'subject': 'README.md',
        }),
      );
    });

    test('normalizes duplicated path prefixes in format output', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedComplexPrivateFunction,
        filePath:
            'lib/src/analyzers/magic_numbers/magic_number_visitor.dart:lib/src/analyzers/magic_numbers/magic_number_visitor.dart',
        subject: 'MagicNumberVisitor._inspectLiteral',
      );

      expect(
        issue.format(),
        equals(
          'lib/src/analyzers/magic_numbers/magic_number_visitor.dart: complex private function is missing documentation "MagicNumberVisitor._inspectLiteral"',
        ),
      );
    });

    test('uses embedded line from file path when lineNumber is null', () {
      final issue = DocumentationIssue(
        type: DocumentationIssueType.undocumentedPublicFunction,
        filePath: 'lib/main.dart:44',
        subject: 'runApp',
      );

      expect(
        issue.format(),
        equals(
          'lib/main.dart:44: public function is missing documentation "runApp"',
        ),
      );
    });
  });

  group('DocumentationDelegate', () {
    late DocumentationDelegate delegate;
    late Directory tempDir;

    setUp(() {
      delegate = DocumentationDelegate();
      tempDir = Directory.systemTemp.createTempSync('fcheck_documentation_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('flags undocumented public classes', () {
      final file = File('${tempDir.path}/public_class.dart')
        ..writeAsStringSync('''
class PublicService {
  /// Existing docs for method.
  void call() {}
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(
        issues.first.type,
        equals(DocumentationIssueType.undocumentedPublicClass),
      );
      expect(issues.first.subject, equals('PublicService'));
    });

    test('flags undocumented public functions', () {
      final file = File('${tempDir.path}/public_function.dart')
        ..writeAsStringSync('''
/// Existing docs for class.
class Service {
  /// Existing docs for method.
  void call() {}
}

void runApp() {}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(
        issues.first.type,
        equals(DocumentationIssueType.undocumentedPublicFunction),
      );
      expect(issues.first.subject, equals('runApp'));
    });

    test('flags complex undocumented private functions', () {
      final file = File('${tempDir.path}/private_complex.dart')
        ..writeAsStringSync('''
/// Existing docs for class.
class Service {
  /// Existing docs for method.
  void execute() {
    _compute();
  }

  int _compute() {
    var total = 0;
    for (var i = 0; i < 6; i++) {
      if (i.isEven) {
        total += i;
      } else {
        total -= i;
      }
    }
    return total;
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(
        issues.first.type,
        equals(DocumentationIssueType.undocumentedComplexPrivateFunction),
      );
      expect(issues.first.subject, equals('Service._compute'));
    });

    test('allows short self-explanatory private functions', () {
      final file = File('${tempDir.path}/private_short.dart')
        ..writeAsStringSync('''
/// Existing docs for class.
class Service {
  /// Existing docs for method.
  int execute(int value) => _id(value);

  int _id(int value) => value;
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('supports top-of-file ignore directive', () {
      final file = File('${tempDir.path}/ignored_file.dart')
        ..writeAsStringSync('''
// ignore: fcheck_documentation
class PublicService {
  void call() {}
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('supports node-level ignore directive', () {
      final file = File('${tempDir.path}/ignored_node.dart')
        ..writeAsStringSync('''
void runApp() {} // ignore: fcheck_documentation
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });
  });

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

  group('Documentation metrics', () {
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
  });
}
