import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/externals/export_mermaid.dart';
import 'package:fcheck/src/exports/externals/export_plantuml.dart';
import 'package:fcheck/src/exports/svg/export_files/export_svg_files.dart';
import 'package:fcheck/src/exports/svg/export_folders/export_svg_folders.dart';
import 'package:fcheck/src/exports/svg/export_loc/export_svg_code_size.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:fcheck/src/exports/externals/graph_format_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  int warningPathCount(String svg) =>
      RegExp(r'<path[^>]*class="warningEdge"').allMatches(svg).length;
  bool hasEdgeWithClass(String svg, String cssClass, String title) {
    final pattern = RegExp(
      '<g>\\s*<path[^>]*class="$cssClass"\\/>\\s*<title>${RegExp.escape(title)}</title>\\s*</g>',
    );
    return pattern.hasMatch(svg);
  }

  group('graph exporters', () {
    test('return empty outputs for empty graphs', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {},
        dependencyGraph: const {},
      );

      expect(exportGraphMermaid(result), equals(emptyMermaidGraph()));
      expect(exportGraphPlantUML(result), equals(emptyPlantUml()));
      expect(exportGraphSvgFiles(result), contains('No dependencies found'));
      expect(
        exportGraphSvgFolders(result),
        contains('No hierarchical dependencies found'),
      );
    });

    test('render graph outputs with edges and labels', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/a.dart': 0,
          'lib/src/b.dart': 1,
          'lib/src/c.dart': 1,
        },
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/b.dart', 'lib/src/c.dart'],
          'lib/src/b.dart': ['lib/src/a.dart'],
          'lib/src/c.dart': ['lib/src/b.dart'],
        },
      );

      final mermaid = exportGraphMermaid(result);
      expect(mermaid, contains('graph TD'));
      expect(mermaid, contains('Layer_0'));
      expect(mermaid, contains('Layer_1'));
      expect(mermaid, contains('-.-o'));
      expect(mermaid, contains('-.->'));

      final plantUml = exportGraphPlantUML(result);
      expect(plantUml, contains('@startuml'));
      expect(plantUml, contains('@enduml'));
      expect(plantUml, contains('-->'));
      expect(plantUml, contains('..>'));

      final svg = exportGraphSvgFiles(result);
      expect(svg, contains('<svg'));
      expect(svg, contains('class="fileNode"'));

      final folderSvg = exportGraphSvgFolders(
        result,
        projectName: 'DemoProject',
        projectVersion: '1.2.3',
        inputFolderName: 'sample',
      );
      expect(folderSvg, contains('<svg'));
      expect(folderSvg, contains('sample'));
      expect(folderSvg, contains('DemoProject v1.2.3'));
    });

    test('apply warning and error tints in layers SVG exports', () {
      final result = LayersAnalysisResult(
        issues: [
          LayersIssue(
            type: LayersIssueType.wrongLayer,
            filePath: 'lib/src/a.dart',
            message: 'warning',
          ),
          LayersIssue(
            type: LayersIssueType.cyclicDependency,
            filePath: 'lib/src/b.dart',
            message: 'cycle',
          ),
          LayersIssue(
            type: LayersIssueType.folderCycle,
            filePath: 'lib/src',
            message: 'folder cycle',
          ),
        ],
        layers: const {'lib/src/a.dart': 0, 'lib/src/b.dart': 0},
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/b.dart'],
          'lib/src/b.dart': ['lib/src/a.dart'],
        },
      );

      final filesSvg = exportGraphSvgFiles(result);
      expect(filesSvg, contains('warningNodeGradient'));
      expect(filesSvg, contains('errorNodeGradient'));

      final foldersSvg = exportGraphSvgFolders(result);
      expect(foldersSvg, contains('warningNodeGradient'));
      expect(foldersSvg, contains('errorNodeGradient'));
    });

    test(
      'apply non-layer analyzer warnings to layers SVG exports when metrics are provided',
      () {
        final result = LayersAnalysisResult(
          issues: const [],
          layers: const {'lib/src/a.dart': 0, 'lib/src/b.dart': 0},
          dependencyGraph: const {
            'lib/src/a.dart': ['lib/src/b.dart'],
            'lib/src/b.dart': <String>[],
          },
        );
        final metrics = ProjectMetrics(
          totalFolders: 0,
          totalFiles: 0,
          totalDartFiles: 0,
          totalLinesOfCode: 0,
          totalCommentLines: 0,
          fileMetrics: const [],
          secretIssues: const [],
          hardcodedStringIssues: const [],
          magicNumberIssues: [
            MagicNumberIssue(
              filePath: 'lib/src/a.dart',
              lineNumber: 12,
              value: '42',
            ),
          ],
          sourceSortIssues: const [],
          layersIssues: const [],
          deadCodeIssues: const [],
          layersEdgeCount: 0,
          layersCount: 0,
          dependencyGraph: const {},
          projectName: 'demo',
          version: '1.0.0',
          projectType: ProjectType.dart,
        );

        final filesSvg = exportGraphSvgFiles(result, projectMetrics: metrics);
        expect(filesSvg, contains('warningNodeGradient'));
        expect(filesSvg, contains('File: lib/src/a.dart'));
        expect(filesSvg, contains('1 Magic Numbers warning'));

        final foldersSvg = exportGraphSvgFolders(
          result,
          projectMetrics: metrics,
        );
        expect(foldersSvg, contains('warningNodeGradient'));
        expect(foldersSvg, contains('File: a.dart'));
        expect(foldersSvg, contains('Folder: .'));
        expect(foldersSvg, contains('1 Magic Numbers warning'));
      },
    );

    test(
      'exclude hardcoded warnings from SVG warnings when localization is OFF',
      () {
        final result = LayersAnalysisResult(
          issues: const [],
          layers: const {'lib/src/a.dart': 0},
          dependencyGraph: const {'lib/src/a.dart': <String>[]},
        );
        final metrics = ProjectMetrics(
          totalFolders: 0,
          totalFiles: 0,
          totalDartFiles: 0,
          totalLinesOfCode: 0,
          totalCommentLines: 0,
          fileMetrics: const [],
          secretIssues: const [],
          hardcodedStringIssues: [
            HardcodedStringIssue(
              filePath: 'lib/src/a.dart',
              lineNumber: 10,
              value: 'Hello',
            ),
          ],
          magicNumberIssues: const [],
          sourceSortIssues: const [],
          layersIssues: const [],
          deadCodeIssues: const [],
          layersEdgeCount: 0,
          layersCount: 0,
          dependencyGraph: const {},
          projectName: 'demo',
          version: '1.0.0',
          projectType: ProjectType.dart,
          usesLocalization: false,
        );

        final filesSvg = exportGraphSvgFiles(result, projectMetrics: metrics);
        expect(filesSvg, isNot(contains('Hardcoded Strings warning')));

        final foldersSvg = exportGraphSvgFolders(
          result,
          projectMetrics: metrics,
        );
        expect(foldersSvg, isNot(contains('Hardcoded Strings warning')));

        final codeSizeSvg = exportSvgCodeSize(const [
          CodeSizeArtifact(
            kind: CodeSizeArtifactKind.file,
            name: 'a.dart',
            filePath: 'lib/src/a.dart',
            linesOfCode: 10,
            startLine: 1,
            endLine: 10,
          ),
        ], projectMetrics: metrics);
        expect(codeSizeSvg, isNot(contains('Hardcoded Strings warning')));
      },
    );

    test('match relative metric paths to absolute layers SVG node paths', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {'/repo/lib/src/a.dart': 0, '/repo/lib/src/b.dart': 0},
        dependencyGraph: const {
          '/repo/lib/src/a.dart': ['/repo/lib/src/b.dart'],
          '/repo/lib/src/b.dart': <String>[],
        },
      );
      final metrics = ProjectMetrics(
        totalFolders: 0,
        totalFiles: 0,
        totalDartFiles: 0,
        totalLinesOfCode: 0,
        totalCommentLines: 0,
        fileMetrics: const [],
        secretIssues: const [],
        hardcodedStringIssues: const [],
        magicNumberIssues: const [],
        sourceSortIssues: const [],
        documentationIssues: const [
          DocumentationIssue(
            filePath: 'lib/src/a.dart',
            lineNumber: 3,
            subject: 'A',
            type: DocumentationIssueType.undocumentedPublicClass,
          ),
        ],
        layersIssues: const [],
        deadCodeIssues: const [],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: const {},
        projectName: 'demo',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final svg = exportGraphSvgFiles(result, projectMetrics: metrics);
      expect(svg, contains('warningNodeGradient'));
      expect(svg, contains('File: /repo/lib/src/a.dart'));
      expect(svg, contains('1 Documentation warning'));
    });

    test('render code-size treemap SVG with unified hierarchy', () {
      final artifacts = <CodeSizeArtifact>[
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: 'a.dart',
          filePath: 'lib/a.dart',
          linesOfCode: 2000,
          startLine: 1,
          endLine: 2000,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: 'b.dart',
          filePath: 'lib/src/b.dart',
          linesOfCode: 300,
          startLine: 1,
          endLine: 300,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: 'user_controller.dart',
          filePath: 'lib/user_controller.dart',
          linesOfCode: 2500,
          startLine: 1,
          endLine: 2500,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: 'main.dart',
          filePath: 'lib/main.dart',
          linesOfCode: 1200,
          startLine: 1,
          endLine: 1200,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.file,
          name: 'app_view.dart',
          filePath: 'lib/app_view.dart',
          linesOfCode: 1800,
          startLine: 1,
          endLine: 1800,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.classDeclaration,
          name: 'UserController',
          filePath: 'lib/user_controller.dart',
          linesOfCode: 150,
          startLine: 5,
          endLine: 150,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.classDeclaration,
          name: 'AppView',
          filePath: 'lib/app_view.dart',
          linesOfCode: 70,
          startLine: 5,
          endLine: 70,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.function,
          name: 'bootstrap',
          filePath: 'lib/main.dart',
          linesOfCode: 60,
          startLine: 10,
          endLine: 60,
        ),
        const CodeSizeArtifact(
          kind: CodeSizeArtifactKind.method,
          name: 'render',
          ownerName: 'AppView',
          filePath: 'lib/app_view.dart',
          linesOfCode: 45,
          startLine: 20,
          endLine: 45,
        ),
      ];

      final metrics = ProjectMetrics(
        totalFolders: 0,
        totalFiles: 0,
        totalDartFiles: 0,
        totalLinesOfCode: 0,
        totalCommentLines: 0,
        fileMetrics: const [],
        secretIssues: const [],
        hardcodedStringIssues: const [],
        magicNumberIssues: [
          MagicNumberIssue(
            filePath: 'lib/app_view.dart',
            lineNumber: 22,
            value: '42',
          ),
        ],
        sourceSortIssues: const [],
        layersIssues: const [],
        deadCodeIssues: [
          DeadCodeIssue(
            type: DeadCodeIssueType.deadFunction,
            filePath: 'lib/app_view.dart',
            lineNumber: 20,
            name: 'render',
            owner: 'AppView',
          ),
        ],
        layersEdgeCount: 0,
        layersCount: 0,
        dependencyGraph: const {},
        projectName: 'demo',
        version: '1.0.0',
        projectType: ProjectType.dart,
      );

      final svg = exportSvgCodeSize(
        artifacts,
        title: 'Code Size Treemap Test',
        projectMetrics: metrics,
      );

      expect(svg, contains('<svg'));
      expect(svg, contains('Code Size Treemap Test'));
      expect(svg, contains('Folders'));
      expect(svg, anyOf(contains('classes'), contains('Classes')));
      expect(svg, anyOf(contains('Functions'), contains('Functions/Methods')));
      expect(svg, isNot(contains('Classes &amp; Functions')));
      expect(svg, contains('2,580 LOC Folder: lib'));
      expect(svg, isNot(contains('2,580 LOC Folder: lib\n\nlib')));
      expect(svg, contains('UserController'));
      expect(svg, contains('45 LOC in Method: AppView.render()'));
      expect(svg, contains('File: lib/app_view.dart'));
      expect(svg, contains('&lt;...&gt;'));
      expect(svg, contains('2,580 LOC'));
      expect(svg, contains('fill="#000"'));
      expect(svg, contains('fill="#e05545"'));
      expect(svg, contains('Warning'));
      expect(svg, contains('Error'));
      expect(svg, isNot(contains('warnings:')));
      expect(svg, contains('1 Dead Code warning'));
      expect(svg, contains('1 Magic Numbers warning'));
      expect(svg, isNot(contains('filter="url(#outlineWhite)"')));
      expect(svg, contains('text-anchor="start"'));
    });

    test('render empty code-size treemap when there are no artifacts', () {
      final svg = exportSvgCodeSize(const []);
      expect(svg, contains('No code-size artifacts found'));
    });

    test('render code-size treemap with relative paths', () {
      final projectRoot = p.join('/tmp', 'demo_project');
      final artifact = CodeSizeArtifact(
        kind: CodeSizeArtifactKind.file,
        name: 'a.dart',
        filePath: p.join(projectRoot, 'lib', 'a.dart'),
        linesOfCode: 12058,
        startLine: 1,
        endLine: 12058,
      );

      final svg = exportSvgCodeSize([artifact], relativeTo: projectRoot);

      expect(svg, contains('lib/a.dart'));
      expect(svg, isNot(contains(projectRoot)));
      expect(svg, isNot(contains('Warning')));
      expect(svg, isNot(contains('Error')));
    });

    test('fit long file labels in flat SVG without truncation', () {
      const longPath =
          'lib/src/this_is_a_very_long_file_name_that_should_stay_complete_in_svg_output.dart';
      const longName =
          'this_is_a_very_long_file_name_that_should_stay_complete_in_svg_output.dart';

      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {longPath: 0},
        dependencyGraph: const {longPath: []},
      );

      final svg = exportGraphSvgFiles(result);

      expect(svg, contains(longName));
      expect(svg, isNot(contains('$longName...')));
      expect(svg, isNot(contains('style="font-size:')));
      expect(
        RegExp(
          '<text[^>]*class="textSmall"[^>]*>${RegExp.escape(longName)}</text>',
        ).hasMatch(svg),
        isTrue,
      );
    });

    test('fit long file labels in hierarchical SVG without truncation', () {
      const longPath =
          'lib/src/reports/this_is_an_even_longer_file_name_for_hierarchical_svg_rendering.dart';
      const helperPath = 'lib/src/reports/helper.dart';
      const longName =
          'this_is_an_even_longer_file_name_for_hierarchical_svg_rendering.dart';

      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {longPath: 0, helperPath: 1},
        dependencyGraph: const {
          longPath: [helperPath],
          helperPath: [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);

      expect(folderSvg, contains(longName));
      expect(folderSvg, isNot(contains('$longName...')));
      expect(folderSvg, isNot(contains('style="font-size:')));

      final pattern = RegExp(
        '<text[^>]*class="textSmall"[^>]*>${RegExp.escape(longName)}</text>',
      );
      final match = pattern.firstMatch(folderSvg);
      expect(match, isNotNull);
    });

    test(
      'creates virtual folder for loose files when folder has both files and subfolders',
      () {
        // This test triggers _applyLooseFilesRule:
        // - lib/ contains both a file (utils.dart) AND a subfolder (src/)
        // - The rule should create a virtual "..." folder for the loose file
        final result = LayersAnalysisResult(
          issues: const [],
          layers: const {'lib/utils.dart': 0, 'lib/src/main.dart': 1},
          dependencyGraph: const {
            'lib/src/main.dart': ['lib/utils.dart'],
            'lib/utils.dart': [],
          },
        );

        final folderSvg = exportGraphSvgFolders(
          result,
          projectName: 'TestProject',
          projectVersion: '1.0.0',
          inputFolderName: 'lib',
        );

        // The virtual "..." folder should be created for the loose file
        expect(folderSvg, contains('...'));
        // Should have both the virtual folder and the src subfolder
        expect(folderSvg, contains('src'));
      },
    );

    test('does not color downward-rendered violation edges orange', () {
      // Use cross-folder ordering where source folder is visually lower than target
      // folder, so violation edges are truly rendered as "going up".
      final graph = const {
        'lib/a/target.dart': <String>[],
        'lib/z/source.dart': ['lib/a/target.dart'],
      };
      final layers = const {'lib/z/source.dart': 2, 'lib/a/target.dart': 1};

      final withoutViolation = LayersAnalysisResult(
        issues: const [],
        layers: layers,
        dependencyGraph: graph,
      );
      final withoutViolationSvg = exportGraphSvgFolders(withoutViolation);
      expect(warningPathCount(withoutViolationSvg), equals(0));

      final withViolation = LayersAnalysisResult(
        issues: [
          LayersIssue(
            type: LayersIssueType.wrongFolderLayer,
            filePath: 'lib/z/source.dart',
            message:
                'Layer 2 depends on file "lib/a/target.dart" (above layer 1)',
          ),
        ],
        layers: layers,
        dependencyGraph: graph,
      );
      final withViolationSvg = exportGraphSvgFolders(withViolation);
      expect(warningPathCount(withViolationSvg), equals(0));
    });

    test(
      'colors upward file edges orange in folder cycles to expose culprit files',
      () {
        final result = LayersAnalysisResult(
          issues: [
            LayersIssue(
              type: LayersIssueType.cyclicDependency,
              filePath: 'lib/a/a.dart',
              message: 'cycle',
            ),
            LayersIssue(
              type: LayersIssueType.folderCycle,
              filePath: 'lib/a',
              message: 'folder cycle',
            ),
            LayersIssue(
              type: LayersIssueType.folderCycle,
              filePath: 'lib/b',
              message: 'folder cycle',
            ),
          ],
          layers: const {},
          dependencyGraph: const {
            'lib/a/a.dart': ['lib/b/b.dart'],
            'lib/b/b.dart': ['lib/a/a.dart'],
          },
        );

        final folderSvg = exportGraphSvgFolders(result);

        expect(
          hasEdgeWithClass(folderSvg, 'warningEdge', 'b/b.dart ▶ a/a.dart'),
          isTrue,
        );
      },
    );

    test('handles deeply nested folders with mixed files and subfolders', () {
      // More complex scenario: nested folders with files at multiple levels
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/main.dart': 0,
          'lib/src/models/user.dart': 1,
          'lib/src/utils.dart': 1,
        },
        dependencyGraph: const {
          'lib/main.dart': ['lib/src/models/user.dart'],
          'lib/src/models/user.dart': [],
          'lib/src/utils.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(
        result,
        projectName: 'DeepProject',
        projectVersion: '2.0.0',
        inputFolderName: 'lib',
      );

      expect(folderSvg, contains('DeepProject'));
      expect(folderSvg, contains('<svg'));
    });

    test('renders innermost folder dependency edges before outer ones', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/a/a.dart': 0,
          'lib/a/b/b.dart': 1,
          'lib/a/c/c.dart': 1,
          'lib/d/d.dart': 1,
        },
        dependencyGraph: const {
          'lib/a/b/b.dart': ['lib/a/c/c.dart'],
          'lib/a/a.dart': ['lib/d/d.dart'],
          'lib/a/c/c.dart': [],
          'lib/d/d.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);

      final nestedEdgeIndex = folderSvg.indexOf('<title>a/b ▶ a/c</title>');
      final outerEdgeIndex = folderSvg.indexOf('<title>a ▶ d</title>');

      expect(nestedEdgeIndex, greaterThanOrEqualTo(0));
      expect(outerEdgeIndex, greaterThanOrEqualTo(0));
      expect(nestedEdgeIndex, lessThan(outerEdgeIndex));
    });

    test('renders real subfolder edges before virtual-folder edges', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/a/root.dart': 0,
          'lib/a/b/b.dart': 1,
          'lib/a/c/c.dart': 1,
        },
        dependencyGraph: const {
          'lib/a/b/b.dart': ['lib/a/c/c.dart'],
          'lib/a/root.dart': ['lib/a/c/c.dart'],
          'lib/a/c/c.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);
      final realEdgeIndex = folderSvg.indexOf('<title>b ▶ c</title>');
      final virtualEdgeIndex = folderSvg.indexOf('<title>... ▶ c</title>');

      expect(realEdgeIndex, greaterThanOrEqualTo(0));
      expect(virtualEdgeIndex, greaterThanOrEqualTo(0));
      expect(realEdgeIndex, lessThan(virtualEdgeIndex));
    });

    test('places shorter sibling folder edge in a more inner lane', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/root.dart': 0,
          'lib/a/a.dart': 1,
          'lib/very/deep/down/down.dart': 1,
        },
        dependencyGraph: const {
          'lib/root.dart': ['lib/a/a.dart', 'lib/very/deep/down/down.dart'],
          'lib/a/a.dart': [],
          'lib/very/deep/down/down.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);
      final shortLaneX = _extractFolderEdgeColumnX(folderSvg, '... ▶ a');
      final longLaneX = _extractFolderEdgeColumnX(folderSvg, '... ▶ very');

      expect(shortLaneX, isNotNull);
      expect(longLaneX, isNotNull);
      expect(shortLaneX!, greaterThan(longLaneX!));
    });

    test('places short graphs edge inside long graphs edge', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/graphs/g.dart': 0,
          'lib/src/analyzers/a.dart': 1,
          'lib/src/models/m.dart': 1,
        },
        dependencyGraph: const {
          'lib/src/graphs/g.dart': [
            'lib/src/analyzers/a.dart',
            'lib/src/models/m.dart',
          ],
          'lib/src/analyzers/a.dart': [],
          'lib/src/models/m.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);
      final graphsToAnalyzersX = _extractFolderEdgeColumnX(
        folderSvg,
        'graphs ▶ analyzers',
      );
      final graphsToModelsX = _extractFolderEdgeColumnX(
        folderSvg,
        'graphs ▶ models',
      );

      expect(graphsToAnalyzersX, isNotNull);
      expect(graphsToModelsX, isNotNull);
      expect(graphsToAnalyzersX!, greaterThan(graphsToModelsX!));
    });

    test('places short file edge inside long file edge in right lane', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/root.dart': 0,
          'lib/a/a.dart': 1,
          'lib/very/deep/down/down.dart': 1,
        },
        dependencyGraph: const {
          'lib/root.dart': ['lib/a/a.dart', 'lib/very/deep/down/down.dart'],
          'lib/a/a.dart': [],
          'lib/very/deep/down/down.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);
      final shortFileEdgeX = _extractFolderEdgeColumnX(
        folderSvg,
        'root.dart ▶ a/a.dart',
      );
      final longFileEdgeX = _extractFolderEdgeColumnX(
        folderSvg,
        'root.dart ▶ very/deep/down/down.dart',
      );

      expect(shortFileEdgeX, isNotNull);
      expect(longFileEdgeX, isNotNull);
      expect(shortFileEdgeX!, lessThan(longFileEdgeX!));
    });

    test('draws inner file edge before outer file edge', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/root.dart': 0,
          'lib/a/a.dart': 1,
          'lib/very/deep/down/down.dart': 1,
        },
        dependencyGraph: const {
          'lib/root.dart': ['lib/a/a.dart', 'lib/very/deep/down/down.dart'],
          'lib/a/a.dart': [],
          'lib/very/deep/down/down.dart': [],
        },
      );

      final folderSvg = exportGraphSvgFolders(result);
      final innerIndex = folderSvg.indexOf(
        '<title>root.dart ▶ a/a.dart</title>',
      );
      final outerIndex = folderSvg.indexOf(
        '<title>root.dart ▶ very/deep/down/down.dart</title>',
      );

      expect(innerIndex, greaterThanOrEqualTo(0));
      expect(outerIndex, greaterThanOrEqualTo(0));
      expect(innerIndex, lessThan(outerIndex));
    });

    test('adjacent same-row forward edges use a near-straight cubic', () {
      // Single node in each column → same Y → near-straight cubic routing.
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {'lib/src/a.dart': 0, 'lib/src/b.dart': 1},
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/b.dart'],
          'lib/src/b.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);

      // Same-row adjacent edge uses a tiny-belly cubic to preserve visibility.
      expect(
        RegExp(r'<path d="M [^"]*C ').hasMatch(svg),
        isTrue,
        reason: 'adjacent same-row edge should use near-straight cubic routing',
      );
      // Should not use elbow Q commands on edge-class paths.
      expect(
        RegExp(r'<path d="M [^"]*Q [^"]*" class="edge').hasMatch(svg),
        isFalse,
        reason: 'adjacent same-row edge should not use elbow routing',
      );
    });

    test('draws far file edge after near file edge', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/root.dart': 0,
          'lib/src/near.dart': 1,
          'lib/src/far.dart': 2,
        },
        dependencyGraph: const {
          'lib/src/root.dart': ['lib/src/near.dart', 'lib/src/far.dart'],
          'lib/src/near.dart': [],
          'lib/src/far.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);
      final nearIndex = svg.indexOf(
        '<title>lib/src/root.dart ▶ lib/src/near.dart</title>',
      );
      final farIndex = svg.indexOf(
        '<title>lib/src/root.dart ▶ lib/src/far.dart</title>',
      );

      expect(nearIndex, greaterThanOrEqualTo(0));
      expect(farIndex, greaterThanOrEqualTo(0));
      expect(nearIndex, lessThan(farIndex));
    });

    test('draws longer-span adjacent file edge before shorter-span one', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/root.dart': 0,
          'lib/src/a_top.dart': 1,
          'lib/src/z_bottom.dart': 1,
        },
        dependencyGraph: const {
          'lib/src/root.dart': ['lib/src/a_top.dart', 'lib/src/z_bottom.dart'],
          'lib/src/a_top.dart': [],
          'lib/src/z_bottom.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);
      final shortIndex = svg.indexOf(
        '<title>lib/src/root.dart ▶ lib/src/a_top.dart</title>',
      );
      final longIndex = svg.indexOf(
        '<title>lib/src/root.dart ▶ lib/src/z_bottom.dart</title>',
      );

      expect(shortIndex, greaterThanOrEqualTo(0));
      expect(longIndex, greaterThanOrEqualTo(0));
      expect(longIndex, lessThan(shortIndex));
    });

    test('same-source vertical fan-out lanes do not overlap', () {
      // One source fans to three targets in the adjacent column at different rows.
      // The non-straight edges should each get unique laneX values spaced by 2px.
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/a.dart': 0,
          'lib/src/b.dart': 1,
          'lib/src/c.dart': 1,
          'lib/src/d.dart': 1,
        },
        dependencyGraph: const {
          'lib/src/a.dart': [
            'lib/src/b.dart',
            'lib/src/c.dart',
            'lib/src/d.dart',
          ],
          'lib/src/b.dart': [],
          'lib/src/c.dart': [],
          'lib/src/d.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);

      final laneXAB = _extractFilesEdgeLaneX(
        svg,
        'lib/src/a.dart',
        'lib/src/b.dart',
      );
      final laneXAC = _extractFilesEdgeLaneX(
        svg,
        'lib/src/a.dart',
        'lib/src/c.dart',
      );
      final laneXAD = _extractFilesEdgeLaneX(
        svg,
        'lib/src/a.dart',
        'lib/src/d.dart',
      );

      // One edge may be straight (same-row) and therefore have no Q/laneX.
      final laneXs = [laneXAB, laneXAC, laneXAD].whereType<double>().toList()
        ..sort();

      expect(
        laneXs.length,
        greaterThanOrEqualTo(2),
        reason: 'at least two fan-out edges should use elbow lanes',
      );

      for (var i = 1; i < laneXs.length; i++) {
        expect(
          laneXs[i] - laneXs[i - 1],
          closeTo(2.0, 0.01),
          reason:
              'vertical fan-out lanes should be spaced by 2 px and not overlap',
        );
      }
    });

    test('non-same-row forward edges use elbow H-V-H routing', () {
      // a (col0 row0) and b (col0 row1) both point to c (col1 row0).
      // b → c crosses rows (row1 → row0) so it must use elbow routing.
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/a.dart': 0, // row 0, col 0 (a < b alphabetically)
          'lib/src/b.dart': 0, // row 1, col 0
          'lib/src/c.dart': 1, // row 0, col 1 (2 incoming → highest priority)
        },
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/c.dart'], // row0 → row0: straight
          'lib/src/b.dart': ['lib/src/c.dart'], // row1 → row0: elbow
          'lib/src/c.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);

      // b→c is an elbow edge: _extractFilesEdgeLaneX finds it via Q command.
      final laneX = _extractFilesEdgeLaneX(
        svg,
        'lib/src/b.dart',
        'lib/src/c.dart',
      );
      expect(
        laneX,
        isNotNull,
        reason: 'non-same-row edge b→c should use elbow routing (Q command)',
      );

      final preCornerX = _extractFilesEdgeFirstPreCornerX(
        svg,
        'lib/src/b.dart',
        'lib/src/c.dart',
      );
      expect(
        preCornerX,
        isNotNull,
        reason: 'elbow edge b→c should include a horizontal pre-corner segment',
      );
      expect(
        laneX! - preCornerX!,
        closeTo(_testFilesEdgeCornerRadius, 0.01),
        reason:
            'forward elbow pre-corner distance should match the fixed radius',
      );
    });

    test('parallel forward edges through same gap are staggered by 2px', () {
      // Two crossing edges through the same gap (col 0 → col 1):
      //   a (row 0) → d (row 1)  and  b (row 1) → c (row 0).
      // Both are non-same-row adjacent → elbow routing with staggered laneX.
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/a.dart': 0,
          'lib/src/b.dart': 0,
          'lib/src/c.dart': 1,
          'lib/src/d.dart': 1,
        },
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/d.dart'],
          'lib/src/b.dart': ['lib/src/c.dart'],
          'lib/src/c.dart': [],
          'lib/src/d.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);

      final laneXAD = _extractFilesEdgeLaneX(
        svg,
        'lib/src/a.dart',
        'lib/src/d.dart',
      );
      final laneXBC = _extractFilesEdgeLaneX(
        svg,
        'lib/src/b.dart',
        'lib/src/c.dart',
      );

      expect(laneXAD, isNotNull, reason: 'edge a→d should have a lane X');
      expect(laneXBC, isNotNull, reason: 'edge b→c should have a lane X');
      expect(
        laneXAD,
        isNot(equals(laneXBC)),
        reason: 'lanes should be staggered',
      );
      expect(
        (laneXAD! - laneXBC!).abs(),
        closeTo(2.0, 0.01),
        reason: 'stagger should be exactly 2 px',
      );
    });

    test('backward edges in files SVG use Bezier routing', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {'lib/src/a.dart': 0, 'lib/src/b.dart': 1},
        dependencyGraph: const {
          'lib/src/a.dart': [],
          'lib/src/b.dart': ['lib/src/a.dart'],
        },
      );

      final svg = exportGraphSvgFiles(result);

      // Backward edge (col 1 → col 0) should use cubic Bezier C command.
      expect(
        RegExp(r'<path d="M [^"]*C ').hasMatch(svg),
        isTrue,
        reason: 'backward edge should use Bezier C routing',
      );
    });

    test('skip edges route through intermediate column passage gaps', () {
      // a (col 0) → d (col 2), crossing col 1 which has two nodes (top, bot).
      // The multi-hop elbow must place its vertical transition in the gap
      // to the left of col 1, then traverse col 1 horizontally at the
      // passage Y (between the two col-1 nodes), then do the final elbow
      // at laneX in the gap between col 1 and col 2.
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {
          'lib/src/a.dart': 0,
          'lib/src/top.dart': 1,
          'lib/src/bot.dart': 1,
          'lib/src/d.dart': 2,
        },
        dependencyGraph: const {
          'lib/src/a.dart': ['lib/src/d.dart'],
          'lib/src/top.dart': [],
          'lib/src/bot.dart': [],
          'lib/src/d.dart': [],
        },
      );

      final svg = exportGraphSvgFiles(result);

      // Find the skip-edge path.
      const title = 'lib/src/a.dart ▶ lib/src/d.dart';
      final pathMatch = RegExp(
        '<path d="([^"]+)" class="edge[^"]*"/>\\s*<title>${RegExp.escape(title)}</title>',
      ).firstMatch(svg);
      expect(pathMatch, isNotNull, reason: 'skip edge a→d should be present');
      final pathData = pathMatch!.group(1)!;

      // Multi-hop path must contain at least 4 Q corners:
      //   2 for the intermediate col 1 entry/exit + 2 for the final laneX elbow.
      final qCount = RegExp(r' Q ').allMatches(pathData).length;
      expect(
        qCount,
        greaterThanOrEqualTo(4),
        reason: 'skip edge should use multi-hop routing with ≥4 Q corners',
      );
      // Must have at least 3 line segments (to col-1 gap, across col 1, to laneX).
      // The implementation uses L commands for all horizontal lines.
      final lCount = RegExp(r' L ').allMatches(pathData).length;
      expect(
        lCount,
        greaterThanOrEqualTo(3),
        reason: 'skip edge should have ≥3 L segments',
      );
    });
  });
}

