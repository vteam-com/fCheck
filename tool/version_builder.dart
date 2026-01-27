// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:build/build.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

/// Generates `lib/src/version.dart` with the package version from `pubspec.yaml`.
Builder versionBuilder(BuilderOptions options) => _VersionBuilder();

class _VersionBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    r'$package$': ['lib/src/version.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final pubspecId = AssetId(buildStep.inputId.package, 'pubspec.yaml');
    final pubspecContent = await buildStep.readAsString(pubspecId);
    final pubspec = Pubspec.parse(pubspecContent);
    final version = pubspec.version?.toString() ?? '0.0.0';

    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln('/// Package version, generated from pubspec.yaml.')
      ..writeln("const String packageVersion = '$version';");

    final outputId = AssetId(buildStep.inputId.package, 'lib/src/version.dart');
    await buildStep.writeAsString(outputId, buffer.toString());
  }
}
