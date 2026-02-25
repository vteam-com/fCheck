import 'package:path/path.dart' as p;

/// Returns true when [path] points to a generated Dart source file.
///
/// Generated Dart files are identified by the conventional filename suffix
/// `*.g.dart` (for example `model.g.dart`).
bool isGeneratedDartFilePath(String path) {
  return p.basename(path).endsWith('.g.dart');
}

/// Returns true when [path] is a generated Flutter localization Dart file.
///
/// Matches:
/// - `app_localizations.dart`
/// - `app_localizations_<locale>.dart`
/// - `app_localization_<locale>.dart`
bool isGeneratedLocalizationDartFilePath(String path) {
  final fileName = p.basename(path);
  if (fileName == 'app_localizations.dart') {
    return true;
  }
  return (fileName.startsWith('app_localizations_') ||
          fileName.startsWith('app_localization_')) &&
      fileName.endsWith('.dart');
}

/// Returns true when [path] belongs to `lib/l10n/` in the project tree.
bool isLibL10nPath(String path) {
  final normalized = p.normalize(path);
  final pathParts = p.split(normalized);
  for (var i = 0; i < pathParts.length - 1; i++) {
    if (pathParts[i] == 'lib' && pathParts[i + 1] == 'l10n') {
      return true;
    }
  }
  return false;
}
