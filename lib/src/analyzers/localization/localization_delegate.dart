import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue_detail.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:path/path.dart' as p;

const Set<String> _knownLocalizationAccessorNames = {
  'l10n',
  'loc',
  'locale',
  'localizations',
  'strings',
};

final RegExp _localizationMemberAccessPattern = RegExp(
  r'\b(?:AppLocalizations|S)\.of\([^)]*\)[!?]?\.([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|\b)',
);
final RegExp _currentLocalizationMemberAccessPattern = RegExp(
  r'\b(?:AppLocalizations|S)\.current\.([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|\b)',
);
final RegExp _contextL10nMemberAccessPattern = RegExp(
  r'\b[A-Za-z_][A-Za-z0-9_]*\.l10n\.([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|\b)',
);
final RegExp _typedLocalizationVariablePattern = RegExp(
  r'\b(?:AppLocalizations(?:[A-Za-z_][A-Za-z0-9_]*)?|S)\??\s+([A-Za-z_][A-Za-z0-9_]*)\b',
);
final RegExp _assignedLocalizationVariablePattern = RegExp(
  r'\b(?:final|var|const|[A-Za-z_][A-Za-z0-9_<>,?]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:(?:AppLocalizations|S)\.of\([^)]*\)|[A-Za-z_][A-Za-z0-9_]*\.l10n)\b',
);

class _ParsedLocalizationArbFile {
  const _ParsedLocalizationArbFile({
    required this.filePath,
    required this.content,
    required this.lineNumbersByKey,
    required this.duplicateLineNumbersByKey,
  });

  final String filePath;
  final Map<String, dynamic> content;
  final Map<String, int> lineNumbersByKey;
  final Map<String, List<int>> duplicateLineNumbersByKey;
}

class _LocalizationKeyUsageScanResult {
  const _LocalizationKeyUsageScanResult({
    required this.hasLocalizationAccess,
    required this.usedKeys,
  });

  final bool hasLocalizationAccess;
  final Set<String> usedKeys;
}

/// Delegate adapter for localization coverage analysis.
class LocalizationDelegate implements AnalyzerDelegate {
  /// Whether to automatically fix ARB files by sorting keys and removing
  /// duplicate entries.
  final bool fix;

  /// Creates a delegate for localization analysis.
  ///
  /// When [fix] is true, [analyzeProject] will rewrite each ARB file with
  /// its keys sorted alphabetically (keeping each `key` / `@key` pair
  /// together) and any duplicate keys removed.
  LocalizationDelegate({this.fix = false});

  /// Analyzes a project for localization coverage.
  ///
  /// This method scans for ARB files and analyzes translation completeness
  /// across all supported languages.
  ///
  /// [context] The file context (not used for localization analysis as it's project-wide).
  ///
  /// Returns a list of [LocalizationIssue] objects representing
  /// missing translations for each language.
  @override
  List<LocalizationIssue> analyzeFileWithContext(AnalysisFileContext context) {
    // Skip analysis for individual files - localization is project-wide
    // We'll handle this in a project-level analyzer instead
    return [];
  }

  /// Performs project-wide localization analysis.
  ///
  /// [projectDir] The root directory of the project to analyze.
  ///
  /// Returns a list of [LocalizationIssue] objects representing
  /// missing translations for each language.
  List<LocalizationIssue> analyzeProject(
    Directory projectDir, {
    List<AnalysisFileContext> analyzedContexts = const [],
  }) {
    final issues = <LocalizationIssue>[];

    final l10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    final primaryArbFiles = l10nDir.existsSync()
        ? _findArbFiles(l10nDir)
        : <File>[];
    final arbFiles = primaryArbFiles.isNotEmpty
        ? primaryArbFiles
        : _findArbFiles(projectDir);
    if (arbFiles.isEmpty) {
      return issues;
    }

    return _analyzeArbFiles(
      projectDir,
      arbFiles,
      analyzedContexts: analyzedContexts,
    );
  }

