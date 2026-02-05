import 'dart:io';
import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:test/test.dart';

void main() {
  group('LayersAnalyzer', () {
    late Directory tempDir;
    late LayersAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('layers_test_');
      analyzer = LayersAnalyzer(
        tempDir,
        projectRoot: tempDir,
        packageName: 'unknown',
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should detect no issues in empty directory', () {
      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isEmpty);
    });

    test('should detect no issues in simple dependency', () {
      // Create file A that imports file B
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync('import "b.dart";');

      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync('class B {}');

      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isEmpty);
    });

    test('should detect cyclic dependency', () {
      // Create files with cyclic dependency: A -> B -> A
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync('import "b.dart";');

      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync('import "a.dart";');

      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isNotEmpty);
      expect(result.issues.length, greaterThanOrEqualTo(1));
      expect(
          result.issues.first.type, equals(LayersIssueType.cyclicDependency));
    });

    test('should handle package imports', () {
      // Create file that imports from package
      final file = File('${tempDir.path}/main.dart');
      file.writeAsStringSync('import "package:flutter/material.dart";');

      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isEmpty);
    });

    test('should handle relative imports with parent directory', () {
      // Create subdirectory structure
      final subDir = Directory('${tempDir.path}/lib');
      subDir.createSync();

      final fileA = File('${subDir.path}/a.dart');
      fileA.writeAsStringSync('import "../utils.dart";');

      final fileUtils = File('${tempDir.path}/utils.dart');
      fileUtils.writeAsStringSync('class Utils {}');

      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isEmpty);
    });

    test('should handle package imports within the same package', () {
      // Create lib directory and files
      final libDir = Directory('${tempDir.path}/lib');
      libDir.createSync();

      final fileA = File('${libDir.path}/a.dart');
      fileA.writeAsStringSync('import "package:test_package/b.dart";');

      final fileB = File('${libDir.path}/b.dart');
      fileB.writeAsStringSync('class B {}');

      // Provide package name from entry point.
      final analyzer = LayersAnalyzer(
        tempDir,
        projectRoot: tempDir,
        packageName: 'test_package',
      );
      final result = analyzer.analyzeDirectory(tempDir);
      expect(result.issues, isEmpty);
      expect(result.dependencyGraph[fileA.path], contains(fileB.path));
    });
    test('should assign correct layers in a chain', () {
      // Create chain: a.dart (entry) -> b.dart -> c.dart
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync('import "b.dart";\nvoid main() { print("A"); }');

      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync('import "c.dart";');

      final fileC = File('${tempDir.path}/c.dart');
      fileC.writeAsStringSync('class C {}');

      final result = analyzer.analyzeDirectory(tempDir);

      expect(result.layers[fileA.path], equals(1));
      expect(result.layers[fileB.path], equals(2));
      expect(result.layers[fileC.path], equals(3));
    });
  });
}