double? _extractFolderEdgeColumnX(String svg, String titlePayload) {
  final pattern = RegExp(
    '<path d="[^"]*Q ([0-9]+(?:\\.[0-9]+)?) [^"]*" class="[^"]*"/>\\s*<title>${RegExp.escape(titlePayload)}</title>',
  );
  final match = pattern.firstMatch(svg);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

const double _testFilesEdgeCornerRadius = 6.0;

/// Extracts the lane X coordinate from an elbow edge in the files SVG.
///
/// Elbow path format: `M startX startY L preCornerX startY Q laneX startY laneX v1Start V ...`
/// Returns the laneX value from the first Q command in the path.
double? _extractFilesEdgeLaneX(String svg, String source, String target) {
  final pathData = _extractFilesEdgePathData(svg, source, target);
  if (pathData == null) return null;
  final qPattern = RegExp(r'Q ([0-9]+(?:\.[0-9]+)?)');
  final qMatch = qPattern.firstMatch(pathData);
  return qMatch != null ? double.tryParse(qMatch.group(1)!) : null;
}

double? _extractFilesEdgeFirstPreCornerX(
  String svg,
  String source,
  String target,
) {
  final pathData = _extractFilesEdgePathData(svg, source, target);
  if (pathData == null) return null;
  final linePattern = RegExp(
    r'^M [0-9]+(?:\.[0-9]+)? [0-9]+(?:\.[0-9]+)? L ([0-9]+(?:\.[0-9]+)?) [0-9]+(?:\.[0-9]+)? Q ',
  );
  final lineMatch = linePattern.firstMatch(pathData);
  return lineMatch != null ? double.tryParse(lineMatch.group(1)!) : null;
}

String? _extractFilesEdgePathData(String svg, String source, String target) {
  final title = '$source ▶ $target';
  final pattern = RegExp(
    '<path d="([^"]+)" class="edge[^"]*"/>\\s*<title>${RegExp.escape(title)}</title>',
  );
  final match = pattern.firstMatch(svg);
  return match?.group(1);
}
