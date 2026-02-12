import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_delegate.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
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
        equals(
          DocumentationIssueType.undocumentedComplexPrivateFunction,
        ),
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
}
