import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/metrics/project_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';

import 'console_common.dart';

const int _maxIssuesToShow = 10;
const int _percentageMultiplier = 100;
const int _commentRatioDecimalPlaces = 0;
const String _noneIndicator = '  (none)';

Iterable<T> _issuesForMode<T>(
  List<T> issues,
  ReportListMode listMode,
) {
  if (listMode == ReportListMode.partial) {
    return issues.take(_maxIssuesToShow);
  }
  return issues;
}

List<String> _uniqueFilePaths(Iterable<String?> paths) {
  final unique = <String>{};
  final result = <String>[];
  for (final path in paths) {
    final value = path ?? 'unknown location';
    if (unique.add(value)) {
      result.add(value);
    }
  }
  return result;
}

/// Builds console report lines for [ProjectMetrics].
List<String> buildReportLines(
  ProjectMetrics metrics, {
  ReportListMode listMode = ReportListMode.partial,
}) {
  final projectName = metrics.projectName;
  final version = metrics.version;
  final projectType = metrics.projectType;
  final totalFolders = metrics.totalFolders;
  final totalFiles = metrics.totalFiles;
  final totalDartFiles = metrics.totalDartFiles;
  final excludedFilesCount = metrics.excludedFilesCount;
  final totalLinesOfCode = metrics.totalLinesOfCode;
  final totalCommentLines = metrics.totalCommentLines;
  final commentRatio = metrics.commentRatio;
  final hardcodedStringIssues = metrics.hardcodedStringIssues;
  final usesLocalization = metrics.usesLocalization;
  final magicNumberIssues = metrics.magicNumberIssues;
  final secretIssues = metrics.secretIssues;
  final deadCodeIssues = metrics.deadCodeIssues;
  final duplicateCodeIssues = [...metrics.duplicateCodeIssues];
  duplicateCodeIssues.sort((left, right) {
    final similarityCompare = right.similarity.compareTo(left.similarity);
    if (similarityCompare != 0) {
      return similarityCompare;
    }

    final lineCountCompare = right.lineCount.compareTo(left.lineCount);
    if (lineCountCompare != 0) {
      return lineCountCompare;
    }

    final firstPathCompare = left.firstFilePath.compareTo(right.firstFilePath);
    if (firstPathCompare != 0) {
      return firstPathCompare;
    }

    final secondPathCompare =
        left.secondFilePath.compareTo(right.secondFilePath);
    if (secondPathCompare != 0) {
      return secondPathCompare;
    }

    final firstLineCompare =
        left.firstLineNumber.compareTo(right.firstLineNumber);
    if (firstLineCompare != 0) {
      return firstLineCompare;
    }

    final secondLineCompare =
        left.secondLineNumber.compareTo(right.secondLineNumber);
    if (secondLineCompare != 0) {
      return secondLineCompare;
    }

    final firstSymbolCompare = left.firstSymbol.compareTo(right.firstSymbol);
    if (firstSymbolCompare != 0) {
      return firstSymbolCompare;
    }

    return left.secondSymbol.compareTo(right.secondSymbol);
  });
  final deadFileIssues = metrics.deadFileIssues;
  final deadClassIssues = metrics.deadClassIssues;
  final deadFunctionIssues = metrics.deadFunctionIssues;
  final unusedVariableIssues = metrics.unusedVariableIssues;
  final oneClassPerFileAnalyzerEnabled = metrics.oneClassPerFileAnalyzerEnabled;
  final hardcodedStringsAnalyzerEnabled =
      metrics.hardcodedStringsAnalyzerEnabled;
  final magicNumbersAnalyzerEnabled = metrics.magicNumbersAnalyzerEnabled;
  final sourceSortingAnalyzerEnabled = metrics.sourceSortingAnalyzerEnabled;
  final secretsAnalyzerEnabled = metrics.secretsAnalyzerEnabled;
  final deadCodeAnalyzerEnabled = metrics.deadCodeAnalyzerEnabled;
  final duplicateCodeAnalyzerEnabled = metrics.duplicateCodeAnalyzerEnabled;
  final layersAnalyzerEnabled = metrics.layersAnalyzerEnabled;
  final layersCount = metrics.layersCount;
  final layersEdgeCount = metrics.layersEdgeCount;
  final fileMetrics = metrics.fileMetrics;
  final sourceSortIssues = metrics.sourceSortIssues;
  final layersIssues = metrics.layersIssues;

  final lines = <String>[];
  void addLine(String line) => lines.add(line);

  final filenamesOnly = listMode == ReportListMode.filenames;

  addLine('Project          : $projectName (version: $version)');
  addLine('Project Type     : ${projectType.label}');
  addLine('Folders          : ${formatCount(totalFolders)}');
  addLine('Files            : ${formatCount(totalFiles)}');
  addLine('Dart Files       : ${formatCount(totalDartFiles)}');
  addLine('Excluded Files   : ${formatCount(excludedFilesCount)}');
  addLine('Lines of Code    : ${formatCount(totalLinesOfCode)}');
  addLine('Comment Lines    : ${formatCount(totalCommentLines)}');
  addLine(
      'Comment Ratio    : ${(commentRatio * _percentageMultiplier).toStringAsFixed(_commentRatioDecimalPlaces)}%');
  final hardcodedSummary = hardcodedStringsAnalyzerEnabled
      ? (usesLocalization
          ? formatCount(hardcodedStringIssues.length)
          : (hardcodedStringIssues.isEmpty
              ? formatCount(hardcodedStringIssues.length)
              : '${formatCount(hardcodedStringIssues.length)} (warning)'))
      : 'disabled';
  addLine('Localization     : ${usesLocalization ? 'Yes' : 'No'}');
  addLine('Hardcoded Strings: $hardcodedSummary');
  addLine(
      'Magic Numbers    : ${magicNumbersAnalyzerEnabled ? formatCount(magicNumberIssues.length) : 'disabled'}');
  addLine(
      'Secrets          : ${secretsAnalyzerEnabled ? formatCount(secretIssues.length) : 'disabled'}');
  addLine(
      'Dead Code        : ${deadCodeAnalyzerEnabled ? formatCount(deadCodeIssues.length) : 'disabled'}');
  addLine(
      'Duplicate Code   : ${duplicateCodeAnalyzerEnabled ? formatCount(duplicateCodeIssues.length) : 'disabled'}');
  addLine(
      'Layers           : ${layersAnalyzerEnabled ? formatCount(layersCount) : 'disabled'}');
  addLine(
      'Dependencies     : ${layersAnalyzerEnabled ? formatCount(layersEdgeCount) : 'disabled'}');

  if (listMode == ReportListMode.none) {
    return lines;
  }

  addLine(dividerLine('Lists', dot: true));

  final nonCompliant =
      fileMetrics.where((m) => !m.isOneClassPerFileCompliant).toList();
  if (!oneClassPerFileAnalyzerEnabled) {
    addLine('${skipTag()} One class per file check skipped (disabled).');
  } else if (nonCompliant.isEmpty) {
    addLine('${okTag()} One class per file check passed.');
  } else {
    addLine(
        '${failTag()} ${formatCount(nonCompliant.length)} files violate the "one class per file" rule:');
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(nonCompliant.map((m) => m.path));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final metric in nonCompliant) {
        addLine(
            '  - ${metric.path} (${formatCount(metric.classCount)} classes found)');
      }
    }
    addLine('');
  }

  if (!hardcodedStringsAnalyzerEnabled) {
    addLine('${skipTag()} Hardcoded strings check skipped (disabled).');
  } else if (hardcodedStringIssues.isEmpty) {
    addLine('${okTag()} Hardcoded strings check passed.');
  } else if (usesLocalization) {
    addLine(
        '${failTag()} ${formatCount(hardcodedStringIssues.length)} hardcoded strings detected (localization enabled):');
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(hardcodedStringIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(hardcodedStringIssues, listMode)) {
        addLine('  - $issue');
      }
      if (listMode == ReportListMode.partial &&
          hardcodedStringIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(hardcodedStringIssues.length - _maxIssuesToShow)} more');
      }
    }
    addLine('');
  } else {
    final firstFile = hardcodedStringIssues.first.filePath.split('/').last;
    addLine(
        '${warnTag()} Hardcoded strings check: ${formatCount(hardcodedStringIssues.length)} found (localization off). Example: $firstFile');
    if (listMode != ReportListMode.partial) {
      if (filenamesOnly) {
        final filePaths =
            _uniqueFilePaths(hardcodedStringIssues.map((i) => i.filePath));
        for (final path in filePaths) {
          addLine('  - $path');
        }
      } else {
        for (final issue in _issuesForMode(hardcodedStringIssues, listMode)) {
          addLine('  - $issue');
        }
      }
      addLine('');
    }
  }

  if (!magicNumbersAnalyzerEnabled) {
    addLine('${skipTag()} Magic numbers check skipped (disabled).');
  } else if (magicNumberIssues.isEmpty) {
    addLine('${okTag()} Magic numbers check passed.');
  } else {
    addLine(
        '${warnTag()} ${formatCount(magicNumberIssues.length)} magic numbers detected:');
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(magicNumberIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(magicNumberIssues, listMode)) {
        addLine('  - $issue');
      }
      addLine('');
      if (listMode == ReportListMode.partial &&
          magicNumberIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(magicNumberIssues.length - _maxIssuesToShow)} more');
      }
    }
    addLine('');
  }

  if (!sourceSortingAnalyzerEnabled) {
    addLine('${skipTag()} Flutter class member sorting skipped (disabled).');
  } else if (sourceSortIssues.isEmpty) {
    addLine('${okTag()} Flutter class member sorting passed.');
  } else {
    addLine(
        '${warnTag()} ${formatCount(sourceSortIssues.length)} Flutter classes have unsorted members:');
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(sourceSortIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(sourceSortIssues, listMode)) {
        addLine(
            '  - ${issue.filePath}:${formatCount(issue.lineNumber)} (${issue.className})');
      }
      if (listMode == ReportListMode.partial &&
          sourceSortIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(sourceSortIssues.length - _maxIssuesToShow)} more');
      }
    }
    addLine('');
  }

  if (!secretsAnalyzerEnabled) {
    addLine('${skipTag()} Secrets scan skipped (disabled).');
  } else if (secretIssues.isEmpty) {
    addLine('${okTag()} Secrets scan passed.');
  } else {
    addLine(
        '${warnTag()} ${formatCount(secretIssues.length)} potential secrets detected:');
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(secretIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(secretIssues, listMode)) {
        addLine('  - $issue');
      }
      if (listMode == ReportListMode.partial &&
          secretIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(secretIssues.length - _maxIssuesToShow)} more');
      }
    }
    addLine('');
  }

  if (!deadCodeAnalyzerEnabled) {
    addLine('${skipTag()} Dead code check skipped (disabled).');
  } else if (deadCodeIssues.isEmpty) {
    addLine('${okTag()} Dead code check passed.');
  } else {
    addLine(
        '${warnTag()} ${formatCount(deadCodeIssues.length)} dead code issues detected:');

    if (deadFileIssues.isNotEmpty) {
      final deadFilePaths = filenamesOnly
          ? _uniqueFilePaths(deadFileIssues.map((i) => i.filePath))
          : const <String>[];
      final deadFileCount =
          filenamesOnly ? deadFilePaths.length : deadFileIssues.length;
      addLine('  Dead files (${formatCount(deadFileCount)}):');
      if (filenamesOnly) {
        for (final path in deadFilePaths) {
          addLine('    - $path');
        }
      } else {
        for (final issue in _issuesForMode(deadFileIssues, listMode)) {
          addLine('    - $issue');
        }
        if (listMode == ReportListMode.partial &&
            deadFileIssues.length > _maxIssuesToShow) {
          addLine(
              '    ... and ${formatCount(deadFileIssues.length - _maxIssuesToShow)} more');
        }
      }
    }

    if (deadClassIssues.isNotEmpty) {
      final deadClassPaths = filenamesOnly
          ? _uniqueFilePaths(deadClassIssues.map((i) => i.filePath))
          : const <String>[];
      final deadClassCount =
          filenamesOnly ? deadClassPaths.length : deadClassIssues.length;
      addLine('  Dead classes (${formatCount(deadClassCount)}):');
      if (filenamesOnly) {
        for (final path in deadClassPaths) {
          addLine('    - $path');
        }
      } else {
        for (final issue in _issuesForMode(deadClassIssues, listMode)) {
          addLine('    - $issue');
        }
        if (listMode == ReportListMode.partial &&
            deadClassIssues.length > _maxIssuesToShow) {
          addLine(
              '    ... and ${formatCount(deadClassIssues.length - _maxIssuesToShow)} more');
        }
      }
    }

    if (deadFunctionIssues.isNotEmpty) {
      final deadFunctionPaths = filenamesOnly
          ? _uniqueFilePaths(deadFunctionIssues.map((i) => i.filePath))
          : const <String>[];
      final deadFunctionCount =
          filenamesOnly ? deadFunctionPaths.length : deadFunctionIssues.length;
      addLine('  Dead functions (${formatCount(deadFunctionCount)}):');
      if (filenamesOnly) {
        for (final path in deadFunctionPaths) {
          addLine('    - $path');
        }
      } else {
        for (final issue in _issuesForMode(deadFunctionIssues, listMode)) {
          addLine('    - $issue');
        }
        if (listMode == ReportListMode.partial &&
            deadFunctionIssues.length > _maxIssuesToShow) {
          addLine(
              '    ... and ${formatCount(deadFunctionIssues.length - _maxIssuesToShow)} more');
        }
      }
    }

    if (unusedVariableIssues.isNotEmpty) {
      final unusedVariablePaths = filenamesOnly
          ? _uniqueFilePaths(unusedVariableIssues.map((i) => i.filePath))
          : const <String>[];
      final unusedVariableCount = filenamesOnly
          ? unusedVariablePaths.length
          : unusedVariableIssues.length;
      addLine('  Unused variables (${formatCount(unusedVariableCount)}):');
      if (filenamesOnly) {
        for (final path in unusedVariablePaths) {
          addLine('    - $path');
        }
      } else {
        for (final issue in _issuesForMode(unusedVariableIssues, listMode)) {
          addLine('    - $issue');
        }
        if (listMode == ReportListMode.partial &&
            unusedVariableIssues.length > _maxIssuesToShow) {
          addLine(
              '    ... and ${formatCount(unusedVariableIssues.length - _maxIssuesToShow)} more');
        }
      }
    }

    addLine('');
  }

  if (!duplicateCodeAnalyzerEnabled) {
    addLine('${skipTag()} Duplicate code check skipped (disabled).');
  } else if (duplicateCodeIssues.isEmpty) {
    addLine('${okTag()} Duplicate code check passed.');
  } else {
    addLine(
        '${warnTag()} ${formatCount(duplicateCodeIssues.length)} duplicate code blocks detected:');
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(
        duplicateCodeIssues.expand((issue) => [
              issue.firstFilePath,
              issue.secondFilePath,
            ]),
      );
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(duplicateCodeIssues, listMode)) {
        addLine('  - $issue');
      }
      if (listMode == ReportListMode.partial &&
          duplicateCodeIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(duplicateCodeIssues.length - _maxIssuesToShow)} more');
      }
    }
    addLine('');
  }

  if (!layersAnalyzerEnabled) {
    addLine('${skipTag()} Layers architecture check skipped (disabled).');
  } else if (layersIssues.isEmpty) {
    addLine('${okTag()} Layers architecture check passed.');
  } else {
    addLine(
        '${failTag()} ${formatCount(layersIssues.length)} layers architecture violations detected:');
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(layersIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        addLine('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(layersIssues, listMode)) {
        addLine('  - $issue');
      }
      if (listMode == ReportListMode.partial &&
          layersIssues.length > _maxIssuesToShow) {
        addLine(
            '  ... and ${formatCount(layersIssues.length - _maxIssuesToShow)} more');
      }
    }
  }

  return lines;
}

