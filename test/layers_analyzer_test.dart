import 'dart:io';
import 'package:fcheck/src/layers/layers_analyzer.dart';
import 'package:fcheck/src/layers/layers_issue.dart';
import 'package:test/test.dart';

void main() {
  group('LayersAnalyzer', () {
    late Directory tempDir;
    late LayersAnalyzer analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('layers_test_');
      analyzer = LayersAnalyzer();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should detect no issues in empty directory', () {
      final issues = analyzer.analyzeDirectory(tempDir);
      expect(issues, isEmpty);
    });

    test('should detect no issues in simple dependency', () {
      // Create file A that imports file B
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync('import "b.dart";');

      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync('class B {}');

      final issues = analyzer.analyzeDirectory(tempDir);
      expect(issues, isEmpty);
    });

    test('should detect cyclic dependency', () {
      // Create files with cyclic dependency: A -> B -> A
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync('import "b.dart";');

      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync('import "a.dart";');

      final issues = analyzer.analyzeDirectory(tempDir);
      expect(issues, isNotEmpty);
      expect(issues.length, greaterThanOrEqualTo(1));
      expect(issues.first.type, equals(LayersIssueType.cyclicDependency));
    });

    test('should handle package imports', () {
      // Create file that imports from package
      final file = File('${tempDir.path}/main.dart');
      file.writeAsStringSync('import "package:flutter/material.dart";');

      final issues = analyzer.analyzeDirectory(tempDir);
      expect(issues, isEmpty);
    });

    test('should handle relative imports with parent directory', () {
      // Create subdirectory structure
      final subDir = Directory('${tempDir.path}/lib');
      subDir.createSync();

      final fileA = File('${subDir.path}/a.dart');
      fileA.writeAsStringSync('import "../utils.dart";');

      final fileUtils = File('${tempDir.path}/utils.dart');
      fileUtils.writeAsStringSync('class Utils {}');

      final issues = analyzer.analyzeDirectory(tempDir);
      expect(issues, isEmpty);
    });
  });
}
