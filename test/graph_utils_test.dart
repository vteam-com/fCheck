import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/exports/svg/shared/badge_model.dart';
import 'package:fcheck/src/exports/externals/graph_format_utils.dart';
import 'package:fcheck/src/exports/svg/shared/svg_common.dart';
import 'package:test/test.dart';

void main() {
  group('graph_format_utils', () {
    test('prepareGraphFormatting counts edges within known layers', () {
      final result = LayersAnalysisResult(
        issues: const [],
        layers: {'lib/a.dart': 0, 'lib/b.dart': 1},
        dependencyGraph: {
          'lib/a.dart': ['lib/b.dart'],
          'lib/b.dart': ['lib/c.dart'],
        },
      );

      final formatting = prepareGraphFormatting(result);

      expect(formatting.layerGroups[0], contains('lib/a.dart'));
      expect(formatting.layerGroups[1], contains('lib/b.dart'));
      expect(formatting.outgoingCounts['lib/a.dart'], equals(1));
      expect(formatting.incomingCounts['lib/b.dart'], equals(1));
      expect(formatting.outgoingCounts['lib/b.dart'], equals(0));
    });

    test('format helpers normalize labels and ids', () {
      expect(relativeFileLabel('lib/src/a.dart'), equals('src/a.dart'));
      expect(mermaidNodeId('lib/src/a.dart'), equals('src_a'));
      expect(
        plantUmlComponentId('lib/src/foo_bar.dart'),
        equals('compsrcfoobar'),
      );
      expect(emptyMermaidGraph(), contains('No dependencies found'));
      expect(emptyPlantUml(), contains('@startuml'));
    });
  });

  group('svg_common', () {
    test('buildPeerLists aggregates and sorts incoming/outgoing peers', () {
      final graph = {
        'lib/a.dart': ['lib/b.dart', 'lib/c.dart'],
        'lib/d.dart': ['lib/b.dart'],
      };

      final peers = buildPeerLists(graph);

      expect(peers.outgoing['lib/a.dart'], equals(['b.dart', 'c.dart']));
      expect(peers.incoming['lib/b.dart'], equals(['a.dart', 'd.dart']));
    });

    test('renderEdgeWithTooltip writes path and title', () {
      final buffer = StringBuffer();

      renderEdgeWithTooltip(
        buffer,
        pathData: 'M0 0',
        source: 'a.dart',
        target: 'b.dart',
        cssClass: 'edge',
      );

      final output = buffer.toString();
      expect(output, contains('class="edge"'));
      expect(output, contains('<title>a.dart ▶ b.dart</title>'));
    });

    test('renderTriangularBadge respects zero counts', () {
      final buffer = StringBuffer();

      renderTriangularBadge(
        buffer,
        const BadgeModel(
          cx: 10,
          cy: 10,
          count: 0,
          direction: BadgeDirection.west,
          isIncoming: true,
        ),
      );

      expect(buffer.toString(), isEmpty);

      renderTriangularBadge(
        buffer,
        const BadgeModel(
          cx: 10,
          cy: 10,
          count: 2,
          direction: BadgeDirection.east,
          isIncoming: false,
        ),
      );

      expect(buffer.toString(), contains('<path'));
    });
  });

  group('BadgeModel', () {
    test('renderSvg returns empty string when count is zero', () {
      final badge = BadgeModel.incoming(
        cx: 0,
        cy: 0,
        count: 0,
        direction: BadgeDirection.west,
      );

      expect(badge.renderSvg(), isEmpty);
    });

    test('renderSvg includes tooltip for peers', () {
      final badge = BadgeModel.outgoing(
        cx: 4,
        cy: 8,
        count: 3,
        direction: BadgeDirection.east,
        peers: ['a.dart', 'b.dart'],
      );

      final svg = badge.renderSvg();
      expect(svg, contains('outgoingBadge'));
      expect(svg, contains('<title>1. a.dart'));
      expect(svg, contains('2. b.dart'));
    });
  });
}
