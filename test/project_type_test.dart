import 'package:fcheck/src/models/project_type.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectType', () {
    test('flutter label returns "Flutter"', () {
      expect(ProjectType.flutter.label, equals('Flutter'));
    });

    test('dart label returns "Dart"', () {
      expect(ProjectType.dart.label, equals('Dart'));
    });

    test('unknown label returns "Unknown"', () {
      expect(ProjectType.unknown.label, equals('Unknown'));
    });

    test('all enum values are accessible', () {
      expect(ProjectType.values, hasLength(3));
      expect(ProjectType.values, contains(ProjectType.flutter));
      expect(ProjectType.values, contains(ProjectType.dart));
      expect(ProjectType.values, contains(ProjectType.unknown));
    });
  });
}
