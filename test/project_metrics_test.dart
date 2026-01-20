import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/models/project_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectMetrics', () {
    test('should create ProjectMetrics instance correctly', () {
      final fileMetrics = [
        FileMetrics(
          path: 'lib/example1.dart',
          linesOfCode: 50,
          commentLines: 10,
          classCount: 1,
          isStatefulWidget: false,
        ),
        FileMetrics(
          path: 'lib/example2.dart',
          linesOfCode: 30,
          commentLines: 5,
          classCount: 1,
          isStatefulWidget: false,
        ),
      ];

      final projectMetrics = ProjectMetrics(
        totalFolders: 5,
        totalFiles: 12,
        totalDartFiles: 2,
        totalLinesOfCode: 80,
        totalCommentLines: 15,
        fileMetrics: fileMetrics,
        hardcodedStringIssues: [],
      );

      expect(projectMetrics.totalFolders, equals(5));
      expect(projectMetrics.totalFiles, equals(12));
      expect(projectMetrics.totalDartFiles, equals(2));
      expect(projectMetrics.totalLinesOfCode, equals(80));
      expect(projectMetrics.totalCommentLines, equals(15));
      expect(projectMetrics.fileMetrics, equals(fileMetrics));
      expect(projectMetrics.hardcodedStringIssues, isEmpty);
    });

    test('should calculate comment ratio correctly', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 5,
        totalFiles: 12,
        totalDartFiles: 2,
        totalLinesOfCode: 100,
        totalCommentLines: 25,
        fileMetrics: [],
        hardcodedStringIssues: [],
      );

      expect(projectMetrics.commentRatio, equals(0.25));
    });

    test('should return 0 comment ratio when no lines of code', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 5,
        totalFiles: 12,
        totalDartFiles: 2,
        totalLinesOfCode: 0,
        totalCommentLines: 0,
        fileMetrics: [],
        hardcodedStringIssues: [],
      );

      expect(projectMetrics.commentRatio, equals(0.0));
    });

    test('should print report correctly', () {
      final fileMetrics = [
        FileMetrics(
          path: 'lib/compliant.dart',
          linesOfCode: 50,
          commentLines: 10,
          classCount: 1,
          isStatefulWidget: false,
        ),
        FileMetrics(
          path: 'lib/non_compliant.dart',
          linesOfCode: 50,
          commentLines: 5,
          classCount: 3,
          isStatefulWidget: false,
        ),
      ];

      final projectMetrics = ProjectMetrics(
        totalFolders: 3,
        totalFiles: 8,
        totalDartFiles: 2,
        totalLinesOfCode: 100,
        totalCommentLines: 15,
        fileMetrics: fileMetrics,
        hardcodedStringIssues: [],
      );

      // Test that printReport doesn't throw an error
      expect(() => projectMetrics.printReport(), returnsNormally);
    });
  });
}