/// Prints a help screen with usage, description, and parser usage details.
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

/// Prints the current CLI tool version.
void printVersionLine(String version) {
  print(version);
}

/// Prints a missing-directory error message.
void printMissingDirectoryError(String path) {
  print('Error: Directory "$path" does not exist.');
}

/// Prints a configuration error message for invalid `.fcheck` files.
void printConfigurationError(String message) {
  print('Error: Invalid .fcheck configuration. $message');
}

/// Prints the run header before analysis starts.
void printRunHeader({
  required String version,
  required Directory directory,
}) {
  print(dividerLine('fCheck $version', downPointer: true));
  print('Input            : ${directory.absolute.path}');
}

/// Prints structured JSON with two-space indentation.
void printJsonOutput(Object? data) {
  print(const JsonEncoder.withIndent('  ').convert(data));
}

/// Prints excluded files and directories in CLI text format.
void printExcludedItems({
  required List<File> excludedDartFiles,
  required List<File> excludedNonDartFiles,
  required List<Directory> excludedDirectories,
}) {
  print('Excluded Dart files (${formatCount(excludedDartFiles.length)}):');
  if (excludedDartFiles.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final file in excludedDartFiles) {
      print('  ${file.path}');
    }
  }

  print(
      '\nExcluded non-Dart files (${formatCount(excludedNonDartFiles.length)}):');
  if (excludedNonDartFiles.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final file in excludedNonDartFiles) {
      print('  ${file.path}');
    }
  }

  print('\nExcluded directories (${formatCount(excludedDirectories.length)}):');
  if (excludedDirectories.isEmpty) {
    print(_noneIndicator);
  } else {
    for (final dir in excludedDirectories) {
      print('  ${dir.path}');
    }
  }
}

