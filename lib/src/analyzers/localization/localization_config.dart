import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The `flutter gen-l10n` settings of a project, from its `l10n.yaml` or
/// Flutter's defaults.
class LocalizationConfig {
  /// Creates settings; every value defaults to Flutter's.
  const LocalizationConfig({
    this.arbDir = defaultArbDir,
    this.templateArbFile = _defaultTemplateArbFile,
    this.outputClass = _defaultOutputClass,
    this.outputFile = _defaultOutputFile,
    this.outputDir,
    this.syntheticPackage = false,
  });

  /// The ARB folder when `l10n.yaml` does not set one.
  static const String defaultArbDir = 'lib/l10n';
  static const String _defaultTemplateArbFile = 'app_en.arb';
  static const String _defaultOutputClass = 'AppLocalizations';
  static const String _defaultOutputFile = 'app_localizations.dart';
  static const String _fileName = 'l10n.yaml';

  /// Project-relative folder of the ARB files.
  final String arbDir;

  /// Name of the generated class.
  final String outputClass;

  /// Project-relative folder of the generated files; [arbDir] when null.
  final String? outputDir;

  /// File name of the generated class.
  final String outputFile;

  /// Whether the classes are generated into the `flutter_gen` package.
  final bool syntheticPackage;

  /// File name of the template ARB file.
  final String templateArbFile;

  /// Reads the settings of the project in [projectDir]; the defaults when
  /// it has no readable `l10n.yaml`.
  static LocalizationConfig load(Directory projectDir) {
    final file = File(p.join(projectDir.path, _fileName));
    if (!file.existsSync()) return const LocalizationConfig();
    try {
      final Object? yaml = loadYaml(file.readAsStringSync());
      if (yaml is! YamlMap) return const LocalizationConfig();
      String text(String key, String fallback) {
        final Object? value = yaml[key];
        return value is String && value.trim().isNotEmpty
            ? value.trim()
            : fallback;
      }

      final Object? outputDir = yaml['output-dir'];
      return LocalizationConfig(
        arbDir: text('arb-dir', defaultArbDir),
        templateArbFile: text('template-arb-file', _defaultTemplateArbFile),
        outputClass: text('output-class', _defaultOutputClass),
        outputFile: text('output-localization-file', _defaultOutputFile),
        outputDir: outputDir is String ? outputDir.trim() : null,
        syntheticPackage: yaml['synthetic-package'] == true,
      );
    } on Exception {
      return const LocalizationConfig();
    }
  }
}
