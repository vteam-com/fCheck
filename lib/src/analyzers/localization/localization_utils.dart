import 'package:path/path.dart' as p;

/// Default locale code used when a file cannot provide a better fallback.
const String localizationDefaultBaseLanguageCode = 'en';

/// Reasons a localization value can be treated as incomplete.
enum LocalizationTranslationProblemType {
  /// The translation key is absent or does not contain a string value.
  missing,

  /// The translation exists but is empty after trimming whitespace.
  empty,

  /// The translation still matches the base locale string.
  unchanged,

  /// The translation does not preserve placeholder structure.
  placeholderMismatch,

  /// The same key appears multiple times in the ARB file.
  duplicateKey,

  /// The base-language key exists in ARB but is never referenced in app code.
  unusedKey,
}

/// Mapping from primary locale subtags to display names.
const Map<String, String> localizationLanguageNamesByCode = {
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'th': 'Thai',
  'vi': 'Vietnamese',
  'sv': 'Swedish',
  'da': 'Danish',
  'no': 'Norwegian',
  'fi': 'Finnish',
  'pl': 'Polish',
  'tr': 'Turkish',
  'nl': 'Dutch',
  'cs': 'Czech',
  'hu': 'Hungarian',
  'ro': 'Romanian',
  'bg': 'Bulgarian',
  'hr': 'Croatian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'et': 'Estonian',
  'lv': 'Latvian',
  'lt': 'Lithuanian',
  'ga': 'Irish',
  'eu': 'Basque',
  'ca': 'Catalan',
  'gl': 'Galician',
  'is': 'Icelandic',
  'mk': 'Macedonian',
  'sr': 'Serbian',
  'bs': 'Bosnian',
  'me': 'Montenegrin',
  'sq': 'Albanian',
  'be': 'Belarusian',
  'uk': 'Ukrainian',
  'el': 'Greek',
  'he': 'Hebrew',
  'fa': 'Persian',
  'ur': 'Urdu',
  'bn': 'Bengali',
  'ta': 'Tamil',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'gu': 'Gujarati',
  'pa': 'Punjabi',
  'mr': 'Marathi',
  'ne': 'Nepali',
  'si': 'Sinhala',
  'my': 'Myanmar',
  'km': 'Khmer',
  'lo': 'Lao',
  'ka': 'Georgian',
  'am': 'Amharic',
  'sw': 'Swahili',
  'zu': 'Zulu',
  'af': 'Afrikaans',
  'mt': 'Maltese',
  'cy': 'Welsh',
};

final RegExp _primaryLocaleCodePattern = RegExp(r'^[a-z]{2,3}$');
final RegExp _placeholderPattern = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}');
final RegExp _arbKeyLinePattern = RegExp(r'^  "([^"]+)"\s*:');
final RegExp _doNotTranslatePattern = RegExp(
  r'\bdo\s*not\s*translate\b|\bdo\s*not\s*localize\b|\bdo\s*not\s*localise\b|\bkeep\s*as\s*is\b|\bleave\s*unchanged\b|\bignore\b|\breviewed\b',
  caseSensitive: false,
);

/// Normalizes an ARB file path into a locale identifier.
///
/// Supports files such as:
/// - `en.arb`
/// - `app_en.arb`
/// - `app_pt_BR.arb`
/// - `zh_Hans.arb`
String? extractLocalizationLocaleIdFromArbPath(String arbFilePath) {
  final fileName = p.basenameWithoutExtension(arbFilePath);
  final cleanName = fileName
      .replaceFirst(RegExp(r'^app_'), '')
      .replaceFirst(RegExp(r'^messages_'), '')
      .replaceFirst(RegExp(r'^l10n_'), '');
  if (cleanName.isEmpty) {
    return null;
  }

  final normalized = cleanName.replaceAll('-', '_');
  final segments = normalized
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return null;
  }

  final primaryLanguageCode = segments.first.toLowerCase();
  if (!_primaryLocaleCodePattern.hasMatch(primaryLanguageCode)) {
    return null;
  }

  if (segments.length == 1) {
    return primaryLanguageCode;
  }

  final suffix = segments.skip(1).join('_');
  return '${primaryLanguageCode}_$suffix';
}

/// Returns a display name for a locale or language code.
String localizationLanguageNameForCode(String languageCode) {
  final primaryLanguageCode = languageCode
      .toLowerCase()
      .split(RegExp(r'[_-]'))
      .first;
  return localizationLanguageNamesByCode[primaryLanguageCode] ??
      primaryLanguageCode.toUpperCase();
}

/// Returns a user-facing label for a localization problem type.
String localizationProblemLabel(LocalizationTranslationProblemType type) {
  switch (type) {
    case LocalizationTranslationProblemType.missing:
      return 'missing';
    case LocalizationTranslationProblemType.empty:
      return 'empty';
    case LocalizationTranslationProblemType.unchanged:
      return 'unchanged';
    case LocalizationTranslationProblemType.placeholderMismatch:
      return 'placeholder mismatch';
    case LocalizationTranslationProblemType.duplicateKey:
      return 'duplicate key';
    case LocalizationTranslationProblemType.unusedKey:
      return 'unused key';
  }
}

