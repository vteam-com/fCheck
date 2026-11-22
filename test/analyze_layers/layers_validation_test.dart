import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/analyzers/layers/layers_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('validateLayers', () {
    test('a graph without cycles nor upward dependencies has no issue', () {
      final issues = validateLayers({
        'lib/views/home.dart': ['lib/widgets/card.dart'],
        'lib/widgets/card.dart': ['lib/models/score.dart'],
        'lib/models/score.dart': [],
      });

      expect(issues, isEmpty);
    });

    test('files importing each other are a cyclic dependency', () {
      final issues = validateLayers({
        'lib/a.dart': ['lib/b.dart'],
        'lib/b.dart': ['lib/a.dart'],
      });

      expect(
        issues.map((issue) => issue.type),
        contains(LayersIssueType.cyclicDependency),
      );
    });

    test('folders depending on each other are a folder cycle', () {
      final issues = validateLayers({
        'lib/widgets/card.dart': ['lib/panels/style.dart'],
        'lib/panels/style.dart': [],
        'lib/panels/panel.dart': ['lib/widgets/card.dart'],
      });

      expect(
        issues.map((issue) => issue.type),
        contains(LayersIssueType.folderCycle),
      );
    });

    test('matches the issues the analysis reports for the same graph', () {
      final graph = {
        'lib/widgets/card.dart': ['lib/panels/style.dart'],
        'lib/panels/style.dart': <String>[],
        'lib/panels/panel.dart': ['lib/widgets/card.dart'],
      };

      final analyzed = LayersAnalyzer.forGraph().analyzeGraph(graph);

      expect(
        validateLayers(graph).map((issue) => issue.toString()),
        containsAll(analyzed.issues.map((issue) => issue.toString())),
      );
    });
  });
}
