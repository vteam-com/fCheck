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
  });
}
