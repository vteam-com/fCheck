import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:test/test.dart';

void main() {
  group('LayersIssue', () {
    test('toString includes type, file path, and message', () {
      final issue = LayersIssue(
        type: LayersIssueType.cyclicDependency,
        filePath: 'lib/a.dart',
        message: 'Cyclic dependency detected involving lib/b.dart',
      );

      expect(
        issue.toString(),
        equals(
          '[LayersIssueType.cyclicDependency] lib/a.dart: '
          'Cyclic dependency detected involving lib/b.dart',
        ),
      );
    });

    test('toJson serializes cyclic dependency type', () {
      final issue = LayersIssue(
        type: LayersIssueType.cyclicDependency,
        filePath: 'lib/a.dart',
        message: 'Cycle found',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'cyclicDependency',
          'filePath': 'lib/a.dart',
          'message': 'Cycle found',
        }),
      );
    });

    test('toJson serializes wrong layer type', () {
      final issue = LayersIssue(
        type: LayersIssueType.wrongLayer,
        filePath: 'lib/presentation/screen.dart',
        message: 'Component is in wrong layer',
      );

      expect(
        issue.toJson(),
        equals({
          'type': 'wrongLayer',
          'filePath': 'lib/presentation/screen.dart',
          'message': 'Component is in wrong layer',
        }),
      );
    });
  });
}
