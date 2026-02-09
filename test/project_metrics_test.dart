import 'dart:async';

import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/metrics/project_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
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
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
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
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
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
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
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
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final output = <String>[];

      runZoned(
        () {
          projectMetrics.printReport();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );

      expect(output, isNotEmpty);
    });

    test('should omit Lists section when listMode is none', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: [
          FileMetrics(
            path: 'lib/sample.dart',
            linesOfCode: 10,
            commentLines: 0,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final output = <String>[];
      runZoned(
        () {
          projectMetrics.printReport(listMode: ReportListMode.none);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );

      expect(output.any((line) => line.contains('Lists')), isFalse);
    });

    test('should print filenames only when listMode is filenames', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: [
          FileMetrics(
            path: 'lib/non_compliant.dart',
            linesOfCode: 10,
            commentLines: 0,
            classCount: 2,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [
          SecretIssue(
            filePath: 'lib/secret.dart',
            lineNumber: 1,
            secretType: 'test',
            value: 'abc',
          ),
        ],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/strings.dart',
            lineNumber: 2,
            value: 'hello',
          ),
        ],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: 'lib/numbers.dart',
            lineNumber: 3,
            value: '42',
          ),
        ],
        sourceSortIssues: [
          SourceSortIssue(
            filePath: 'lib/sort.dart',
            className: 'SortMe',
            lineNumber: 4,
            description: 'unsorted',
          ),
        ],
        layersIssues: [
          LayersIssue(
            type: LayersIssueType.cyclicDependency,
            filePath: 'lib/layers.dart',
            message: 'cycle',
          ),
        ],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.deadFile,
            filePath: 'lib/dead.dart',
            name: 'dead.dart',
          ),
        ],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final output = <String>[];
      runZoned(
        () {
          projectMetrics.printReport(listMode: ReportListMode.filenames);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );

      final joined = output.join('\n');
      expect(joined, contains('lib/non_compliant.dart'));
      expect(joined, contains('lib/strings.dart'));
      expect(joined, contains('lib/secret.dart'));
      expect(joined, isNot(contains(':2:')));
      expect(joined, isNot(contains('"hello"')));
    });

    test('should not truncate lists when listMode is full', () {
      final magicIssues = List.generate(
        12,
        (i) => MagicNumberIssue(
          filePath: 'lib/num_$i.dart',
          lineNumber: i + 1,
          value: '${i + 1}',
        ),
      );

      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: [],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: magicIssues,
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: true,
      );

      final output = <String>[];
      runZoned(
        () {
          projectMetrics.printReport(listMode: ReportListMode.full);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );

      final joined = output.join('\n');
      expect(joined, contains('lib/num_11.dart'));
      expect(joined, isNot(contains('... and')));
    });
  });
}
