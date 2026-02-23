import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:test/test.dart';

void main() {
  group('CodeSizeArtifactKind', () {
    test('exposes stable labels for all artifact kinds', () {
      expect(CodeSizeArtifactKind.file.label, equals('file'));
      expect(CodeSizeArtifactKind.classDeclaration.label, equals('class'));
      expect(CodeSizeArtifactKind.function.label, equals('function'));
      expect(CodeSizeArtifactKind.method.label, equals('method'));
    });
  });

  group('CodeSizeArtifact', () {
    test('builds stableId from identifying fields', () {
      const artifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.method,
        name: 'save',
        filePath: 'lib/src/user_service.dart',
        linesOfCode: 12,
        startLine: 20,
        endLine: 35,
        ownerName: 'UserService',
      );

      expect(
        artifact.stableId,
        equals('lib/src/user_service.dart|method|save|20|35'),
      );
    });

    test('returns simple name when owner is null or empty', () {
      const withNullOwner = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.function,
        name: 'bootstrap',
        filePath: 'bin/main.dart',
        linesOfCode: 4,
        startLine: 1,
        endLine: 4,
      );
      const withEmptyOwner = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.method,
        name: 'build',
        filePath: 'lib/view.dart',
        linesOfCode: 8,
        startLine: 10,
        endLine: 17,
        ownerName: '',
      );

      expect(withNullOwner.qualifiedName, equals('bootstrap'));
      expect(withEmptyOwner.qualifiedName, equals('build'));
    });

    test('prefixes name with owner when owner is present', () {
      const artifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.method,
        name: 'render',
        filePath: 'lib/app_view.dart',
        linesOfCode: 22,
        startLine: 30,
        endLine: 51,
        ownerName: 'AppView',
      );

      expect(artifact.qualifiedName, equals('AppView.render'));
    });

    test('marks only function and method artifacts as callable', () {
      const fileArtifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.file,
        name: 'main.dart',
        filePath: 'lib/main.dart',
        linesOfCode: 100,
        startLine: 1,
        endLine: 100,
      );
      const classArtifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.classDeclaration,
        name: 'HomePage',
        filePath: 'lib/home_page.dart',
        linesOfCode: 42,
        startLine: 3,
        endLine: 44,
      );
      const functionArtifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.function,
        name: 'bootstrap',
        filePath: 'bin/main.dart',
        linesOfCode: 6,
        startLine: 1,
        endLine: 6,
      );
      const methodArtifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.method,
        name: 'dispose',
        filePath: 'lib/home_page.dart',
        linesOfCode: 5,
        startLine: 60,
        endLine: 64,
        ownerName: 'HomePage',
      );

      expect(fileArtifact.isCallable, isFalse);
      expect(classArtifact.isCallable, isFalse);
      expect(functionArtifact.isCallable, isTrue);
      expect(methodArtifact.isCallable, isTrue);
    });

    test('serializes to JSON with ownerName when provided', () {
      const artifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.method,
        name: 'render',
        filePath: 'lib/app_view.dart',
        linesOfCode: 22,
        startLine: 30,
        endLine: 51,
        ownerName: 'AppView',
      );

      expect(artifact.toJson(), {
        'kind': 'method',
        'name': 'render',
        'qualifiedName': 'AppView.render',
        'filePath': 'lib/app_view.dart',
        'linesOfCode': 22,
        'startLine': 30,
        'endLine': 51,
        'ownerName': 'AppView',
      });
    });

    test('serializes to JSON without ownerName when omitted', () {
      const artifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.function,
        name: 'bootstrap',
        filePath: 'bin/main.dart',
        linesOfCode: 4,
        startLine: 1,
        endLine: 4,
      );

      expect(artifact.toJson(), {
        'kind': 'function',
        'name': 'bootstrap',
        'qualifiedName': 'bootstrap',
        'filePath': 'bin/main.dart',
        'linesOfCode': 4,
        'startLine': 1,
        'endLine': 4,
      });
    });
  });
}
