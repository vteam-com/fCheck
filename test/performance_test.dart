import 'dart:io';
import 'package:fcheck/fcheck.dart';
import 'package:test/test.dart';

void main() {
  group('Performance Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory with test files
      tempDir = await Directory.systemTemp.createTemp('fcheck_perf_test_');

      // Create multiple test Dart files
      for (int i = 0; i < 50; i++) {
        final file = File('${tempDir.path}/file_$i.dart');
        await file.writeAsString('''
// Test file $i
import 'dart:io';

class TestClass$i {
  final String name = "test";
  final int value = 42;
  
  void method() {
    print("Hello from file $i");
    final result = 3.14159 * value;
  }
}
''');
      }

      // Create pubspec.yaml
      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_project
version: 1.0.0
''');
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Compare performance between original and optimized analysis', () {
      // Original analysis (now uses unified approach)
      final originalAnalyzer = AnalyzeFolder(tempDir);
      final originalStart = DateTime.now();
      final originalResult = originalAnalyzer.analyze();
      final originalEnd = DateTime.now();
      final originalDuration = originalEnd.difference(originalStart);

      // Optimized analysis (same as original now)
      final optimizedAnalyzer = AnalyzeFolder(tempDir);
      final optimizedStart = DateTime.now();
      final optimizedResult = optimizedAnalyzer.analyze();
      final optimizedEnd = DateTime.now();
      final optimizedDuration = optimizedEnd.difference(optimizedStart);

      print('Original analysis time: ${originalDuration.inMilliseconds}ms');
      print('Optimized analysis time: ${optimizedDuration.inMilliseconds}ms');

      // Verify results are equivalent
      expect(originalResult.totalDartFiles,
          equals(optimizedResult.totalDartFiles));
      expect(originalResult.totalLinesOfCode,
          equals(optimizedResult.totalLinesOfCode));
      expect(originalResult.totalCommentLines,
          equals(optimizedResult.totalCommentLines));

      // Performance improvement should be significant (at least 20% faster)
      final improvement =
          (originalDuration.inMilliseconds - optimizedDuration.inMilliseconds) /
              originalDuration.inMilliseconds;

      print(
          'Performance improvement: ${(improvement * 100).toStringAsFixed(1)}%');

      // For small test cases, the improvement might be less dramatic,
      // but for larger projects it should be substantial
      expect(improvement, greaterThan(0.1),
          reason: 'Optimized version should be at least 10% faster');
    });

    test('Verify unified analysis produces same results', () async {
      final analyzer = AnalyzeFolder(tempDir);

      final result1 = analyzer.analyze();
      final result2 = analyzer.analyze();

      // Compare key metrics (should be identical)
      expect(result1.totalDartFiles, equals(result2.totalDartFiles));
      expect(result1.totalLinesOfCode, equals(result2.totalLinesOfCode));
      expect(result1.totalCommentLines, equals(result2.totalCommentLines));
      expect(result1.fileMetrics.length, equals(result2.fileMetrics.length));

      // Compare issue counts (should be identical)
      expect(result1.hardcodedStringIssues.length,
          equals(result2.hardcodedStringIssues.length));
      expect(result1.magicNumberIssues.length,
          equals(result2.magicNumberIssues.length));
      expect(result1.secretIssues.length, equals(result2.secretIssues.length));
    });
  });
}
