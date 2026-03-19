import 'dart:io';

import 'package:fcheck/src/analyzers/localization/localization_delegate.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue.dart';
import 'package:fcheck/src/analyzers/localization/localization_issue_detail.dart';
import 'package:fcheck/src/analyzers/localization/localization_report_scanner.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';
import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/models/app_strings.dart';

import 'console_common.dart';

const int _percentageMultiplier = 100;
const int _ansiGreenBright = 92;
const int _ansiYellow = 33;
const int _ansiYellowBright = 93;
const int _ansiWhiteBright = 97;

String _colorize(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[${colorCode}m$text\x1B[0m' : text;

String _colorizeBold(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[1;${colorCode}m$text\x1B[0m' : text;

/// Returns the bright-green success tag used by console report blocks.
String okTag() => _colorize('[✓]', _ansiGreenBright);

/// Returns the bright-yellow warning tag used by console report blocks.
String warnTag() => _colorize('[!]', _ansiYellowBright);

Iterable<T> _issuesForMode<T>(
  List<T> issues,
  ReportListMode listMode,
  int listItemLimit,
) {
  if (listMode == ReportListMode.partial) {
    return issues.take(listItemLimit);
  }
  return issues;
}

String _pathText(String path) => colorizePathFilename(path);

/// Returns unique file paths in first-seen order for localization details.
List<String> _uniqueFilePaths(Iterable<String?> paths) {
  final unique = <String>{};
  final result = <String>[];
  for (final path in paths) {
    final value = path ?? AppStrings.unknownLocation;
    if (unique.add(value)) {
      result.add(value);
    }
  }
  return result;
}

/// Builds the localization analyzer warning block.
List<String> buildLocalizationWarningLines({
  required String analysisRootPath,
  required List<LocalizationIssue> localizationIssues,
  required ReportListMode listMode,
  required int effectiveListItemLimit,
  required bool filenamesOnly,
}) {
  final scanResult = scanLocalizationLocales(analysisRootPath);
  final effectiveIssues = localizationIssues.isNotEmpty
      ? List<LocalizationIssue>.from(localizationIssues)
      : (analysisRootPath.trim().isEmpty
            ? buildLocalizationIssuesFromScanResult(scanResult)
            : LocalizationDelegate().analyzeProject(
                Directory(analysisRootPath),
              ));
  final lines = <String>[
    '${warnTag()} ${formatCount(effectiveIssues.length)} localization issues detected',
  ];
  final allLocaleStats = scanResult.localeStats;
  final totalBaseKeys = scanResult.baseTranslationCount;
  final totalLanguages = allLocaleStats.length;

  lines.add('');
  lines.add('  ${okTag()} Localization Summary:');
  lines.add(
    '    - Base language: ${scanResult.baseLocaleCode == null ? "Not detected" : "${localizationLanguageNameForCode(scanResult.baseLocaleCode!)} (${scanResult.baseLocaleCode})"}',
  );
  if (totalBaseKeys > 0) {
    lines.add('    - Total translation keys: $totalBaseKeys');
    lines.add('    - Supported languages: $totalLanguages');
    lines.add('    - Problem locales: ${effectiveIssues.length}');
  }

  if (totalBaseKeys == 0) {
    return lines;
  }

  lines.add('');
  lines.add('  ${warnTag()} Localization Problems:');
  final sortedIssues = List<LocalizationIssue>.from(effectiveIssues)
    ..sort((left, right) {
      final leftCode = left.languageCode.toLowerCase();
      final rightCode = right.languageCode.toLowerCase();
      return leftCode.compareTo(rightCode);
    });
  final localeLabelWidth = _maxLocalizationLocaleLabelWidth(sortedIssues);
  for (final issue in sortedIssues) {
    lines.add(_formatLocalizationIssueSummary(issue, localeLabelWidth));
    if (issue.details.isEmpty || listMode == ReportListMode.none) {
      continue;
    }
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(
        issue.details.map((detail) => detail.filePath),
      );
      for (final path in filePaths) {
        lines.add('      - ${_pathText(path)}');
      }
      continue;
    }
    final visibleDetails = _issuesForMode(
      issue.details,
      listMode,
      effectiveListItemLimit,
    ).toList();
    for (final detail in visibleDetails) {
      lines.add(_formatLocalizationIssueDetail(issue, detail));
    }
    if (listMode == ReportListMode.partial &&
        issue.details.length > effectiveListItemLimit) {
      lines.add(
        '      ... and ${formatCount(issue.details.length - effectiveListItemLimit)} more',
      );
    }
  }
  return lines;
}

/// Builds detailed localization issues from the scan summary fallback.
///
/// This is used only when the in-memory analyzer list is empty but the ARB
/// scan still shows localization coverage gaps.
List<LocalizationIssue> buildLocalizationIssuesFromScanResult(
  LocalizationReportScanResult scanResult,
) {
  final baseLocaleCode = scanResult.baseLocaleCode;
  final baseTranslationCount = scanResult.baseTranslationCount;
  if (baseLocaleCode == null || baseTranslationCount == 0) {
    return const <LocalizationIssue>[];
  }

  final issues = <LocalizationIssue>[];
  for (final entry in scanResult.localeStats.entries) {
    if (entry.key == baseLocaleCode) {
      continue;
    }
    final stat = entry.value;
    final missingCount = baseTranslationCount - stat.translationCount;
    if (missingCount <= 0) {
      continue;
    }
    issues.add(
      LocalizationIssue(
        languageCode: stat.languageCode,
        languageName: stat.languageName,
        missingCount: missingCount,
        totalCount: baseTranslationCount,
        problemCounts: {
          LocalizationTranslationProblemType.missing: missingCount,
        },
      ),
    );
  }
  return issues;
}

/// Returns the widest locale label in the provided localization issues.
int _maxLocalizationLocaleLabelWidth(Iterable<LocalizationIssue> issues) {
  var maxWidth = 0;
  for (final issue in issues) {
    final width = '${issue.languageName} (${issue.languageCode})'.length;
    if (width > maxWidth) {
      maxWidth = width;
    }
  }
  return maxWidth;
}

/// Formats a localization issue summary using the shared dash bullet style.
String _formatLocalizationIssueSummary(
  LocalizationIssue issue,
  int localeLabelWidth,
) {
  final localeLabel = _formatLocalizationLocaleLabel(
    issue,
    localeLabelWidth: localeLabelWidth,
  );
  final coveragePercent = issue.coveragePercentage.floor();
  final coverageText = coveragePercent >= _percentageMultiplier
      ? _colorizeBold('${formatCount(coveragePercent)}%', _ansiGreenBright)
      : _colorize('${formatCount(coveragePercent)}%', _ansiYellow);
  return '    - $localeLabel: $coverageText coverage (${issue.problemSummaryText()})';
}

/// Formats the locale label with colored text tokens and plain parentheses.
String _formatLocalizationLocaleLabel(
  LocalizationIssue issue, {
  required int localeLabelWidth,
}) {
  final plainLabel = '${issue.languageName} (${issue.languageCode})';
  final paddingWidth = localeLabelWidth - plainLabel.length;
  final padding = paddingWidth > 0 ? ' ' * paddingWidth : '';
  return '${_colorizeBold(issue.languageName, _ansiWhiteBright)} (${_colorizeBold(issue.languageCode, _ansiWhiteBright)})$padding';
}

/// Formats a single localization issue detail line with file and line data.
String _formatLocalizationIssueDetail(
  LocalizationIssue issue,
  LocalizationIssueDetail detail,
) {
  final location = resolveIssueLocationWithLine(
    rawPath: detail.filePath,
    lineNumber: detail.lineNumber,
  );
  final problemLabel = localizationProblemLabel(detail.problemType);
  final keyText = colorizeIssueArtifact(detail.key);
  if (detail.problemType == LocalizationTranslationProblemType.missing) {
    return '      - $location: missing $keyText in ${issue.languageCode}';
  }
  if (detail.problemType == LocalizationTranslationProblemType.unusedKey) {
    return '      - $location: unused key $keyText in app source';
  }
  return '      - $location: $problemLabel $keyText';
}
