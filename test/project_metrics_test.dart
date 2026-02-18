import 'dart:async';
import 'package:fcheck/src/models/app_strings.dart';

import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
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

    test('should not report 100 compliance score when there are open issues',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 17,
        totalFiles: 73,
        totalDartFiles: 50,
        totalLinesOfCode: 11603,
        totalCommentLines: 1684,
        fileMetrics: List.generate(
          50,
          (index) => FileMetrics(
            path: 'lib/file_$index.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ),
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: 'lib/src/metrics/project_metrics.dart',
            lineNumber: 274,
            value: '95',
          ),
          MagicNumberIssue(
            filePath: 'lib/src/metrics/project_metrics.dart',
            lineNumber: 277,
            value: '85',
          ),
          MagicNumberIssue(
            filePath: 'lib/src/metrics/project_metrics.dart',
            lineNumber: 280,
            value: '70',
          ),
          MagicNumberIssue(
            filePath: 'lib/src/metrics/project_metrics.dart',
            lineNumber: 283,
            value: '55',
          ),
        ],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 112,
        layersCount: 7,
        dependencyGraph: {},
        projectName: 'fcheck',
        version: '0.9.8',
        projectType: ProjectType.dart,
      );

      expect(projectMetrics.complianceScore, equals(99));
      expect(projectMetrics.complianceFocusAreaLabel, equals('Magic numbers'));
    });

    test('should report 100 compliance score for a fully clean run', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 2,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 2,
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
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'clean_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      expect(projectMetrics.complianceScore, equals(100));
      expect(projectMetrics.complianceFocusAreaLabel, equals('None'));
    });

    test('should apply suppression penalty when ignores/excludes are overused',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 20,
        totalDartFiles: 10,
        totalLinesOfCode: 1000,
        totalCommentLines: 120,
        fileMetrics: List.generate(
          10,
          (index) => FileMetrics(
            path: 'lib/file_$index.dart',
            linesOfCode: 100,
            commentLines: 12,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ),
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'suppressed_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        ignoreDirectivesCount: 20,
        customExcludedFilesCount: 8,
        hardcodedStringsAnalyzerEnabled: false,
        layersAnalyzerEnabled: false,
      );

      expect(projectMetrics.suppressionPenaltyPoints, equals(25));
      expect(projectMetrics.complianceScore, equals(75));
      expect(
          projectMetrics.complianceFocusAreaKey, equals('suppression_hygiene'));
      expect(
          projectMetrics.complianceFocusAreaLabel, equals('Checks bypassed'));
      expect(projectMetrics.complianceFocusAreaIssueCount, equals(30));
      expect(
        projectMetrics.complianceNextInvestment,
        contains('Reduce custom excludes'),
      );
    });

    test('should allow limited suppressions within budget', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 10,
        totalDartFiles: 6,
        totalLinesOfCode: 600,
        totalCommentLines: 50,
        fileMetrics: List.generate(
          6,
          (index) => FileMetrics(
            path: 'lib/file_$index.dart',
            linesOfCode: 100,
            commentLines: 8,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ),
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'limited_suppression_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        ignoreDirectivesCount: 2,
        customExcludedFilesCount: 1,
        duplicateCodeAnalyzerEnabled: false,
      );

      expect(projectMetrics.suppressionPenaltyPoints, equals(0));
      expect(projectMetrics.complianceScore, equals(100));
    });

    test('should cap maximum loss from one analyzer to its equal-share slice',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 8,
        totalDartFiles: 8,
        totalLinesOfCode: 800,
        totalCommentLines: 80,
        fileMetrics: List.generate(
          8,
          (index) => FileMetrics(
            path: 'lib/file_$index.dart',
            linesOfCode: 100,
            commentLines: 10,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ),
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: List.generate(
          1000,
          (index) => MagicNumberIssue(
            filePath: 'lib/file_0.dart',
            lineNumber: index + 1,
            value: '${index + 1}',
          ),
        ),
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'equal_share_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      expect(projectMetrics.complianceScore, equals(88));
      expect(projectMetrics.complianceFocusAreaLabel, equals('Magic numbers'));
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
            'customExcludedFiles': 0,
            'ignoreDirectives': 0,
            'disabledAnalyzers': 0,
            'suppressionPenalty': 0,
            'linesOfCode': 10,
            'commentLines': 2,
            'commentRatio': 0.2,
            'functions': 0,
            'stringLiterals': 0,
            'numberLiterals': 0,
            'hardcodedStrings': 1,
            'magicNumbers': 1,
            'secretIssues': 1,
            'deadCodeIssues': 1,
            'duplicateCodeIssues': 1,
            'documentationIssues': 0,
            'complianceScore': 43,
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
              'functionCount': 0,
              'stringLiteralCount': 0,
              'numberLiteralCount': 0,
              'isStatefulWidget': false,
              'isOneClassPerFileCompliant': false,
              'ignoreOneClassPerFile': false,
            },
          ],
          'codeSize': {
            'artifacts': [],
            'files': [],
            'classes': [],
            'callables': [],
          },
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
          'documentationIssues': [],
          'localization': {'usesLocalization': true},
          'compliance': {
            'score': 43,
            'suppressionPenalty': 0,
            'focusArea': 'one_class_per_file',
            'focusAreaLabel': 'One class per file',
            'focusAreaIssues': 1,
            'nextInvestment':
                'Split files with multiple classes into focused files.',
          },
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
      final joined = output.join('\n');
      expect(joined, contains('Scorecard'));
      expect(joined, contains(RegExp(r'Total Score.*:')));
      expect(joined, contains(RegExp(r'Invest Next.*:')));
      expect(RegExp(r'Total Score\s+:').allMatches(joined), hasLength(1));
    });

    test('should show dependency and devDependency counts in the dashboard',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 0,
            classCount: 2,
            methodCount: 4,
            topLevelFunctionCount: 3,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: const [],
        hardcodedStringIssues: const [],
        magicNumberIssues: const [],
        sourceSortIssues: const [],
        layersIssues: const [],
        deadCodeIssues: const [],
        layersEdgeCount: 9,
        layersCount: 0,
        dependencyGraph: const {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        dependencyCount: 3,
        devDependencyCount: 2,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');

      expect(joined, contains(AppStrings.dependency));
      expect(joined, contains(AppStrings.devDependency));
      expect(joined, contains(RegExp(r'Dependency\s+:.*3')));
      expect(joined, contains(RegExp(r'DevDependency\s+:.*2')));
      expect(joined, contains(RegExp(r'Classes\s+:.*2')));
      expect(joined, contains(RegExp(r'Methods\s+:.*4')));
      expect(joined, contains(RegExp(r'Functions\s+:.*3')));
      expect(joined, isNot(contains(AppStrings.customExcludes)));
      expect(joined, isNot(contains(AppStrings.ignoreDirectives)));
      expect(joined, isNot(contains(AppStrings.disabledRules)));
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
            filePath: 'sort.dart',
            className: 'SortMe',
            lineNumber: 4,
            description: 'unsorted',
          ),
        ],
        layersIssues: [
          LayersIssue(
            type: LayersIssueType.cyclicDependency,
            filePath: 'layers.dart',
            message: 'cycle',
          ),
        ],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.deadFile,
            filePath: 'dead.dart',
            name: 'dead.dart',
          ),
        ],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: true,
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

    test(
        'should list hardcoded string entries as warnings for Dart projects when localization is off',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: const [],
        secretIssues: const [],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/strings.dart',
            lineNumber: 2,
            value: 'hello',
          ),
        ],
        magicNumberIssues: const [],
        sourceSortIssues: const [],
        layersIssues: const [],
        deadCodeIssues: const [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: const {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: false,
      );

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.full);
      final joined = output.join('\n');

      expect(
        joined,
        contains(
          '${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.off}):',
        ),
      );
      expect(joined, contains('lib/strings.dart:2'));
      expect(joined, contains('"hello"'));
    });

    test(
        'should list hardcoded string entries as warnings for non-Dart projects when localization is off',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 0,
        fileMetrics: const [],
        secretIssues: const [],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/strings.dart',
            lineNumber: 2,
            value: 'hello',
          ),
        ],
        magicNumberIssues: const [],
        sourceSortIssues: const [],
        layersIssues: const [],
        deadCodeIssues: const [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: const {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.flutter,
        usesLocalization: false,
      );

      final output =
          buildReportLines(projectMetrics, listMode: ReportListMode.full);
      final joined = output.join('\n');

      expect(
        joined,
        contains(
          '${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.off}):',
        ),
      );
      expect(joined, contains('lib/strings.dart:2'));
      expect(joined, contains('"hello"'));
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

    test('should respect a custom partial list limit', () {
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

      final output = buildReportLines(
        projectMetrics,
        listMode: ReportListMode.partial,
        listItemLimit: 3,
      );

      final joined = output.join('\n');
      expect(joined, contains('lib/num_2.dart'));
      expect(joined, isNot(contains('lib/num_3.dart')));
      expect(joined, contains('... and 9 more'));
    });

    test('should respect partial list limit for one class per file issues', () {
      final violatingFiles = List.generate(
        4,
        (i) => FileMetrics(
          path: 'lib/violating_$i.dart',
          linesOfCode: 10,
          commentLines: 0,
          classCount: 2,
          isStatefulWidget: false,
        ),
      );

      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 4,
        totalDartFiles: 4,
        totalLinesOfCode: 40,
        totalCommentLines: 0,
        fileMetrics: violatingFiles,
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
        usesLocalization: true,
      );

      final output = buildReportLines(
        projectMetrics,
        listMode: ReportListMode.partial,
        listItemLimit: 2,
      );

      final joined = output.join('\n');
      expect(joined, contains('lib/violating_0.dart'));
      expect(joined, contains('lib/violating_1.dart'));
      expect(joined, isNot(contains('lib/violating_2.dart')));
      expect(joined, contains('... and 2 more'));
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

      expect(joined, contains(AppStrings.localization));
      expect(joined, contains('Hardcoded'));
      expect(joined, contains(AppStrings.disabled));
      expect(
          joined,
          contains(
              'Hardcoded strings check skipped (${AppStrings.disabled}).'));
      expect(joined, isNot(contains('Hardcoded strings check passed.')));
      expect(joined, contains('Duplicate code check skipped (disabled).'));
    });

    test('should show documentation check passed when enabled with no issues',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 1,
        fileMetrics: [
          FileMetrics(
            path: 'lib/sample.dart',
            linesOfCode: 10,
            commentLines: 1,
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
        duplicateCodeIssues: [],
        documentationIssues: const [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: true,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');

      expect(joined, contains('[✓] Documentation'));
      expect(
        joined,
        isNot(contains(
            '${AppStrings.documentationCheck} ${AppStrings.checkPassed}')),
      );
    });

    test('should show documentation issues in list section', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 1,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 1,
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
        duplicateCodeIssues: [],
        documentationIssues: const [
          DocumentationIssue(
            type: DocumentationIssueType.undocumentedPublicFunction,
            filePath: 'lib/a.dart',
            lineNumber: 12,
            subject: 'runApp',
          ),
        ],
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

      expect(joined, contains('1'));
      expect(joined, contains(AppStrings.documentationIssuesDetected));
      expect(
        joined,
        contains('lib/a.dart:12: public function is missing documentation'),
      );
    });

    test(
        'should show documentation skipped status and include it in disabled analyzers',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 1,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 1,
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
        duplicateCodeIssues: [],
        documentationIssues: const [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: true,
        documentationAnalyzerEnabled: false,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');

      expect(
          joined,
          contains(
              '${AppStrings.documentationCheck} skipped (${AppStrings.disabled}).'));
      expect(joined, contains(AppStrings.disabledRules));
      expect(joined, contains('1'));
      expect(joined, contains(AppStrings.analyzerSmall));
      expect(joined, contains('documentation'));
    });

    test('should show suppressions summary in Lists when suppressions exist',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 12,
        totalDartFiles: 8,
        totalLinesOfCode: 800,
        totalCommentLines: 80,
        fileMetrics: List.generate(
          8,
          (index) => FileMetrics(
            path: 'lib/file_$index.dart',
            linesOfCode: 100,
            commentLines: 10,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ),
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        ignoreDirectivesCount: 12,
        ignoreDirectiveFiles: [
          'lib/a.dart',
          'lib/b.dart',
        ],
        ignoreDirectiveCountsByFile: {
          'lib/a.dart': 7,
          'lib/b.dart': 5,
        },
        customExcludedFilesCount: 4,
        hardcodedStringsAnalyzerEnabled: false,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');

      expect(joined, contains(AppStrings.suppressionsSummary));
      expect(joined, contains('Ignore directives:'));
      expect(joined, contains('12'));
      expect(joined, contains(AppStrings.ignoreDirectivesAcross));
      expect(joined, contains('2'));
      expect(joined, contains(AppStrings.file));
      expect(joined, contains(AppStrings.filesSmall));
      expect(joined, contains(AppStrings.customExcludes));
      expect(joined, contains('4'));
      expect(joined, contains(AppStrings.dartFilesExcluded));
      expect(joined, contains(AppStrings.disabledRules));
      expect(joined, contains('1'));
      expect(joined, contains(AppStrings.analyzerSmall));
      expect(joined, contains('lib/a.dart'));
      expect(joined, contains('7'));
      expect(joined, contains('lib/b.dart'));
      expect(joined, contains('5'));
      expect(joined, contains('hardcoded_strings'));
    });

    test('should show suppressions check passed when no suppressions exist',
        () {
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
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final output = buildReportLines(projectMetrics);
      final joined = output.join('\n');
      expect(joined, contains('[✓] Checks bypassed'));
      expect(joined,
          isNot(contains('Suppressions check ${AppStrings.checkPassed}')));
    });

    test(
        'should order analyzer blocks with clean first, then warning/failing by score and title',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 3,
        totalDartFiles: 3,
        totalLinesOfCode: 30,
        totalCommentLines: 3,
        fileMetrics: [
          FileMetrics(
            path: 'lib/non_compliant.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 2,
            isStatefulWidget: false,
          ),
          FileMetrics(
            path: 'lib/clean1.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 1,
            isStatefulWidget: false,
          ),
          FileMetrics(
            path: 'lib/clean2.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/strings.dart',
            lineNumber: 2,
            value: 'hello',
          ),
        ],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: 'lib/num.dart',
            lineNumber: 3,
            value: '42',
          ),
        ],
        sourceSortIssues: [],
        layersIssues: [
          LayersIssue(
            type: LayersIssueType.cyclicDependency,
            filePath: 'lib/layers.dart',
            message: 'cycle',
          ),
        ],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: {},
        projectName: 'example_project',
        version: '1.0.0',
        projectType: ProjectType.dart,
        usesLocalization: false,
        ignoreDirectivesCount: 1,
        ignoreDirectiveCountsByFile: {'lib/ignored.dart': 1},
        deadCodeAnalyzerEnabled: false,
      );

      final output = buildReportLines(projectMetrics);
      final headerPattern = RegExp(
        r'^\s*(\[[^\]]+\])\s+(.+?)(?:\s+-(\d+(?:\.\d+)?)%\s+\((\d+)\))?$',
      );
      final analyzersIndex =
          output.indexWhere((line) => line.contains('Analyzers'));
      final analyzerSectionLines = analyzersIndex >= 0
          ? output
              .skip(analyzersIndex + 1)
              .takeWhile((line) => !line.contains('Scorecard'))
          : const <String>[];
      final headerRows = analyzerSectionLines
          .where((line) => RegExp(r'^\s*\[[^\]]+\]').hasMatch(line))
          .map((line) => headerPattern.firstMatch(line))
          .whereType<RegExpMatch>()
          .map((match) => (
                status: match.group(1)!,
                title: match.group(2)!.trim(),
                deduction: match.group(3) == null
                    ? 0.0
                    : double.parse(match.group(3)!),
                issueCount:
                    match.group(4) == null ? 0 : int.parse(match.group(4)!),
              ))
          .toList();

      int groupForStatus(String status) {
        if (status == '[✓]') {
          return 0;
        }
        if (status == '[!]' || status == '[x]') {
          return 1;
        }
        return 2;
      }

      expect(headerRows, isNotEmpty);
      for (var i = 1; i < headerRows.length; i++) {
        final previous = headerRows[i - 1];
        final current = headerRows[i];
        final previousGroup = groupForStatus(previous.status);
        final currentGroup = groupForStatus(current.status);
        expect(
          previousGroup <= currentGroup,
          isTrue,
          reason:
              'Expected clean first, warnings/failures second, disabled last.',
        );
        if (previousGroup != currentGroup) {
          continue;
        }
        if (currentGroup == 1 &&
            previous.deduction != current.deduction &&
            previous.issueCount > 0 &&
            current.issueCount > 0) {
          expect(
            previous.deduction <= current.deduction,
            isTrue,
            reason:
                'Expected lower global deduction first for warning/failing analyzers.',
          );
          continue;
        }
        if (previous.deduction == current.deduction || currentGroup != 1) {
          expect(
            current.title.compareTo(previous.title) >= 0,
            isTrue,
            reason: 'Expected title ascending within same ordering bucket.',
          );
        }
      }
    });

    test('should normalize duplicated path prefixes in issue lines', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 1,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [
          HardcodedStringIssue(
            filePath: 'lib/a.dart:lib/a.dart',
            lineNumber: 1,
            value: 'x',
          ),
        ],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
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

      expect(joined, isNot(contains('lib/a.dart:lib/a.dart:')));
      expect(joined, contains('lib/a.dart:1: "x"'));
    });

    test('should normalize duplicated absolute path prefixes in issue lines',
        () {
      const absolute =
          '/Users/jp/src/github/vteam/fcheck/bin/console_output.dart';

      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 10,
        totalCommentLines: 1,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 10,
            commentLines: 1,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: '$absolute:$absolute',
            lineNumber: 2,
            value: '2',
          ),
        ],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
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

      expect(joined, isNot(contains('$absolute:$absolute:')));
      expect(joined, contains('bin/console_output.dart:2: 2'));
    });

    test('should normalize duplicated path prefixes in output file lines', () {
      final printedLines = <String>[];
      const path = '/tmp/layers.svg';
      const duplicatedPath = '$path:$path';

      runZoned(
        () => printOutputFileLine(
          label: 'SVG layers         ',
          path: duplicatedPath,
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printedLines.add(line),
        ),
      );

      expect(printedLines, hasLength(1));
      expect(printedLines.single, contains(path));
      expect(printedLines.single, isNot(contains(duplicatedPath)));
    });

    test('dead code grouped output should not repeat issue type label', () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 20,
        totalCommentLines: 2,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 20,
            commentLines: 2,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.unusedVariable,
            filePath: 'lib/a.dart',
            lineNumber: 12,
            name: 'tempValue',
            owner: 'build',
          ),
        ],
        duplicateCodeIssues: [],
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

      expect(joined, contains('${AppStrings.unusedVariables} (1):'));
      expect(joined, contains('lib/a.dart:12:'));
      expect(joined, contains('"tempValue"'));
      expect(joined, contains('in build'));
      expect(joined, isNot(contains('unused variable "tempValue"')));
    });

    test('dead code grouped output should normalize duplicated path prefixes',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 20,
        totalCommentLines: 2,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 20,
            commentLines: 2,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.unusedVariable,
            filePath: 'bin/console_output.dart:bin/console_output.dart',
            name: 'status',
            owner: 'anonymous',
          ),
        ],
        duplicateCodeIssues: [],
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

      expect(
        joined,
        contains('bin/console_output.dart:'),
      );
      expect(
        joined,
        contains('"status"'),
      );
      expect(
        joined,
        contains('in anonymous'),
      );
      expect(
        joined,
        isNot(
          contains('bin/console_output.dart:bin/console_output.dart:'),
        ),
      );
    });

    test(
        'dead code grouped output should preserve line numbers with duplicated paths',
        () {
      final projectMetrics = ProjectMetrics(
        totalFolders: 1,
        totalFiles: 1,
        totalDartFiles: 1,
        totalLinesOfCode: 20,
        totalCommentLines: 2,
        fileMetrics: [
          FileMetrics(
            path: 'lib/main.dart',
            linesOfCode: 20,
            commentLines: 2,
            classCount: 1,
            isStatefulWidget: false,
          ),
        ],
        secretIssues: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.unusedVariable,
            filePath: 'bin/console_output.dart:bin/console_output.dart',
            lineNumber: 428,
            name: 'status',
            owner: 'anonymous',
          ),
        ],
        duplicateCodeIssues: [],
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

      expect(joined, contains('bin/console_output.dart:428:'));
      expect(joined, contains('"status"'));
      expect(joined, contains('in anonymous'));
      expect(
        joined,
        isNot(
          contains('bin/console_output.dart:bin/console_output.dart:'),
        ),
      );
    });
  });
}