  // /// Performs detailed localization analysis with locale statistics.
  // ///
  // /// [projectDir] The root directory of the project to analyze.
  // ///
  // /// Returns a [LocalizationAnalysisResult] containing both issues
  // /// and detailed locale statistics.
  // LocalizationAnalysisResult analyzeProjectWithStats(Directory projectDir) {
  //   final issues = <LocalizationIssue>[];
  //   final localeStats = <LocaleStats>[];

  //   // Skip if no l10n directory or ARB files
  //   final l10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
  //   if (!l10nDir.existsSync()) {
  //     return const LocalizationAnalysisResult(
  //       issues: [],
  //       localeStats: [],
  //       baseLanguageCode: 'en',
  //       baseLanguageName: 'English',
  //       totalBaseKeys: 0,
  //     );
  //   }

  //   // Find all ARB files
  //   final arbFiles = _findArbFiles(l10nDir);
  //   if (arbFiles.isEmpty) {
  //     return const LocalizationAnalysisResult(
  //       issues: [],
  //       localeStats: [],
  //       baseLanguageCode: 'en',
  //       baseLanguageName: 'English',
  //       totalBaseKeys: 0,
  //     );
  //   }

  //   // Parse ARB files and extract translation keys
  //   final Map<String, Map<String, dynamic>> parsedArbFiles = {};
  //   for (final arbFile in arbFiles) {
  //     try {
  //       final content = arbFile.readAsStringSync();
  //       final yaml = loadYaml(content);
  //       if (yaml is Map) {
  //         parsedArbFiles[arbFile.path] = Map<String, dynamic>.from(yaml);
  //       }
  //     } catch (_) {
  //       // Skip malformed ARB files
  //       continue;
  //     }
  //   }

  //   if (parsedArbFiles.isEmpty) {
  //     return const LocalizationAnalysisResult(
  //       issues: [],
  //       localeStats: [],
  //       baseLanguageCode: 'en',
  //       baseLanguageName: 'English',
  //       totalBaseKeys: 0,
  //     );
  //   }

  //   // Identify base language file (usually en.arb or app_en.arb)
  //   final baseLanguageFile = _findBaseLanguageFile(
  //     parsedArbFiles.keys.toList(),
  //   );
  //   if (baseLanguageFile == null) {
  //     return const LocalizationAnalysisResult(
  //       issues: [],
  //       localeStats: [],
  //       baseLanguageCode: 'en',
  //       baseLanguageName: 'English',
  //       totalBaseKeys: 0,
  //     );
  //   }

  //   final baseTranslations = parsedArbFiles[baseLanguageFile] ?? {};
  //   final baseKeys = _extractTranslationKeys(baseTranslations);
  //   final baseLanguageCode =
  //       _extractLanguageCode(baseLanguageFile) ?? _defaultBaseLanguage;
  //   final baseLanguageName = _getLanguageName(baseLanguageCode);

  //   if (baseKeys.isEmpty) {
  //     return LocalizationAnalysisResult(
  //       issues: [],
  //       localeStats: [],
  //       baseLanguageCode: baseLanguageCode,
  //       baseLanguageName: baseLanguageName,
  //       totalBaseKeys: 0,
  //     );
  //   }

  //   // Analyze each language file for completeness and collect stats
  //   for (final entry in parsedArbFiles.entries) {
  //     if (entry.key == baseLanguageFile) {
  //       continue; // Skip base language
  //     }

  //     final languageCode = _extractLanguageCode(entry.key);
  //     if (languageCode == null) {
  //       continue;
  //     }

  //     final translations = entry.value;
  //     final keys = _extractTranslationKeys(translations);
  //     final missingCount = baseKeys.where((key) => !keys.contains(key)).length;

  //     // Create issue for missing translations
  //     if (missingCount > 0) {
  //       final issue = LocalizationIssue(
  //         languageCode: languageCode,
  //         languageName: _getLanguageName(languageCode),
  //         missingCount: missingCount,
  //         totalCount: baseKeys.length,
  //       );
  //       issues.add(issue);
  //     }

  //     // Create locale statistics
  //     final localeStat = LocaleStats(
  //       languageCode: languageCode,
  //       languageName: _getLanguageName(languageCode),
  //       translationCount: keys.length,
  //       missingCount: missingCount,
  //       coveragePercentage: baseKeys.isNotEmpty
  //           ? ((baseKeys.length - missingCount) / baseKeys.length) * 100.0
  //           : 100.0,
  //     );
  //     localeStats.add(localeStat);
  //   }

