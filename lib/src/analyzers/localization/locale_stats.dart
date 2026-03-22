/// Represents localization statistics for a supported locale.
class LocaleStats {
  /// Constant for 100% coverage percentage.
  static const double _fullCoveragePercentage = 100.0;

  /// The ISO language code (e.g., 'en', 'es', 'fr').
  final String languageCode;

  /// The display name of the language (e.g., 'English', 'Spanish', 'French').
  final String languageName;

  /// The total number of translation entries in this locale.
  final int translationCount;

  /// The number of missing translations compared to the base language.
  final int missingCount;

  /// The coverage percentage (0-100).
  final double coveragePercentage;

  /// Creates a new locale statistics object.
  const LocaleStats({
    required this.languageCode,
    required this.languageName,
    required this.translationCount,
    required this.missingCount,
    required this.coveragePercentage,
  });

  /// Whether this locale has complete translations (100% coverage).
  bool get isComplete => coveragePercentage >= _fullCoveragePercentage;

  /// Whether this locale has any translations at all.
  bool get hasTranslations => translationCount > 0;

  /// Converts this locale stats to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'languageName': languageName,
    'translationCount': translationCount,
    'missingCount': missingCount,
    'coveragePercentage': coveragePercentage,
    'isComplete': isComplete,
    'hasTranslations': hasTranslations,
  };

  @override
  String toString() => format();

  /// Returns a formatted string for CLI output.
  String format() {
    final coverageStr = coveragePercentage.toStringAsFixed(1);
    final statusStr = isComplete
        ? 'complete'
        : hasTranslations
        ? '$missingCount missing'
        : 'no translations';
    return '$languageName ($languageCode): $translationCount entries, $coverageStr% coverage ($statusStr)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocaleStats &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode;

  @override
  int get hashCode => languageCode.hashCode;
}
