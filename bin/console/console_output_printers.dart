part of 'console_output.dart';

/// Prints the main CLI help screen.
///
/// [usageLine], [descriptionLine], and [parserUsage] are composed by
/// `console_common.dart` and the argument parser.
void printHelpScreen({
  required String usageLine,
  required String descriptionLine,
  required String parserUsage,
}) {
  print(usageLine);
  print('');
  print(descriptionLine);
  print('');
  print(parserUsage);
}

/// Prints invalid-argument diagnostics and usage details.
///
/// Used when argument parsing fails before runtime execution starts.
void printInvalidArgumentsScreen({
  required String invalidArgumentsLine,
  required String usageLine,
  required String parserUsage,
}) {
  print(invalidArgumentsLine);
  print(usageLine);
  print('');
  print(parserUsage);
}

/// Prints the current CLI tool version string.
void printVersionLine(String version) {
  print(version);
}

/// Prints an error when a requested input directory does not exist.
void printMissingDirectoryError(String path) {
  print(AppStrings.missingDirectoryError(path));
}

/// Prints a configuration error for invalid `.fcheck` content.
void printConfigurationError(String message) {
  print(AppStrings.invalidFcheckConfigurationError(message));
}

/// Prints the run header before analysis starts.
///
/// Includes tool version and normalized input directory path.
void printRunHeader({required String version, required Directory directory}) {
  print(dividerLine('fCheck $version', downPointer: true));
  print(
    _labelValueLine(label: AppStrings.input, value: directory.absolute.path),
  );
}

/// Prints structured JSON with two-space indentation.
///
/// This is used for machine-readable output (`--json`) only.
void printJsonOutput(Object? data) {
  print(const JsonEncoder.withIndent('  ').convert(data));
}

/// Prints excluded files and directories in CLI text format.
///
/// Groups output by Dart files, non-Dart files, and directories.
void printExcludedItems({
  required List<File> excludedDartFiles,
  required List<File> excludedNonDartFiles,
  required List<Directory> excludedDirectories,
}) {
  print(
    AppStrings.excludedDartFilesHeader(formatCount(excludedDartFiles.length)),
  );
  if (excludedDartFiles.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final file in excludedDartFiles) {
      print('  ${_pathText(file.path)}');
    }
  }

  print(
    AppStrings.excludedNonDartFilesHeader(
      formatCount(excludedNonDartFiles.length),
    ),
  );
  if (excludedNonDartFiles.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final file in excludedNonDartFiles) {
      print('  ${_pathText(file.path)}');
    }
  }

  print(
    AppStrings.excludedDirectoriesHeader(
      formatCount(excludedDirectories.length),
    ),
  );
  if (excludedDirectories.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final dir in excludedDirectories) {
      print('  ${_pathText(dir.path)}');
    }
  }
}

