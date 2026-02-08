/// The detected type of the analyzed project.
enum ProjectType {
  /// Flutter application or package (depends on `flutter`).
  flutter,

  /// Pure Dart project (no `flutter` dependency found).
  dart,

  /// Unknown project type (pubspec.yaml missing or unreadable).
  unknown,
}

/// Adds presentation helpers for [ProjectType].
extension ProjectTypeLabel on ProjectType {
  /// Human-readable label for the project type.
  String get label {
    switch (this) {
      case ProjectType.flutter:
        return 'Flutter';
      case ProjectType.dart:
        return 'Dart';
      case ProjectType.unknown:
        return 'Unknown';
    }
  }
}