/// Prints each report line in order.
void printReportLines(Iterable<String> lines) {
  for (final line in lines) {
    print(line);
  }
}

/// Prints a divider for generated output files.
void printOutputFilesHeader() {
  print(dividerLine('Output files', dot: true));
}

/// Prints one generated output file line using a label and path.
void printOutputFileLine({
  required String label,
  required String path,
}) {
  print('$label: $path');
}

/// Prints run completion footer with elapsed seconds.
void printRunCompleted(String elapsedSeconds) {
  print(
      dividerLine('fCheck completed (${elapsedSeconds}s)', downPointer: false));
}

/// Prints fatal analysis error and stack trace details.
void printAnalysisError(Object error, StackTrace stack) {
  print('Error during analysis: $error');
  print(stack);
}

/// Length of the header and footer lines
final int dividerLength = 40;
const int _halfTitleLengthDivisor = 2;

bool get _supportsAnsiEscapes => stdout.supportsAnsiEscapes;

const int _ansiGreen = 32;
const int _ansiYellow = 33;
const int _ansiRed = 31;
const int _ansiGray = 90;

String _colorize(String text, int colorCode) =>
    _supportsAnsiEscapes ? '\x1B[${colorCode}m$text\x1B[0m' : text;

/// Status markers styled like `flutter doctor`.
///
/// These are intentionally short and suitable for console output.
String okTag() => _colorize('[✓]', _ansiGreen);

/// Warning marker styled like `flutter doctor`.
///
/// This remains readable even without ANSI color support.
String warnTag() => _colorize('[!]', _ansiYellow);

/// Failure marker styled like `flutter doctor`.
///
/// The label uses a single-width glyph for alignment.
String failTag() => _colorize('[✗]', _ansiRed);

/// Informational marker for skipped checks.
String skipTag() => _colorize('[-]', _ansiGray);

/// Builds a formatted divider line for console headers/footers.
String dividerLine(String title, {bool downPointer = true, bool dot = false}) {
  title = ' $title ';
  final directionChar = downPointer ? '↓' : '↑';
  final sideLines = (dot ? '·' : '-') *
      (dividerLength - (title.length ~/ _halfTitleLengthDivisor));

  return '$directionChar$sideLines$title$sideLines$directionChar';
}