/// Prints literals inventory in CLI text format.
void printLiteralsSummary({
  required int totalStringLiteralCount,
  required int duplicatedStringLiteralCount,
  required int hardcodedStringCount,
  required int totalNumberLiteralCount,
  required int duplicatedNumberLiteralCount,
  required int hardcodedNumberCount,
  required Map<String, int> stringLiteralFrequencies,
  required Map<String, int> numberLiteralFrequencies,
  required List<Map<String, Object?>> hardcodedStringEntries,
  required ReportListMode listMode,
  required int listItemLimit,
}) {
  final stringCountText = formatCount(totalStringLiteralCount);
  final numberCountText = formatCount(totalNumberLiteralCount);
  final countWidth = stringCountText.length >= numberCountText.length
      ? stringCountText.length
      : numberCountText.length;

  print(dividerLine(AppStrings.literalsDivider));
  print(
    _labelValueLine(
      label: AppStrings.strings,
      value: _literalInventorySummary(
        totalCount: totalStringLiteralCount,
        duplicatedCount: duplicatedStringLiteralCount,
        hardcodedCount: hardcodedStringCount,
        countWidth: countWidth,
      ),
    ),
  );
  print(
    _labelValueLine(
      label: AppStrings.numbers,
      value: _literalInventorySummary(
        totalCount: totalNumberLiteralCount,
        duplicatedCount: duplicatedNumberLiteralCount,
        hardcodedCount: hardcodedNumberCount,
        countWidth: countWidth,
      ),
    ),
  );

  if (listMode == ReportListMode.none) {
    return;
  }

  final stringEntries = _sortedLiteralEntries(
    stringLiteralFrequencies,
    numericAware: false,
  );
  final numberEntries = _sortedLiteralEntries(
    numberLiteralFrequencies,
    numericAware: true,
  );
  final visibleStringEntries = _literalEntriesForMode(
    entries: stringEntries,
    listMode: listMode,
    listItemLimit: listItemLimit,
  );
  final visibleNumberEntries = _literalEntriesForMode(
    entries: numberEntries,
    listMode: listMode,
    listItemLimit: listItemLimit,
  );

  final sortedHardcodedEntries = [...hardcodedStringEntries]
    ..sort((a, b) {
      final pathA = (a['filePath'] as String?) ?? '';
      final pathB = (b['filePath'] as String?) ?? '';
      final pathCompare = pathA.compareTo(pathB);
      if (pathCompare != 0) {
        return pathCompare;
      }
      final lineA = (a['lineNumber'] as int?) ?? 0;
      final lineB = (b['lineNumber'] as int?) ?? 0;
      final lineCompare = lineA.compareTo(lineB);
      if (lineCompare != 0) {
        return lineCompare;
      }
      final valueA = (a['value'] as String?) ?? '';
      final valueB = (b['value'] as String?) ?? '';
      return valueA.compareTo(valueB);
    });
  final visibleHardcodedEntries = _hardcodedEntriesForMode(
    entries: sortedHardcodedEntries,
    listMode: listMode,
    listItemLimit: listItemLimit,
  );

  print('');
  print(
    AppStrings.foundItemsHeader(
      label: AppStrings.hardcodedStrings,
      count: formatCount(sortedHardcodedEntries.length),
    ),
  );
  if (visibleHardcodedEntries.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final entry in visibleHardcodedEntries) {
      final filePath = (entry['filePath'] as String?) ?? '';
      final lineNumber = (entry['lineNumber'] as int?) ?? 0;
      final value = (entry['value'] as String?) ?? '';
      final location = resolveIssueLocationWithLine(
        rawPath: filePath,
        lineNumber: lineNumber,
      );
      print('  - ${_pathText(location)}: ${jsonEncode(value)}');
    }
    if (listMode == ReportListMode.partial &&
        sortedHardcodedEntries.length > visibleHardcodedEntries.length) {
      print(
        '  ... ${AppStrings.and} ${formatCount(sortedHardcodedEntries.length - visibleHardcodedEntries.length)} ${AppStrings.more}',
      );
    }
  }

  print('');
  print(
    AppStrings.uniqueFoundItemsHeader(
      label: AppStrings.strings.toLowerCase(),
      count: formatCount(stringEntries.length),
    ),
  );
  if (visibleStringEntries.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final entry in visibleStringEntries) {
      print('  - ${jsonEncode(entry.key)} (${formatCount(entry.value)})');
    }
    if (listMode == ReportListMode.partial &&
        stringEntries.length > visibleStringEntries.length) {
      print(
        '  ... ${AppStrings.and} ${formatCount(stringEntries.length - visibleStringEntries.length)} ${AppStrings.more}',
      );
    }
  }

  print('');
  print(
    AppStrings.uniqueFoundItemsHeader(
      label: AppStrings.numbers.toLowerCase(),
      count: formatCount(numberEntries.length),
    ),
  );
  if (visibleNumberEntries.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final entry in visibleNumberEntries) {
      print('  - ${entry.key} (${formatCount(entry.value)})');
    }
    if (listMode == ReportListMode.partial &&
        numberEntries.length > visibleNumberEntries.length) {
      print(
        '  ... ${AppStrings.and} ${formatCount(numberEntries.length - visibleNumberEntries.length)} ${AppStrings.more}',
      );
    }
  }
}

List<Map<String, Object?>> _hardcodedEntriesForMode({
  required List<Map<String, Object?>> entries,
  required ReportListMode listMode,
  required int listItemLimit,
}) {
  if (listMode == ReportListMode.full) {
    return entries;
  }
  final safeLimit = listItemLimit > 0 ? listItemLimit : 1;
  return entries.take(safeLimit).toList(growable: false);
}

/// Returns literal frequency entries sorted by count, then by literal value.
///
/// When [numericAware] is true, numeric ties are ordered by parsed numeric
/// value before falling back to lexicographic comparison.
List<MapEntry<String, int>> _sortedLiteralEntries(
  Map<String, int> frequencies, {
  required bool numericAware,
}) {
  final entries = frequencies.entries.toList();
  entries.sort((left, right) {
    final countCompare = right.value.compareTo(left.value);
    if (countCompare != 0) {
      return countCompare;
    }
    if (numericAware) {
      final leftNumeric = parseNumericLexeme(left.key);
      final rightNumeric = parseNumericLexeme(right.key);
      if (leftNumeric != null && rightNumeric != null) {
        final numericCompare = leftNumeric.compareTo(rightNumeric);
        if (numericCompare != 0) {
          return numericCompare;
        }
      } else if (leftNumeric != null) {
        return -1;
      } else if (rightNumeric != null) {
        return 1;
      }
    }
    return left.key.compareTo(right.key);
  });
  return entries;
}

List<MapEntry<String, int>> _literalEntriesForMode({
  required List<MapEntry<String, int>> entries,
  required ReportListMode listMode,
  required int listItemLimit,
}) {
  if (listMode == ReportListMode.full) {
    return entries;
  }
  final safeLimit = listItemLimit > 0 ? listItemLimit : 1;
  return entries.take(safeLimit).toList(growable: false);
}

/// Prints each prebuilt report line in order.
void printReportLines(Iterable<String> lines) {
  for (final line in lines) {
    print(line);
  }
}

/// Prints a divider for generated output files.
void printOutputFilesHeader() {
  print(dividerLine('Output files'));
}

/// Prints one generated output file line using a label and path.
void printOutputFileLine({required String label, required String path}) {
  final normalizedPath = normalizeIssueLocation(path).path;
  print(
    _labelValueLine(label: label.trimRight(), value: _pathText(normalizedPath)),
  );
}

/// Prints run completion footer with elapsed time in seconds.
void printRunCompleted(String elapsedSeconds) {
  print(
    dividerLine(
      'fCheck completed (${elapsedSeconds}s)',
      dot: false,
      downPointer: false,
    ),
  );
}
