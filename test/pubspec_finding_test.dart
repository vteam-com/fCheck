import 'dart:io';
import 'package:fcheck/fcheck.dart';
import 'package:test/test.dart';

void main() {
  group('pubspec.yaml finding', () {
    late Directory tempDir;
    late Directory projectRoot;
    late Directory subDir1;
    late Directory subDir2;

    setUp(() async {
      // Create a temporary directory structure for testing
      tempDir = await Directory.systemTemp.createTemp('fcheck_test_');
      projectRoot = Directory('${tempDir.path}/project');
      subDir1 = Directory('${projectRoot.path}/lib/subdir1');
      subDir2 = Directory('${subDir1.path}/subdir2');

      // Create directory structure
      await subDir2.create(recursive: true);

      // Create a pubspec.yaml in the project root
      final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_project
version: 1.2.3
environment:
  sdk: '>=2.17.0 <4.0.0'
''');

      // Create a simple Dart file in the deepest subdirectory
      final dartFile = File('${subDir2.path}/test.dart');
      await dartFile.writeAsString('''
void main() {
  print('Hello, World!');
}
''');
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should find pubspec.yaml when analyzing from project root', () {
      final analyzer = AnalyzeFolder(projectRoot);
      final metrics = analyzer.analyze();

      expect(metrics.projectName, equals('test_project'));
      expect(metrics.version, equals('1.2.3'));
    });

    test('should find pubspec.yaml when analyzing from subdirectory', () {
      final analyzer = AnalyzeFolder(subDir1);
      final metrics = analyzer.analyze();

      expect(metrics.projectName, equals('test_project'));
      expect(metrics.version, equals('1.2.3'));
    });

    test(
        'should find pubspec.yaml when analyzing from deep nested subdirectory',
        () {
      final analyzer = AnalyzeFolder(subDir2);
      final metrics = analyzer.analyze();

      expect(metrics.projectName, equals('test_project'));
      expect(metrics.version, equals('1.2.3'));
    });

    test('should return unknown when no pubspec.yaml exists', () async {
      // Create a directory structure without pubspec.yaml
      final noPubspecDir = Directory('${tempDir.path}/no_pubspec');
      await noPubspecDir.create();

      final dartFile = File('${noPubspecDir.path}/test.dart');
      await dartFile.writeAsString('void main() {}');

      final analyzer = AnalyzeFolder(noPubspecDir);
      final metrics = analyzer.analyze();

      expect(metrics.projectName, equals('unknown'));
      expect(metrics.version, equals('unknown'));

      // Clean up
      await noPubspecDir.delete(recursive: true);
    });

    test('should respect guardrails and not traverse too far up', () async {
      // Create a directory structure deeper than maxParentLevels (10)
      Directory currentDir = tempDir; // Start from temp dir (no pubspec.yaml)
      for (int i = 0; i < 15; i++) {
        currentDir = Directory('${currentDir.path}/level$i');
        await currentDir.create();
      }

      // Add a dart file to the deepest level
      final dartFile = File('${currentDir.path}/deep.dart');
      await dartFile.writeAsString('void main() {}');

      final analyzer = AnalyzeFolder(currentDir);
      final metrics = analyzer.analyze();

      // Should return unknown since there's no pubspec.yaml within the guardrail limit
      expect(metrics.projectName, equals('unknown'));
      expect(metrics.version, equals('unknown'));
    });
  });
}
