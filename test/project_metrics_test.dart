import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/metrics/project_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:test/test.dart';

import '../bin/console_common.dart';
import '../bin/console_output.dart';

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

    test('should serialize toJson with all sections and issue details', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 3,
        totalFiles: 8,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 2,
        fileMetrics: [
          FileMetrics(
            path: 'lib/non_compliant.dart',
            linesOfCode: 10,
            commentLines: 2,
            classCount: 3,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [
          SecretIssue(
            filePath: 'lib/.env',
            lineNumber: 3,
            secretType: 'api_key',
            value: 'SECRET',
          ),
        ],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/ui.dart',
            lineNumber: 11,
            value: 'Hello',
          ),
        ],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: 'lib/calc.dart',
            lineNumber: 7,
            value: '42',
          ),
        ],
        sourceSortIssues: [
          SourceSortIssue(
            filePath: 'lib/sort.dart',
            className: 'SortMe',
            lineNumber: 4,
            description: 'Members are not sorted',
          ),
        ],
        layersIssues: [
          LayersIssue(
            type: LayersIssueType.wrongLayer,
            filePath: 'lib/data/repo.dart',
            message: 'Data layer depends on presentation',
          ),
        ],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.deadFunction,
            filePath: 'lib/utils.dart',
            lineNumber: 21,
            name: 'unusedHelper',
            owner: 'Utils',
          ),
        ],
        duplicateCodeIssues: [
          DuplicateCodeIssue(
            firstFilePath: 'lib/one.dart',
            firstLineNumber: 10,
            firstSymbol: 'render',
            secondFilePath: 'lib/two.dart',
            secondLineNumber: 15,
            secondSymbol: 'buildView',
            similarity: 0.9,
            lineCount: 12,
          ),
        ],
        layersEdgeCount: 6,
        layersCount: 4,
        dependencyGraph: {
          'lib/data/repo.dart': ['lib/presentation/view.dart'],
        },
        excludedFilesCount: 5,
        usesLocalization: true,
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.flutter,
      );

      expect(
        projectMetrics.toJson(),
        equals({
          'project': {
            'name': 'example_project',
            'version': '1.0.0',
            'type': 'Flutter',
          },
          'stats': {
            'folders': 3,
            'files': 8,
            'dartFiles': 1,
            'excludedFiles': 5,
            'linesOfCode': 10,
            'commentLines': 2,
            'commentRatio': 0.2,
            'hardcodedStrings': 1,
            'magicNumbers': 1,
            'secretIssues': 1,
            'deadCodeIssues': 1,
            'duplicateCodeIssues': 1,
          },
          'layers': {
            'count': 4,
            'dependencies': 6,
            'violations': [
              {
                'type': 'wrongLayer',
                'filePath': 'lib/data/repo.dart',
                'message': 'Data layer depends on presentation',
              },
            ],
            'graph': {
              'lib/data/repo.dart': ['lib/presentation/view.dart'],
            },
          },
          'files': [
            {
              'path': 'lib/non_compliant.dart',
              'linesOfCode': 10,
              'commentLines': 2,
              'classCount': 3,
              'isStatefulWidget': false,
              'isOneClassPerFileCompliant': false,
              'ignoreOneClassPerFile': false,
            },
          ],
          'hardcodedStrings': [
            {
              'filePath': 'lib/ui.dart',
              'lineNumber': 11,
              'value': 'Hello',
            },
          ],
          'magicNumbers': [
            {
              'filePath': 'lib/calc.dart',
              'lineNumber': 7,
              'value': '42',
            },
          ],
          'sourceSorting': [
            {
              'filePath': 'lib/sort.dart',
              'className': 'SortMe',
              'lineNumber': 4,
              'description': 'Members are not sorted',
            },
          ],
          'secretIssues': [
            {
              'filePath': 'lib/.env',
              'lineNumber': 3,
              'secretType': 'api_key',
              'value': 'SECRET',
            },
          ],
          'deadCodeIssues': [
            {
              'type': 'deadFunction',
              'filePath': 'lib/utils.dart',
              'lineNumber': 21,
              'name': 'unusedHelper',
              'owner': 'Utils',
            },
          ],
          'duplicateCodeIssues': [
            {
              'firstFilePath': 'lib/one.dart',
              'firstLineNumber': 10,
              'firstSymbol': 'render',
              'secondFilePath': 'lib/two.dart',
              'secondLineNumber': 15,
              'secondSymbol': 'buildView',
              'similarity': 0.9,
              'lineCount': 12,
            },
          ],
          'localization': {'usesLocalization': true},
        }),
      );
    });

    test('should build report correctly', () {
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

      final output = buildReportLines(projectMetrics);

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

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.none);

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

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.filenames);

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

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.full);

      final joined = output.join('\n');
      expect(joined, contains('lib/num_11.dart'));
      expect(joined, isNot(contains('... and')));
    });

    test(
        'should sort duplicate code output by similarity then line count descending',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: [],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [
          DuplicateCodeIssue(
            firstFilePath: 'lib/short_a.dart',
            firstLineNumber: 10,
            firstSymbol: 'a',
            secondFilePath: 'lib/short_b.dart',
            secondLineNumber: 20,
            secondSymbol: 'b',
            similarity: 1.0,
            lineCount: 9,
          ),
          DuplicateCodeIssue(
            firstFilePath: 'lib/long_a.dart',
            firstLineNumber: 10,
            firstSymbol: 'a',
            secondFilePath: 'lib/long_b.dart',
            secondLineNumber: 20,
            secondSymbol: 'b',
            similarity: 1.0,
            lineCount: 16,
          ),
          DuplicateCodeIssue(
            firstFilePath: 'lib/lower_similarity_a.dart',
            firstLineNumber: 10,
            firstSymbol: 'a',
            secondFilePath: 'lib/lower_similarity_b.dart',
            secondLineNumber: 20,
            secondSymbol: 'b',
            similarity: 0.95,
            lineCount: 30,
          ),
        ],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.full);
      final duplicateLines = output
          .where((line) => line.startsWith('  - ') && line.contains(' <-> '))
          .toList();

      expect(duplicateLines, hasLength(3));
      expect(duplicateLines[0], contains('100% (16 lines)'));
      expect(duplicateLines[1], contains('100% ( 9 lines)'));
      expect(duplicateLines[2], contains('95% (30 lines)'));
    });

    test('should show skipped status for disabled analyzers', () {
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
        hardcodedStringsAnalyzerEnabled: false,
        duplicateCodeAnalyzerEnabled: false,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');

      expect(joined, contains('Hardcoded Strings: disabled'));
      expect(joined, contains('Hardcoded strings check skipped (disabled).'));
      expect(joined, isNot(contains('Hardcoded strings check passed.')));
      expect(joined, contains('Duplicate Code   : disabled'));
      expect(joined, contains('Duplicate code check skipped (disabled).'));
    });
  });
}
