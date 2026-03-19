import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/analyzers/localization/locale_stats.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';
import 'package:fcheck/src/models/constants.dart';
import 'package:path/path.dart' as p;

/// Scan result for localization coverage data.
class LocalizationReportScanResult {
  /// Creates a localization scan result.
  const LocalizationReportScanResult({
    required this.localeStats,
    required this.baseLocaleCode,
    required this.baseTranslationCount,
  });

  /// Locale coverage statistics keyed by locale identifier.
  final Map<String, LocaleStats> localeStats;

  /// Detected base locale identifier, if one could be resolved.
  final String? baseLocaleCode;

  /// Number of translatable strings in the base locale.
  final int baseTranslationCount;
}

/// Scans ARB files under `lib/l10n` and returns locale coverage statistics.
LocalizationReportScanResult scanLocalizationLocales(String analysisRootPath) {
  final localeStats = <String, LocaleStats>{};
  if (analysisRootPath.trim().isEmpty) {
    return const LocalizationReportScanResult(
      localeStats: {},
      baseLocaleCode: null,
      baseTranslationCount: 0,
    );
  }

  final l10nDir = Directory(p.join(analysisRootPath, 'lib', 'l10n'));
  if (!l10nDir.existsSync()) {
    return const LocalizationReportScanResult(
      localeStats: {},
      baseLocaleCode: null,
      baseTranslationCount: 0,
    );
  }

  final arbFiles = <File>[];
  for (final entity in l10nDir.listSync(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.arb')) {
      arbFiles.add(entity);
    }
  }
  if (arbFiles.isEmpty) {
    return const LocalizationReportScanResult(
      localeStats: {},
      baseLocaleCode: null,
      baseTranslationCount: 0,
    );
  }

  final parsedFiles = <String, Map<String, dynamic>>{};
  for (final file in arbFiles) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) {
        parsedFiles[file.path] = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      continue;
    }
  }
  if (parsedFiles.isEmpty) {
    return const LocalizationReportScanResult(
      localeStats: {},
      baseLocaleCode: null,
      baseTranslationCount: 0,
    );
  }

  final basePath = findLocalizationBaseLanguageFile(parsedFiles.keys.toList());
  if (basePath == null) {
    return const LocalizationReportScanResult(
      localeStats: {},
      baseLocaleCode: null,
      baseTranslationCount: 0,
    );
  }

  final baseKeys = extractLocalizationTranslationKeys(
    parsedFiles[basePath] ?? const {},
  );
  final baseTranslations = parsedFiles[basePath] ?? const {};
  final translatableBaseKeys = baseKeys
      .where(
        (key) => !isLocalizationKeyMarkedDoNotTranslate(baseTranslations, key),
      )
      .toList(growable: false);
  final baseLocaleCode = extractLocalizationLocaleIdFromArbPath(basePath);
  final baseTranslationCount = translatableBaseKeys.length;
  if (translatableBaseKeys.isEmpty) {
    return LocalizationReportScanResult(
      localeStats: const {},
      baseLocaleCode: baseLocaleCode,
      baseTranslationCount: baseTranslationCount,
    );
  }

  for (final entry in parsedFiles.entries) {
    final localeCode = extractLocalizationLocaleIdFromArbPath(entry.key);
    if (localeCode == null) {
      continue;
    }

    var missingCount = 0;
    for (final key in translatableBaseKeys) {
      if (isLocalizationKeyMarkedDoNotTranslate(entry.value, key)) {
        continue;
      }
      final problem = classifyLocalizationTranslationProblem(
        baseValue: baseTranslations[key],
        targetValue: entry.value[key],
      );
      if (problem == null) {
        continue;
      }
      missingCount++;
    }
    final translatedCount = translatableBaseKeys.length - missingCount;
    final coverage = translatableBaseKeys.isEmpty
        ? 0.0
        : (translatedCount / translatableBaseKeys.length) *
              AppConstants.fullPercentage;

    localeStats[localeCode] = LocaleStats(
      languageCode: localeCode,
      languageName: localizationLanguageNameForCode(localeCode),
      translationCount: translatedCount,
      missingCount: missingCount,
      coveragePercentage: coverage,
    );
  }

  return LocalizationReportScanResult(
    localeStats: localeStats,
    baseLocaleCode: baseLocaleCode,
    baseTranslationCount: baseTranslationCount,
  );
}