  //   return LocalizationAnalysisResult(
  //     issues: issues,
  //     localeStats: localeStats,
  //     baseLanguageCode: baseLanguageCode,
  //     baseLanguageName: baseLanguageName,
  //     totalBaseKeys: baseKeys.length,
  //   );
  // }

  /// Finds all ARB files in the specified directory and subdirectories.
  List<File> _findArbFiles(Directory dir) {
    final arbFiles = <File>[];

    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.arb')) {
          arbFiles.add(entity);
        }
      }
      arbFiles.sort((left, right) => left.path.compareTo(right.path));
    } catch (_) {
      // Return empty list if directory can't be read
    }

    return arbFiles;
  }

  /// Finds the base language ARB file (typically English).
  String? _findBaseLanguageFile(List<String> arbFilePaths) {
    return findLocalizationBaseLanguageFile(arbFilePaths);
  }

  /// Extracts translation keys from ARB file content.
  Set<String> _extractTranslationKeys(Map<String, dynamic> arbContent) {
    return extractLocalizationTranslationKeys(arbContent);
  }

  /// Extracts the locale identifier from an ARB file path.
  String? _extractLanguageCode(String arbFilePath) {
    return extractLocalizationLocaleIdFromArbPath(arbFilePath);
  }

  /// Gets display name for language code.
  String _getLanguageName(String languageCode) {
    return localizationLanguageNameForCode(languageCode);
  }

  /// Compares parsed ARB contents against the base locale and emits issues.
  ///
  /// The comparison counts missing, empty, unchanged, or placeholder-drifted
  /// translations as incomplete for the target locale.
  List<LocalizationIssue> _analyzeParsedArbFiles(
    Directory projectDir,
    List<_ParsedLocalizationArbFile> parsedArbFiles, {
    List<AnalysisFileContext> analyzedContexts = const [],
  }) {
    final issues = <LocalizationIssue>[];
    final parsedFilesByPath = {
      for (final parsedFile in parsedArbFiles) parsedFile.filePath: parsedFile,
    };
    final baseLanguageFile = _findBaseLanguageFile(
      parsedFilesByPath.keys.toList(),
    );
    if (baseLanguageFile == null) {
      return issues;
    }

    final baseParsedFile = parsedFilesByPath[baseLanguageFile];
    if (baseParsedFile == null) {
      return issues;
    }

    final baseTranslations = baseParsedFile.content;
    final baseKeys = _extractTranslationKeys(baseTranslations);
    final translatableBaseKeys = baseKeys
        .where(
          (key) =>
              !isLocalizationKeyMarkedDoNotTranslate(baseTranslations, key),
        )
        .toList(growable: false);
    if (translatableBaseKeys.isEmpty) {
      final duplicateIssues = _collectDuplicateIssues(
        parsedArbFiles: parsedArbFiles,
        baseTranslationCount: translatableBaseKeys.length,
      );
      return duplicateIssues;
    }

    final baseLanguageCode = _extractLanguageCode(baseLanguageFile);
    final usageScan =
        baseLanguageCode != null &&
            baseLanguageCode.split('_').first ==
                localizationDefaultBaseLanguageCode
        ? _collectUsedLocalizationKeys(
            projectDir: projectDir,
            candidateKeys: translatableBaseKeys.toSet(),
            analyzedContexts: analyzedContexts,
          )
        : const _LocalizationKeyUsageScanResult(
            hasLocalizationAccess: false,
            usedKeys: <String>{},
          );
    final usedBaseKeys = usageScan.usedKeys;
    final unusedBaseKeys =
        baseLanguageCode != null &&
            baseLanguageCode.split('_').first ==
                localizationDefaultBaseLanguageCode &&
            usageScan.hasLocalizationAccess
        ? translatableBaseKeys
              .where((key) => !usedBaseKeys.contains(key))
              .toList(growable: false)
        : const <String>[];
    final issueDataByLocale = <String, _LocalizationIssueData>{};
    void addDetail(
      String localeCode, {
      required int totalCount,
      required String languageName,
      required LocalizationTranslationProblemType problemType,
      required String filePath,
      required int lineNumber,
      required String key,
      bool countsAsMissing = true,
    }) {
      final data = issueDataByLocale.putIfAbsent(
        localeCode,
        () => _LocalizationIssueData(
          languageCode: localeCode,
          languageName: languageName,
          totalCount: totalCount,
        ),
      );
      if (countsAsMissing) {
        data.missingCount++;
      }
      data.problemCounts[problemType] =
          (data.problemCounts[problemType] ?? 0) + 1;
      data.details.add(
        LocalizationIssueDetail(
          filePath: filePath,
          lineNumber: lineNumber,
          key: key,
          problemType: problemType,
        ),
      );
    }

    for (final parsedFile in parsedArbFiles) {
      final localeCode = _extractLanguageCode(parsedFile.filePath);
      if (localeCode == null) {
        continue;
      }

      if (parsedFile.filePath == baseLanguageFile) {
        for (final entry in parsedFile.duplicateLineNumbersByKey.entries) {
          for (final lineNumber in entry.value) {
            addDetail(
              localeCode,
              totalCount: translatableBaseKeys.length,
              languageName: _getLanguageName(localeCode),
              problemType: LocalizationTranslationProblemType.duplicateKey,
              filePath: parsedFile.filePath,
              lineNumber: lineNumber,
              key: entry.key,
              countsAsMissing: false,
            );
          }
        }
        continue;
      }

      final translations = parsedFile.content;
      for (final key in translatableBaseKeys) {
        if (isLocalizationKeyMarkedDoNotTranslate(translations, key)) {
          continue;
        }
        final duplicateLineNumbers = parsedFile.duplicateLineNumbersByKey[key];
        if (duplicateLineNumbers != null && duplicateLineNumbers.isNotEmpty) {
          for (final lineNumber in duplicateLineNumbers) {
            addDetail(
              localeCode,
              totalCount: translatableBaseKeys.length,
              languageName: _getLanguageName(localeCode),
              problemType: LocalizationTranslationProblemType.duplicateKey,
              filePath: parsedFile.filePath,
              lineNumber: lineNumber,
              key: key,
              countsAsMissing: false,
            );
          }
          continue;
        }
        final problem = classifyLocalizationTranslationProblem(
          baseValue: baseTranslations[key],
          targetValue: translations[key],
        );
        if (problem != null) {
          final detailFilePath =
              problem == LocalizationTranslationProblemType.missing
              ? baseLanguageFile
              : parsedFile.filePath;
          final detailLineNumber =
              problem == LocalizationTranslationProblemType.missing
              ? baseParsedFile.lineNumbersByKey[key] ?? 1
              : parsedFile.lineNumbersByKey[key] ?? 1;
          addDetail(
            localeCode,
            totalCount: translatableBaseKeys.length,
            languageName: _getLanguageName(localeCode),
            problemType: problem,
            filePath: detailFilePath,
            lineNumber: detailLineNumber,
            key: key,
          );
        }
      }
    }

    if (baseLanguageCode != null && unusedBaseKeys.isNotEmpty) {
      for (final key in unusedBaseKeys) {
        addDetail(
          baseLanguageCode,
          totalCount: translatableBaseKeys.length,
          languageName: _getLanguageName(baseLanguageCode),
          problemType: LocalizationTranslationProblemType.unusedKey,
          filePath: baseLanguageFile,
          lineNumber: baseParsedFile.lineNumbersByKey[key] ?? 1,
          key: key,
          countsAsMissing: false,
        );
      }
    }

    for (final data in issueDataByLocale.values) {
      data.details.sort((left, right) {
        final pathCompare = left.filePath.compareTo(right.filePath);
        if (pathCompare != 0) {
          return pathCompare;
        }
        final lineCompare = left.lineNumber.compareTo(right.lineNumber);
        if (lineCompare != 0) {
          return lineCompare;
        }
        final keyCompare = left.key.compareTo(right.key);
        if (keyCompare != 0) {
          return keyCompare;
        }
        return left.problemType.index.compareTo(right.problemType.index);
      });
      if (data.problemCounts.isEmpty) {
        continue;
      }
      issues.add(
        LocalizationIssue(
          languageCode: data.languageCode,
          languageName: data.languageName,
          missingCount: data.missingCount,
          totalCount: data.totalCount,
          problemCounts: data.problemCounts,
          details: data.details,
        ),
      );
    }

    return issues;
  }

  /// Sorts and deduplicates a single ARB file, writing the result back to
  /// disk when changes are needed.
  ///
  /// Keys are sorted alphabetically (case-insensitive). For each translatable
  /// key, its corresponding `@key` metadata entry is placed immediately after
  /// it. File-level `@@...` entries (e.g. `@@locale`) are preserved at the
  /// top. Duplicate keys are collapsed to their first decoded occurrence.
  void _fixArbFile(File arbFile) {
    final String rawContent;
    try {
      rawContent = arbFile.readAsStringSync();
    } catch (_) {
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(rawContent);
    } catch (_) {
      return;
    }
    if (decoded is! Map) {
      return;
    }
    final arbMap = Map<String, dynamic>.from(decoded);

    final headerEntries = <MapEntry<String, dynamic>>[];
    final metaByKey = <String, dynamic>{};
    final translationKeys = <String>[];
    final translationValues = <String, dynamic>{};

    for (final entry in arbMap.entries) {
      if (entry.key.startsWith('@@')) {
        headerEntries.add(entry);
      } else if (entry.key.startsWith('@')) {
        metaByKey[entry.key] = entry.value;
      } else {
        translationKeys.add(entry.key);
        translationValues[entry.key] = entry.value;
      }
    }

    translationKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final sortedMap = <String, dynamic>{};
    for (final entry in headerEntries) {
      sortedMap[entry.key] = entry.value;
    }
    for (final key in translationKeys) {
      sortedMap[key] = translationValues[key];
      final metaKey = '@$key';
      if (metaByKey.containsKey(metaKey)) {
        sortedMap[metaKey] = metaByKey[metaKey];
      }
    }
    // Append orphan @key entries (metadata without a corresponding key).
    for (final entry in metaByKey.entries) {
      if (!translationValues.containsKey(entry.key.substring(1))) {
        sortedMap[entry.key] = entry.value;
      }
    }

    final newContent =
        '${const JsonEncoder.withIndent('  ').convert(sortedMap)}\n';
    if (newContent == rawContent) {
      return;
    }
    arbFile.writeAsStringSync(newContent);
  }

  /// Parses ARB files and delegates to the parsed-file comparison routine.
  List<LocalizationIssue> _analyzeArbFiles(
    Directory projectDir,
    List<File> arbFiles, {
    List<AnalysisFileContext> analyzedContexts = const [],
  }) {
    if (fix) {
      for (final arbFile in arbFiles) {
        _fixArbFile(arbFile);
      }
    }
    final parsedArbFiles = <_ParsedLocalizationArbFile>[];
    for (final arbFile in arbFiles) {
      try {
        final content = arbFile.readAsStringSync();
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          parsedArbFiles.add(
            _ParsedLocalizationArbFile(
              filePath: arbFile.path,
              content: Map<String, dynamic>.from(decoded),
              lineNumbersByKey: extractLocalizationKeyLineNumbers(content),
              duplicateLineNumbersByKey:
                  extractLocalizationDuplicateKeyLineNumbers(content),
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    if (parsedArbFiles.isEmpty) {
      return <LocalizationIssue>[];
    }
    return _analyzeParsedArbFiles(
      projectDir,
      parsedArbFiles,
      analyzedContexts: analyzedContexts,
    );
  }

  /// Finds base-locale keys that appear in app Dart source files.
  _LocalizationKeyUsageScanResult _collectUsedLocalizationKeys({
    required Directory projectDir,
    required Set<String> candidateKeys,
    required List<AnalysisFileContext> analyzedContexts,
  }) {
    if (candidateKeys.isEmpty) {
      return const _LocalizationKeyUsageScanResult(
        hasLocalizationAccess: false,
        usedKeys: <String>{},
      );
    }

    final libDir = Directory(p.join(projectDir.path, 'lib'));
    if (!libDir.existsSync()) {
      return const _LocalizationKeyUsageScanResult(
        hasLocalizationAccess: false,
        usedKeys: <String>{},
      );
    }

    final usedKeys = <String>{};
    var hasLocalizationAccess = false;
    if (analyzedContexts.isNotEmpty) {
      for (final context in analyzedContexts) {
        if (!p.isWithin(libDir.path, context.file.path)) {
          continue;
        }
        if (isGeneratedLocalizationDartFilePath(context.file.path)) {
          continue;
        }
        if (_isLocalizationSupportSourceFile(context.file.path, libDir.path)) {
          continue;
        }
        final content = context.content;
        hasLocalizationAccess =
            _scanLocalizationContent(
              content: content,
              candidateKeys: candidateKeys,
              usedKeys: usedKeys,
            ) ||
            hasLocalizationAccess;
      }
      return _LocalizationKeyUsageScanResult(
        hasLocalizationAccess: hasLocalizationAccess,
        usedKeys: usedKeys,
      );
    }

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (isGeneratedLocalizationDartFilePath(entity.path)) {
        continue;
      }
      if (_isLocalizationSupportSourceFile(entity.path, libDir.path)) {
        continue;
      }
      final content = entity.readAsStringSync();
      hasLocalizationAccess =
          _scanLocalizationContent(
            content: content,
            candidateKeys: candidateKeys,
            usedKeys: usedKeys,
          ) ||
          hasLocalizationAccess;
    }
    return _LocalizationKeyUsageScanResult(
      hasLocalizationAccess: hasLocalizationAccess,
      usedKeys: usedKeys,
    );
  }

  /// Scans one source file content for localization key usage.
  bool _scanLocalizationContent({
    required String content,
    required Set<String> candidateKeys,
    required Set<String> usedKeys,
  }) {
    var hasLocalizationAccess = false;
    hasLocalizationAccess =
        _addUsedKeysFromMatches(
          pattern: _localizationMemberAccessPattern,
          content: content,
          candidateKeys: candidateKeys,
          usedKeys: usedKeys,
        ) ||
        hasLocalizationAccess;
    hasLocalizationAccess =
        _addUsedKeysFromMatches(
          pattern: _currentLocalizationMemberAccessPattern,
          content: content,
          candidateKeys: candidateKeys,
          usedKeys: usedKeys,
        ) ||
        hasLocalizationAccess;
    hasLocalizationAccess =
        _addUsedKeysFromMatches(
          pattern: _contextL10nMemberAccessPattern,
          content: content,
          candidateKeys: candidateKeys,
          usedKeys: usedKeys,
        ) ||
        hasLocalizationAccess;
    final accessorNames = _extractLocalizationAccessorNames(content);
    for (final accessorName in accessorNames) {
      // This pattern matches dynamic localization member access such as
      //   <accessorName>[!|?].memberName(…)
      // It starts at a word boundary, then the escaped accessor name, then an
      // optional Dart null-assertion or null-safe access operator (`!` or `?`)
      // expressed as a non-capturing group `(?:!|\?)?`, followed by a dot,
      // the member identifier, and finally either an opening parenthesis or
      // a word boundary (to cover properties as well as method calls).
      final memberPattern = RegExp(
        '\\b${RegExp.escape(accessorName)}(?:!|\\?)?\\.([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\(|\\b)',
      );
      hasLocalizationAccess =
          _addUsedKeysFromMatches(
            pattern: memberPattern,
            content: content,
            candidateKeys: candidateKeys,
            usedKeys: usedKeys,
          ) ||
          hasLocalizationAccess;
    }
    return hasLocalizationAccess;
  }

  /// Returns true for Dart files that define localization plumbing, not app use.
  bool _isLocalizationSupportSourceFile(String filePath, String libDirPath) {
    final normalizedPath = p.normalize(filePath);
    final relativePath = p.relative(normalizedPath, from: libDirPath);
    final relativeSegments = p.split(relativePath);
    return relativeSegments.isNotEmpty && relativeSegments.first == 'l10n';
  }

  /// Adds localization key usages captured by [pattern] into [usedKeys].
  bool _addUsedKeysFromMatches({
    required RegExp pattern,
    required String content,
    required Set<String> candidateKeys,
    required Set<String> usedKeys,
  }) {
    var foundMatch = false;
    for (final match in pattern.allMatches(content)) {
      foundMatch = true;
      final key = match.group(1);
      if (key != null && candidateKeys.contains(key)) {
        usedKeys.add(key);
      }
    }
    return foundMatch;
  }

  /// Discovers variable names that hold localization accessor instances.
  Set<String> _extractLocalizationAccessorNames(String content) {
    final accessorNames = <String>{..._knownLocalizationAccessorNames};
    for (final match in _typedLocalizationVariablePattern.allMatches(content)) {
      final variableName = match.group(1);
      if (variableName != null) {
        accessorNames.add(variableName);
      }
    }
    for (final match in _assignedLocalizationVariablePattern.allMatches(
      content,
    )) {
      final variableName = match.group(1);
      if (variableName != null) {
        accessorNames.add(variableName);
      }
    }
    return accessorNames;
  }

  /// Collects duplicate-key localization issues from parsed ARB files.
  ///
  /// This scans each parsed ARB file for repeated top-level translation keys
  /// and turns each duplicate occurrence into a localization warning without
  /// affecting translation coverage.
  List<LocalizationIssue> _collectDuplicateIssues({
    required List<_ParsedLocalizationArbFile> parsedArbFiles,
    required int baseTranslationCount,
  }) {
    final issueDataByLocale = <String, _LocalizationIssueData>{};
    void addDuplicateDetail(
      String localeCode, {
      required String languageName,
      required String filePath,
      required int lineNumber,
      required String key,
    }) {
      final data = issueDataByLocale.putIfAbsent(
        localeCode,
        () => _LocalizationIssueData(
          languageCode: localeCode,
          languageName: languageName,
          totalCount: baseTranslationCount,
        ),
      );
      data.problemCounts[LocalizationTranslationProblemType.duplicateKey] =
          (data.problemCounts[LocalizationTranslationProblemType
                  .duplicateKey] ??
              0) +
          1;
      data.details.add(
        LocalizationIssueDetail(
          filePath: filePath,
          lineNumber: lineNumber,
          key: key,
          problemType: LocalizationTranslationProblemType.duplicateKey,
        ),
      );
    }

    for (final parsedFile in parsedArbFiles) {
      final localeCode = _extractLanguageCode(parsedFile.filePath);
      if (localeCode == null) {
        continue;
      }
      if (parsedFile.duplicateLineNumbersByKey.isEmpty) {
        continue;
      }
      for (final entry in parsedFile.duplicateLineNumbersByKey.entries) {
        for (final lineNumber in entry.value) {
          addDuplicateDetail(
            localeCode,
            languageName: _getLanguageName(localeCode),
            filePath: parsedFile.filePath,
            lineNumber: lineNumber,
            key: entry.key,
          );
        }
      }
    }

    final issues = <LocalizationIssue>[];
    for (final data in issueDataByLocale.values) {
      data.details.sort((left, right) {
        final pathCompare = left.filePath.compareTo(right.filePath);
        if (pathCompare != 0) {
          return pathCompare;
        }
        final lineCompare = left.lineNumber.compareTo(right.lineNumber);
        if (lineCompare != 0) {
          return lineCompare;
        }
        return left.key.compareTo(right.key);
      });
      issues.add(
        LocalizationIssue(
          languageCode: data.languageCode,
          languageName: data.languageName,
          missingCount: 0,
          totalCount: data.totalCount,
          problemCounts: data.problemCounts,
          details: data.details,
        ),
      );
    }
    return issues;
  }
}

class _LocalizationIssueData {
  _LocalizationIssueData({
    required this.languageCode,
    required this.languageName,
    required this.totalCount,
  });

  final String languageCode;
  final String languageName;
  final int totalCount;
  int missingCount = 0;
  final Map<LocalizationTranslationProblemType, int> problemCounts = {};
  final List<LocalizationIssueDetail> details = [];
}
