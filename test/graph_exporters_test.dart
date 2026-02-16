import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/graphs/export_mermaid.dart';
import 'package:fcheck/src/graphs/export_plantuml.dart';
import 'package:fcheck/src/graphs/export_svg.dart';
import 'package:fcheck/src/graphs/export_svg_folders.dart';
import 'package:fcheck/src/graphs/graph_format_utils.dart';
import 'package:test/test.dart';

void main() {
  group('graph exporters', () {
    test('return empty outputs for empty graphs', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: const {},
        dependencyGraph: const {},
      );

      expect(exportGraphMermaid(result), equals(emptyMermaidGraph()));
      expect(exportGraphPlantUML(result), equals(emptyPlantUml()));
      expect(exportGraphSvg(result), contains('No dependencies found'));
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

      final svg = exportGraphSvg(result);
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

      final svg = exportGraphSvg(result);

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
        layers: const {
          'lib/utils.dart': 0,
          'lib/src/main.dart': 1,
        },
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
  });
}

double? _extractFolderEdgeColumnX(String svg, String titlePayload) {
  final pattern = RegExp(
      '<path d=\"[^\"]*Q ([0-9]+(?:\\.[0-9]+)?) [^\"]*\" class=\"[^\"]*\"/>\\s*<title>${RegExp.escape(titlePayload)}</title>');
  final match = pattern.firstMatch(svg);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}