/// Finds all translation keys in an ARB file, excluding metadata entries.
Set<String> extractLocalizationTranslationKeys(
  Map<String, dynamic> arbContent,
) {
  final keys = <String>{};
  for (final entry in arbContent.entries) {
    final key = entry.key;
    if (key.startsWith('@')) {
      continue;
    }
    if (key.startsWith('@@')) {
      continue;
    }
    keys.add(key);
  }
  return keys;
}

/// Returns line numbers for top-level translatable keys found in an ARB file.
///
/// The result maps each translation key to the first line that declares it.
/// Metadata entries such as `@foo` and `@@locale` are ignored.
Map<String, int> extractLocalizationKeyLineNumbers(String arbContent) {
  final lineNumbersByKey = <String, int>{};
  final lines = arbContent.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final match = _arbKeyLinePattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }
    final key = match.group(1);
    if (key == null || key.startsWith('@')) {
      continue;
    }
    lineNumbersByKey.putIfAbsent(key, () => index + 1);
  }
  return lineNumbersByKey;
}

/// Returns all line numbers for top-level translatable keys found in an ARB file.
///
/// The result maps each translation key to every line that declares it so
/// callers can detect duplicate entries. Metadata entries such as `@foo` and
/// `@@locale` are ignored.
Map<String, List<int>> extractLocalizationKeyOccurrenceLineNumbers(
  String arbContent,
) {
  final occurrenceLineNumbersByKey = <String, List<int>>{};
  final lines = arbContent.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final match = _arbKeyLinePattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }
    final key = match.group(1);
    if (key == null || key.startsWith('@')) {
      continue;
    }
    occurrenceLineNumbersByKey.putIfAbsent(key, () => <int>[]).add(index + 1);
  }
  return occurrenceLineNumbersByKey;
}

/// Returns duplicate line numbers for top-level translatable keys found in an ARB file.
///
/// The first occurrence of each key is treated as the canonical definition and
/// omitted; only repeated entries are returned.
Map<String, List<int>> extractLocalizationDuplicateKeyLineNumbers(
  String arbContent,
) {
  final duplicateLineNumbersByKey = <String, List<int>>{};
  final occurrences = extractLocalizationKeyOccurrenceLineNumbers(arbContent);
  for (final entry in occurrences.entries) {
    if (entry.value.length <= 1) {
      continue;
    }
    duplicateLineNumbersByKey[entry.key] = entry.value.skip(1).toList();
  }
  return duplicateLineNumbersByKey;
}

/// Returns true when an ARB key explicitly instructs translators not to translate it.
///
/// This checks common guidance phrases in the `@key.description` metadata in
/// either the base ARB or the translated ARB.
bool isLocalizationKeyMarkedDoNotTranslate(
  Map<String, dynamic> arbContent,
  String key,
) {
  final metadata = arbContent['@$key'];
  if (metadata is! Map) {
    return false;
  }
  final description = metadata['description'];
  if (description is! String || description.trim().isEmpty) {
    return false;
  }
  return _doNotTranslatePattern.hasMatch(description);
}

/// Finds the base language ARB file, preferring English and then alphabetical.
String? findLocalizationBaseLanguageFile(List<String> arbFilePaths) {
  if (arbFilePaths.isEmpty) {
    return null;
  }

  final sortedPaths = List<String>.from(arbFilePaths)..sort();
  for (final path in sortedPaths) {
    final localeId = extractLocalizationLocaleIdFromArbPath(path);
    if (localeId == null) {
      continue;
    }
    final languageCode = localeId.split(RegExp(r'[_-]')).first.toLowerCase();
    if (languageCode == localizationDefaultBaseLanguageCode) {
      return path;
    }
  }

  return sortedPaths.first;
}

/// Classifies a target translation as incomplete, or returns null if valid.
LocalizationTranslationProblemType? classifyLocalizationTranslationProblem({
  required dynamic baseValue,
  required dynamic targetValue,
}) {
  if (targetValue is! String) {
    return LocalizationTranslationProblemType.missing;
  }

  final targetText = targetValue.trim();
  if (targetText.isEmpty) {
    return LocalizationTranslationProblemType.empty;
  }

  if (baseValue is! String) {
    return LocalizationTranslationProblemType.missing;
  }

  if (targetValue == baseValue) {
    return LocalizationTranslationProblemType.unchanged;
  }

  final basePlaceholders = _extractPlaceholders(baseValue);
  if (basePlaceholders.isEmpty) {
    return null;
  }

  final targetPlaceholders = _extractPlaceholders(targetValue);
  return basePlaceholders.difference(targetPlaceholders).isNotEmpty ||
          targetPlaceholders.difference(basePlaceholders).isNotEmpty
      ? LocalizationTranslationProblemType.placeholderMismatch
      : null;
}

Set<String> _extractPlaceholders(String value) {
  return _placeholderPattern
      .allMatches(value)
      .map((match) => match.group(1))
      .whereType<String>()
      .toSet();
}
