import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
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
      expect(filesSvg, contains('#f2a23a'));
      expect(filesSvg, contains('#e05545'));

      final foldersSvg = exportGraphSvgFolders(result);
      expect(foldersSvg, contains('#f2a23a'));
      expect(foldersSvg, contains('#e05545'));
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
        expect(filesSvg, contains('#f2a23a'));
        expect(filesSvg, contains('File: lib/src/a.dart'));
        expect(filesSvg, contains('1 Magic Numbers warning'));

        final foldersSvg = exportGraphSvgFolders(
          result,
          projectMetrics: metrics,
        );
        expect(foldersSvg, contains('#f2a23a'));
        expect(foldersSvg, contains('File: a.dart'));
        expect(foldersSvg, contains('Folder: .'));
        expect(foldersSvg, contains('1 Magic Numbers warning'));
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
      expect(svg, contains('#f2a23a'));
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
