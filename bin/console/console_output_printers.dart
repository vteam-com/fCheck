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

/// Prints fatal analysis error and stack trace details.
///
/// This keeps CLI failures transparent for local debugging and CI logs.
