import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/metrics/project_metrics.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:fcheck/src/models/project_type.dart';

import 'console_common.dart';

const int _maxIssuesToShow = 10;
const int _percentageMultiplier = 100;
const int _gridLabelWidth = 18;
const int _gridValueWidth = 18;
const int _domainValueWidth = 18;
const int _perfectScoreThreshold = 95;
const int _goodScoreThreshold = 85;
const int _fairScoreThreshold = 70;
const int _minHealthyCommentRatioPercent = 10;
const int _minorIssueCountUpperBound = 3;
const int _compactDecimalPlaces = 2;
const int _hardcodedValueWidth = 3;
const int _minorSuppressionPenaltyUpperBound = 3;
const int _moderateSuppressionPenaltyUpperBound = 7;
const int _unknownListBlockOrder = 99;
const String _noneIndicator = '  (none)';

/// Returns all issues or a top slice depending on [listMode].
///
/// Partial mode limits output to a stable preview size for readability.
Iterable<T> _issuesForMode<T>(
  List<T> issues,
  ReportListMode listMode,
) {
  if (listMode == ReportListMode.partial) {
    return issues.take(_maxIssuesToShow);
  }
  return issues;
}

/// Deduplicates and normalizes file paths for filenames-only sections.
///
/// Null entries are represented as `unknown location` to keep output explicit.
List<String> _uniqueFilePaths(Iterable<String?> paths) {
  final unique = <String>{};
  final result = <String>[];
  for (final path in paths) {
    final value =
        path == null ? 'unknown location' : normalizeIssueLocation(path).path;
    if (unique.add(value)) {
      result.add(value);
    }
  }
  return result;
}

/// Computes the widest decimal width among [values].
///
/// Used to align numeric columns in list output blocks.
int _maxIntWidth(Iterable<int> values) {
  var maxWidth = 0;
  for (final value in values) {
    final width = value.toString().length;
    if (width > maxWidth) {
      maxWidth = width;
    }
  }
  return maxWidth;
}

String _separatorColon() => _colorize(':', _ansiGray);
String _separatorPipe() => _colorize('|', _ansiGray);

String _labelValueLine({
  required String label,
  required String value,
  int labelWidth = _gridLabelWidth,
}) =>
    '${label.padRight(labelWidth)} ${_separatorColon()} $value';

String _gridRow(List<String> cells) => cells.join('  ${_separatorPipe()}  ');

/// Builds one dashboard cell with consistent label/value alignment.
String _gridCell({
  required String label,
  required String value,
  int valueWidth = _gridValueWidth,
  bool alignRight = true,
  bool valuePreAligned = false,
}) {
  final alignedValue = valuePreAligned
      ? value
      : (alignRight ? value.padLeft(valueWidth) : value.padRight(valueWidth));
  return _labelValueLine(
    label: label,
    value: alignedValue,
    labelWidth: _gridLabelWidth,
  );
}

/// Colors the compliance score text according to threshold bands.
String _scoreValue(int score) {
  final text = '${formatCount(score)}%';
  if (score >= _perfectScoreThreshold) {
    return _colorizeBold(text, _ansiGreenBright);
  }
  if (score >= _goodScoreThreshold) {
    return _colorizeBold(text, _ansiYellowBright);
  }
  if (score >= _fairScoreThreshold) {
    return _colorizeBold(text, _ansiOrange);
  }
  return _colorizeBold(text, _ansiRedBright);
}

/// Formats a domain dashboard value including disabled/issue severity states.
String _domainValue({
  required bool enabled,
  required int issueCount,
  bool anyIssueIsBad = false,
  int width = _domainValueWidth,
}) {
  if (!enabled) {
    if (width <= 0) {
      return 'disabled';
    }
    return 'disabled'.padLeft(width);
  }

  if (issueCount == 0) {
    final rawText = '✓';
    final text = width <= 0 ? rawText : rawText.padLeft(width);
    return _colorize(text, _ansiGreen);
  }

  final rawText = formatCount(issueCount);
  final text = width <= 0 ? rawText : rawText.padLeft(width);

  if (anyIssueIsBad) {
    return _colorize(text, _ansiRed);
  }

  if (issueCount == 1) {
    return _colorize(text, _ansiYellowBright);
  }

  if (issueCount <= _minorIssueCountUpperBound) {
    return _colorize(text, _ansiOrange);
  }

  return _colorize(text, _ansiRed);
}

/// Formats comments as raw count and percent of LOC.
String _commentSummary({
  required int totalCommentLines,
  required double commentRatio,
  int width = 0,
}) {
  final ratioPercent = (commentRatio * _percentageMultiplier).round();
  final summary =
      '${formatCount(totalCommentLines)} (${formatCount(ratioPercent)}%)';
  final text = width <= 0 ? summary : summary.padLeft(width);
  if (ratioPercent < _minHealthyCommentRatioPercent) {
    return _colorize(text, _ansiRed);
  }
  return text;
}

/// Formats suppression penalty points with sign, alignment, and severity color.
///
/// Zero penalty is green; larger penalties are highlighted to make score
/// deductions obvious in the scorecard.
String _suppressionPenaltyValue({
  required int penaltyPoints,
  int width = 0,
}) {
  final rawText =
      penaltyPoints == 0 ? '0 pts' : '-${formatCount(penaltyPoints)} pts';
  final text = width <= 0 ? rawText : rawText.padLeft(width);

  if (penaltyPoints == 0) {
    return _colorize(text, _ansiGreen);
  }
  if (penaltyPoints <= _minorSuppressionPenaltyUpperBound) {
    return _colorize(text, _ansiYellowBright);
  }
  if (penaltyPoints <= _moderateSuppressionPenaltyUpperBound) {
    return _colorize(text, _ansiOrange);
  }
  return _colorize(text, _ansiRed);
}

/// Formats suppression-related counts with optional width alignment.
///
/// A zero count is shown as green to indicate healthy suppression hygiene.
String _suppressionCountValue({
  required int count,
  int width = 0,
}) {
  final rawText = formatCount(count);
  final text = width <= 0 ? rawText : rawText.padLeft(width);
  if (count == 0) {
    return _colorize(text, _ansiGreen);
  }
  return _colorize(text, _ansiOrange);
}

/// Formats a decimal value for compact CLI display.
///
/// Keeps up to two fractional digits and removes trailing zeros and separators.
String _formatCompactDecimal(double value) {
  var text = value.toStringAsFixed(_compactDecimalPlaces);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// Builds console report lines for [ProjectMetrics].
///
/// The output is grouped into:
/// - Scorecard (overall compliance + next investment)
/// - Dashboard (compact project and analyzer snapshot)
/// - Lists (detailed issues), unless [listMode] is `none`
///
/// [listMode] controls detail level for issue sections and can render
/// filenames-only output for easier triage.
List<String> buildReportLines(
  ProjectMetrics metrics, {
  ReportListMode listMode = ReportListMode.partial,
}) {
  final projectName = metrics.projectName;
  final version = metrics.version;
  final totalFolders = metrics.totalFolders;
  final totalFiles = metrics.totalFiles;
  final totalDartFiles = metrics.totalDartFiles;
  final excludedFilesCount = metrics.excludedFilesCount;
  final customExcludedFilesCount = metrics.customExcludedFilesCount;
  final ignoreDirectivesCount = metrics.ignoreDirectivesCount;
  final ignoreDirectiveCountsByFile =
      metrics.ignoreDirectiveCountsByFile.isEmpty
          ? <String, int>{
              for (final path in _uniqueFilePaths(metrics.ignoreDirectiveFiles))
                path: 1,
            }
          : Map<String, int>.from(metrics.ignoreDirectiveCountsByFile);
  final ignoreDirectiveEntries = ignoreDirectiveCountsByFile.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final ignoreDirectiveFileCount = ignoreDirectiveEntries.length;
  final disabledAnalyzersCount = metrics.disabledAnalyzersCount;
  final totalLinesOfCode = metrics.totalLinesOfCode;
  final totalCommentLines = metrics.totalCommentLines;
  final commentRatio = metrics.commentRatio;
  final hardcodedStringIssues = metrics.hardcodedStringIssues;
  final usesLocalization = metrics.usesLocalization;
  final magicNumberIssues = metrics.magicNumberIssues;
  final secretIssues = metrics.secretIssues;
  final deadCodeIssues = metrics.deadCodeIssues;
  final documentationIssues = metrics.documentationIssues;
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
  final documentationAnalyzerEnabled = metrics.documentationAnalyzerEnabled;
  final layersAnalyzerEnabled = metrics.layersAnalyzerEnabled;
  final layersEdgeCount = metrics.layersEdgeCount;
  final fileMetrics = metrics.fileMetrics;
  final sourceSortIssues = metrics.sourceSortIssues;
  final layersIssues = metrics.layersIssues;
  final disabledAnalyzerKeys = <String>[
    if (!oneClassPerFileAnalyzerEnabled)
      AnalyzerDomain.oneClassPerFile.configName,
    if (!hardcodedStringsAnalyzerEnabled)
      AnalyzerDomain.hardcodedStrings.configName,
    if (!magicNumbersAnalyzerEnabled) AnalyzerDomain.magicNumbers.configName,
    if (!sourceSortingAnalyzerEnabled) AnalyzerDomain.sourceSorting.configName,
    if (!layersAnalyzerEnabled) AnalyzerDomain.layers.configName,
    if (!secretsAnalyzerEnabled) AnalyzerDomain.secrets.configName,
    if (!deadCodeAnalyzerEnabled) AnalyzerDomain.deadCode.configName,
    if (!duplicateCodeAnalyzerEnabled) AnalyzerDomain.duplicateCode.configName,
    if (!documentationAnalyzerEnabled) AnalyzerDomain.documentation.configName,
  ]..sort();
  final complianceScore = metrics.complianceScore;
  final suppressionPenaltyPoints = metrics.suppressionPenaltyPoints;
  final complianceFocusAreaLabel = metrics.complianceFocusAreaLabel;
  final complianceFocusAreaIssueCount = metrics.complianceFocusAreaIssueCount;
  final complianceNextInvestment = metrics.complianceNextInvestment;
  final commentSummary = _commentSummary(
    totalCommentLines: totalCommentLines,
    commentRatio: commentRatio,
    width: _gridValueWidth,
  );
  final nonCompliant = fileMetrics
      .where((metric) => !metric.isOneClassPerFileCompliant)
      .toList();

  final lines = <String>[];
  void addLine(String line) => lines.add(line);

  final filenamesOnly = listMode == ReportListMode.filenames;

  addLine(
    _labelValueLine(
      label: '${metrics.projectType.label} Project',
      value: '$projectName (version: $version)',
    ),
  );
  addLine(dividerLine('Scorecard'));
  addLine(
    _labelValueLine(
      label: 'Compliance Score',
      value: _scoreValue(complianceScore),
    ),
  );
  if (suppressionPenaltyPoints > 0) {
    addLine(
      _labelValueLine(
        label: 'Suppressions',
        value: _suppressionPenaltyValue(
          penaltyPoints: suppressionPenaltyPoints,
        ),
      ),
    );
  }
  if (complianceFocusAreaLabel == 'None') {
    addLine(
      _labelValueLine(
        label: 'Invest Next',
        value: complianceNextInvestment,
      ),
    );
  } else {
    addLine(
      _labelValueLine(
        label: 'Focus Area',
        value:
            '$complianceFocusAreaLabel (${formatCount(complianceFocusAreaIssueCount)} issues)',
      ),
    );
    addLine(
      _labelValueLine(
        label: 'Invest Next',
        value: complianceNextInvestment,
      ),
    );
  }

  final oneClassSummary = _domainValue(
    enabled: oneClassPerFileAnalyzerEnabled,
    issueCount: nonCompliant.length,
  );
  final hardcodedSummary = _domainValue(
    enabled: hardcodedStringsAnalyzerEnabled,
    issueCount: hardcodedStringIssues.length,
    width: _hardcodedValueWidth,
  );
  final magicNumbersSummary = _domainValue(
    enabled: magicNumbersAnalyzerEnabled,
    issueCount: magicNumberIssues.length,
  );
  final sourceSortingSummary = _domainValue(
    enabled: sourceSortingAnalyzerEnabled,
    issueCount: sourceSortIssues.length,
  );
  final layersSummary = _domainValue(
    enabled: layersAnalyzerEnabled,
    issueCount: layersIssues.length,
  );
  final secretsSummary = _domainValue(
    enabled: secretsAnalyzerEnabled,
    issueCount: secretIssues.length,
    anyIssueIsBad: true,
  );
  final deadCodeSummary = _domainValue(
    enabled: deadCodeAnalyzerEnabled,
    issueCount: deadCodeIssues.length,
  );
  final duplicateCodeSummary = _domainValue(
    enabled: duplicateCodeAnalyzerEnabled,
    issueCount: duplicateCodeIssues.length,
  );
  final localizationLabel = 'Localization (${usesLocalization ? 'ON' : 'OFF'})';
  final hardcodedCountText = hardcodedStringsAnalyzerEnabled
      ? formatCount(hardcodedStringIssues.length).padLeft(_hardcodedValueWidth)
      : 'disabled';
  final localizationHardcodedValue =
      !usesLocalization && hardcodedStringsAnalyzerEnabled
          ? _colorize(hardcodedCountText, _ansiGray)
          : hardcodedSummary;
  final localizationHardcodedPlain =
      'HardCoded $hardcodedCountText'.padLeft(_gridValueWidth);
  final localizationHardcodedSummary = localizationHardcodedPlain.replaceRange(
    localizationHardcodedPlain.length - hardcodedCountText.length,
    localizationHardcodedPlain.length,
    localizationHardcodedValue,
  );
  final localizationCell = _labelValueLine(
    label: localizationLabel,
    value: localizationHardcodedSummary,
  );
  addLine(dividerLine('Dashboard'));
  addLine(_gridRow([
    _gridCell(label: 'Files', value: formatCount(totalFiles)),
    _gridCell(label: 'Dart Files', value: formatCount(totalDartFiles)),
  ]));
  addLine(_gridRow([
    _gridCell(label: 'Excluded Files', value: formatCount(excludedFilesCount)),
    localizationCell,
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'Custom Excludes',
      value: _suppressionCountValue(
        count: customExcludedFilesCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
    _gridCell(
      label: 'Ignore Directives',
      value: _suppressionCountValue(
        count: ignoreDirectivesCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'Disabled Rules',
      value: _suppressionCountValue(
        count: disabledAnalyzersCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
    _gridCell(
      label: 'Folders',
      value: formatCount(totalFolders),
    ),
  ]));
  addLine(_gridRow([
    _gridCell(label: 'Lines of Code', value: formatCount(totalLinesOfCode)),
    _gridCell(
      label: 'Comments',
      value: commentSummary,
      valuePreAligned: true,
    ),
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'One Class/File',
      value: oneClassSummary,
      valuePreAligned: true,
    ),
    _gridCell(
      label: 'Magic Numbers',
      value: magicNumbersSummary,
      valuePreAligned: true,
    ),
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'Secrets',
      value: secretsSummary,
      valuePreAligned: true,
    ),
    _gridCell(
      label: 'Dead Code',
      value: deadCodeSummary,
      valuePreAligned: true,
    ),
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'Layers',
      value: layersSummary,
      valuePreAligned: true,
    ),
    _gridCell(
      label: 'Source Sorting',
      value: sourceSortingSummary,
      valuePreAligned: true,
    ),
  ]));
  addLine(_gridRow([
    _gridCell(
      label: 'Dependencies',
      value: layersAnalyzerEnabled ? formatCount(layersEdgeCount) : 'disabled',
    ),
    _gridCell(
      label: 'Duplicate Code',
      value: duplicateCodeSummary,
      valuePreAligned: true,
    ),
  ]));

  if (listMode == ReportListMode.none) {
    return lines;
  }

  addLine(dividerLine('Lists'));
  final listBlocks = <_ListBlock>[];

  void addListBlock({
    required _ListBlockStatus status,
    required String sortKey,
    required List<String> blockLines,
  }) {
    if (blockLines.isEmpty) {
      return;
    }
    listBlocks.add(
      _ListBlock(
        status: status,
        sortKey: sortKey,
        lines: blockLines,
      ),
    );
  }

  if (ignoreDirectivesCount == 0 &&
      customExcludedFilesCount == 0 &&
      disabledAnalyzersCount == 0) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'suppressions',
      blockLines: ['${okTag()} Suppressions check passed.'],
    );
  } else {
    final suppressionTag = suppressionPenaltyPoints > 0 ? failTag() : warnTag();
    final suffix = suppressionPenaltyPoints > 0
        ? '(score deduction applied: ${_suppressionPenaltyValue(penaltyPoints: suppressionPenaltyPoints)})'
        : '(within budget, no score deduction)';
    final blockLines = <String>[
      '$suppressionTag Suppressions summary $suffix:',
    ];
    if (ignoreDirectivesCount > 0) {
      final fileLabel = ignoreDirectiveFileCount == 1 ? 'file' : 'files';
      blockLines.add(
        '  - Ignore directives: ${_suppressionCountValue(count: ignoreDirectivesCount)} across ${_suppressionCountValue(count: ignoreDirectiveFileCount)} $fileLabel',
      );
      if (ignoreDirectiveEntries.isNotEmpty) {
        final visibleIgnoreDirectiveEntries = _issuesForMode(
          ignoreDirectiveEntries,
          listMode,
        ).toList();
        for (final entry in visibleIgnoreDirectiveEntries) {
          if (filenamesOnly) {
            blockLines.add('    - ${entry.key}');
            continue;
          }
          blockLines.add(
            '    - ${entry.key} (${_suppressionCountValue(count: entry.value)})',
          );
        }
        if (listMode == ReportListMode.partial &&
            ignoreDirectiveEntries.length > _maxIssuesToShow) {
          blockLines.add(
            '    ... and ${formatCount(ignoreDirectiveEntries.length - _maxIssuesToShow)} more',
          );
        }
      }
    } else {
      blockLines.add(
        '  - Ignore directives: ${_suppressionCountValue(count: ignoreDirectivesCount)}',
      );
    }
    if (customExcludedFilesCount > 0) {
      final customExcludeFileLabel = customExcludedFilesCount == 1
          ? 'Dart file excluded'
          : 'Dart files excluded';
      blockLines.add(
        '  - Custom excludes: ${_suppressionCountValue(count: customExcludedFilesCount)} $customExcludeFileLabel (file count; from .fcheck input.exclude or --exclude)',
      );
    }
    if (disabledAnalyzersCount > 0) {
      final analyzerLabel =
          disabledAnalyzersCount == 1 ? 'analyzer' : 'analyzers';
      blockLines.add(
        '  ${skipTag()} Disabled analyzers: ${_suppressionCountValue(count: disabledAnalyzersCount)} $analyzerLabel:',
      );
      for (final analyzerKey in disabledAnalyzerKeys) {
        blockLines.add('    ${skipTag()} $analyzerKey');
      }
    }
    blockLines.add('');
    addListBlock(
      status: suppressionPenaltyPoints > 0
          ? _ListBlockStatus.failure
          : _ListBlockStatus.warning,
      sortKey: 'suppressions',
      blockLines: blockLines,
    );
  }

  if (!oneClassPerFileAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'one class per file',
      blockLines: ['${skipTag()} One class per file check skipped (disabled).'],
    );
  } else if (nonCompliant.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'one class per file',
      blockLines: ['${okTag()} One class per file check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${failTag()} ${formatCount(nonCompliant.length)} files violate the "one class per file" rule:',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(nonCompliant.map((m) => m.path));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final classCountWidth =
          _maxIntWidth(nonCompliant.map((metric) => metric.classCount));
      for (final metric in nonCompliant) {
        final classCountText =
            metric.classCount.toString().padLeft(classCountWidth);
        blockLines.add('  - ${metric.path} ($classCountText classes found)');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.failure,
      sortKey: 'one class per file',
      blockLines: blockLines,
    );
  }

  if (!hardcodedStringsAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'hardcoded strings',
      blockLines: ['${skipTag()} Hardcoded strings check skipped (disabled).'],
    );
  } else if (hardcodedStringIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'hardcoded strings',
      blockLines: ['${okTag()} Hardcoded strings check passed.'],
    );
  } else if (usesLocalization) {
    final blockLines = <String>[
      '${failTag()} ${formatCount(hardcodedStringIssues.length)} hardcoded strings detected (localization enabled):',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(hardcodedStringIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleHardcodedIssues =
          _issuesForMode(hardcodedStringIssues, listMode).toList();
      for (final issue in visibleHardcodedIssues) {
        blockLines.add('  - ${issue.format()}');
      }
      if (listMode == ReportListMode.partial &&
          hardcodedStringIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(hardcodedStringIssues.length - _maxIssuesToShow)} more');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.failure,
      sortKey: 'hardcoded strings',
      blockLines: blockLines,
    );
  } else {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'hardcoded strings',
      blockLines: [
        '${skipTag()} Hardcoded strings check skipped (localization off).',
      ],
    );
  }

  if (!magicNumbersAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'magic numbers',
      blockLines: ['${skipTag()} Magic numbers check skipped (disabled).'],
    );
  } else if (magicNumberIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'magic numbers',
      blockLines: ['${okTag()} Magic numbers check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(magicNumberIssues.length)} magic numbers detected:',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(magicNumberIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleMagicNumberIssues =
          _issuesForMode(magicNumberIssues, listMode).toList();
      for (final issue in visibleMagicNumberIssues) {
        blockLines.add('  - ${issue.format()}');
      }
      if (listMode == ReportListMode.partial &&
          magicNumberIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(magicNumberIssues.length - _maxIssuesToShow)} more');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'magic numbers',
      blockLines: blockLines,
    );
  }

  if (!sourceSortingAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'source sorting',
      blockLines: [
        '${skipTag()} Flutter class member sorting skipped (disabled).'
      ],
    );
  } else if (sourceSortIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'source sorting',
      blockLines: ['${okTag()} Flutter class member sorting passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(sourceSortIssues.length)} Flutter classes have unsorted members:',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(sourceSortIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleSourceSortIssues =
          _issuesForMode(sourceSortIssues, listMode).toList();
      for (final issue in visibleSourceSortIssues) {
        blockLines.add('  - ${issue.format()}');
      }
      if (listMode == ReportListMode.partial &&
          sourceSortIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(sourceSortIssues.length - _maxIssuesToShow)} more');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'source sorting',
      blockLines: blockLines,
    );
  }

  if (!secretsAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'secrets',
      blockLines: ['${skipTag()} Secrets scan skipped (disabled).'],
    );
  } else if (secretIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'secrets',
      blockLines: ['${okTag()} Secrets scan passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(secretIssues.length)} potential secrets detected:',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(secretIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleSecretIssues =
          _issuesForMode(secretIssues, listMode).toList();
      for (final issue in visibleSecretIssues) {
        blockLines.add('  - ${issue.format()}');
      }
      if (listMode == ReportListMode.partial &&
          secretIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(secretIssues.length - _maxIssuesToShow)} more');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'secrets',
      blockLines: blockLines,
    );
  }

  if (!deadCodeAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'dead code',
      blockLines: ['${skipTag()} Dead code check skipped (disabled).'],
    );
  } else if (deadCodeIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'dead code',
      blockLines: ['${okTag()} Dead code check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(deadCodeIssues.length)} dead code issues detected:',
    ];
    if (deadFileIssues.isNotEmpty) {
      final deadFilePaths = filenamesOnly
          ? _uniqueFilePaths(deadFileIssues.map((i) => i.filePath))
          : const <String>[];
      final deadFileCount =
          filenamesOnly ? deadFilePaths.length : deadFileIssues.length;
      blockLines.add('  Dead files (${formatCount(deadFileCount)}):');
      if (filenamesOnly) {
        for (final path in deadFilePaths) {
          blockLines.add('    - $path');
        }
      } else {
        final visibleDeadFileIssues =
            _issuesForMode(deadFileIssues, listMode).toList();
        for (final issue in visibleDeadFileIssues) {
          blockLines.add('    - ${issue.formatGrouped()}');
        }
        if (listMode == ReportListMode.partial &&
            deadFileIssues.length > _maxIssuesToShow) {
          blockLines.add(
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
      blockLines.add('  Dead classes (${formatCount(deadClassCount)}):');
      if (filenamesOnly) {
        for (final path in deadClassPaths) {
          blockLines.add('    - $path');
        }
      } else {
        final visibleDeadClassIssues =
            _issuesForMode(deadClassIssues, listMode).toList();
        for (final issue in visibleDeadClassIssues) {
          blockLines.add('    - ${issue.formatGrouped()}');
        }
        if (listMode == ReportListMode.partial &&
            deadClassIssues.length > _maxIssuesToShow) {
          blockLines.add(
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
      blockLines.add('  Dead functions (${formatCount(deadFunctionCount)}):');
      if (filenamesOnly) {
        for (final path in deadFunctionPaths) {
          blockLines.add('    - $path');
        }
      } else {
        final visibleDeadFunctionIssues =
            _issuesForMode(deadFunctionIssues, listMode).toList();
        for (final issue in visibleDeadFunctionIssues) {
          blockLines.add('    - ${issue.formatGrouped()}');
        }
        if (listMode == ReportListMode.partial &&
            deadFunctionIssues.length > _maxIssuesToShow) {
          blockLines.add(
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
      blockLines
          .add('  Unused variables (${formatCount(unusedVariableCount)}):');
      if (filenamesOnly) {
        for (final path in unusedVariablePaths) {
          blockLines.add('    - $path');
        }
      } else {
        final visibleUnusedVariableIssues =
            _issuesForMode(unusedVariableIssues, listMode).toList();
        for (final issue in visibleUnusedVariableIssues) {
          blockLines.add('    - ${issue.formatGrouped()}');
        }
        if (listMode == ReportListMode.partial &&
            unusedVariableIssues.length > _maxIssuesToShow) {
          blockLines.add(
              '    ... and ${formatCount(unusedVariableIssues.length - _maxIssuesToShow)} more');
        }
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'dead code',
      blockLines: blockLines,
    );
  }

  if (!duplicateCodeAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'duplicate code',
      blockLines: ['${skipTag()} Duplicate code check skipped (disabled).'],
    );
  } else if (duplicateCodeIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'duplicate code',
      blockLines: ['${okTag()} Duplicate code check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(duplicateCodeIssues.length)} duplicate code blocks detected:',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(
        duplicateCodeIssues.expand((issue) => [
              issue.firstFilePath,
              issue.secondFilePath,
            ]),
      );
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleDuplicateCodeIssues =
          _issuesForMode(duplicateCodeIssues, listMode).toList();
      final duplicateSimilarityWidth = _maxIntWidth(
        visibleDuplicateCodeIssues
            .map((issue) => issue.similarityPercentRoundedDown),
      );
      final duplicateLineCountWidth = _maxIntWidth(
        visibleDuplicateCodeIssues.map((issue) => issue.lineCount),
      );
      for (final issue in visibleDuplicateCodeIssues) {
        blockLines.add(
          '  - ${issue.format(similarityPercentWidth: duplicateSimilarityWidth, lineCountWidth: duplicateLineCountWidth)}',
        );
      }
      if (listMode == ReportListMode.partial &&
          duplicateCodeIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(duplicateCodeIssues.length - _maxIssuesToShow)} more');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'duplicate code',
      blockLines: blockLines,
    );
  }

  if (!documentationAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'documentation',
      blockLines: ['${skipTag()} Documentation check skipped (disabled).'],
    );
  } else if (documentationIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'documentation',
      blockLines: ['${okTag()} Documentation check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(documentationIssues.length)} documentation issues detected:',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(documentationIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      final visibleDocumentationIssues =
          _issuesForMode(documentationIssues, listMode).toList();
      for (final issue in visibleDocumentationIssues) {
        blockLines.add('  - ${issue.format()}');
      }
      if (listMode == ReportListMode.partial &&
          documentationIssues.length > _maxIssuesToShow) {
        blockLines.add(
          '  ... and ${formatCount(documentationIssues.length - _maxIssuesToShow)} more',
        );
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'documentation',
      blockLines: blockLines,
    );
  }

  if (!layersAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'layers architecture',
      blockLines: [
        '${skipTag()} Layers architecture check skipped (disabled).'
      ],
    );
  } else if (layersIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'layers architecture',
      blockLines: ['${okTag()} Layers architecture check passed.'],
    );
  } else {
    final blockLines = <String>[
      '${failTag()} ${formatCount(layersIssues.length)} layers architecture violations detected:',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(layersIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - $path');
      }
    } else {
      for (final issue in _issuesForMode(layersIssues, listMode)) {
        blockLines.add('  - $issue');
      }
      if (listMode == ReportListMode.partial &&
          layersIssues.length > _maxIssuesToShow) {
        blockLines.add(
            '  ... and ${formatCount(layersIssues.length - _maxIssuesToShow)} more');
      }
    }
    addListBlock(
      status: _ListBlockStatus.failure,
      sortKey: 'layers architecture',
      blockLines: blockLines,
    );
  }

  const statusOrder = <_ListBlockStatus, int>{
    _ListBlockStatus.success: 0,
    _ListBlockStatus.disabled: 1,
    _ListBlockStatus.warning: 2,
    _ListBlockStatus.failure: 3,
  };
  listBlocks.sort((left, right) {
    final leftOrder = statusOrder[left.status] ?? _unknownListBlockOrder;
    final rightOrder = statusOrder[right.status] ?? _unknownListBlockOrder;
    final statusCompare = leftOrder.compareTo(rightOrder);
    if (statusCompare != 0) {
      return statusCompare;
    }
    return left.sortKey.compareTo(right.sortKey);
  });

  for (final block in listBlocks) {
    for (final blockLine in block.lines) {
      addLine(blockLine);
    }
  }

  return lines;
}

enum _ListBlockStatus { success, disabled, warning, failure }

class _ListBlock {
  final _ListBlockStatus status;
  final String sortKey;
  final List<String> lines;

  const _ListBlock({
    required this.status,
    required this.sortKey,
    required this.lines,
  });
}

/// Returns the in-file ignore directive for an analyzer, when supported.
///
/// Some analyzers intentionally do not support per-file ignore comments and
/// return `null`.
String? _ignoreDirectiveForAnalyzer(AnalyzerDomain analyzer) {
  switch (analyzer) {
    case AnalyzerDomain.documentation:
      return IgnoreConfig.ignoreDirectiveForDocumentation;
    case AnalyzerDomain.oneClassPerFile:
      return IgnoreConfig.ignoreDirectiveForOneClassPerFile;
    case AnalyzerDomain.hardcodedStrings:
      return IgnoreConfig.ignoreDirectiveForHardcodedStrings;
    case AnalyzerDomain.magicNumbers:
      return IgnoreConfig.ignoreDirectiveForMagicNumbers;
    case AnalyzerDomain.sourceSorting:
      return null;
    case AnalyzerDomain.layers:
      return IgnoreConfig.ignoreDirectiveForLayers;
    case AnalyzerDomain.secrets:
      return IgnoreConfig.ignoreDirectiveForSecrets;
    case AnalyzerDomain.deadCode:
      return IgnoreConfig.ignoreDirectiveForDeadCode;
    case AnalyzerDomain.duplicateCode:
      return IgnoreConfig.ignoreDirectiveForDuplicateCode;
  }
}

/// Prints ignore setup guidance for analyzer directives and `.fcheck`.
///
/// This help screen explains both in-file ignore comments and equivalent
/// `.fcheck` configuration options, including analyzer-specific directives.
void printIgnoreSetupGuide() {
  final sortedAnalyzers = List<AnalyzerDomain>.from(AnalyzerDomain.values)
    ..sort((left, right) => left.configName.compareTo(right.configName));

  var maxAnalyzerNameLength = 0;
  for (final analyzer in sortedAnalyzers) {
    if (analyzer.configName.length > maxAnalyzerNameLength) {
      maxAnalyzerNameLength = analyzer.configName.length;
    }
  }

  print('--------------------------------------------');
  print('Setup ignores directly in Dart file');
  print(
      'Top-of-file directives must be placed before any Dart code in the file.');
  print('');

  var index = 1;
  for (final analyzer in sortedAnalyzers) {
    final directive = _ignoreDirectiveForAnalyzer(analyzer);
    final directiveText = directive ?? '(no comment ignore support)';
    final analyzerName = analyzer.configName.padRight(maxAnalyzerNameLength);
    print('  $index. $analyzerName | $directiveText');
    index++;
  }

  print('');
  print('Hardcoded strings also support Flutter-style ignore comments:');
  print('  - // ignore_for_file: avoid_hardcoded_strings_in_widgets');

  print('--------------------------------------------');
  print('Setup using the .fcheck file');
  print('Create .fcheck in the --input directory (or current directory).');
  print('Supported example:');
  print('  input:');
  print('    exclude:');
  print('      - "**/example/**"');
  print('');
  print('  analyzers:');
  print('    default: on|off');
  print('    disabled: # or enabled');
  print('      - hardcoded_strings');
  print('    options:');
  print('      duplicate_code:');
  print('        similarity_threshold: 0.90 # 0.0 to 1.0');
  print('        min_tokens: 20');
  print('        min_non_empty_lines: 8');
  print('');
  print('Available analyzer names:');
  for (final analyzer in sortedAnalyzers) {
    print('      - ${analyzer.configName}');
  }
}

/// Prints scoring model guidance for compliance score calculation.
///
/// The formulas mirror the implementation in `ProjectMetrics` so users can
/// understand how issue counts map to a 0-100 compliance score.
void printScoreSystemGuide() {
  final analyzers = List<AnalyzerDomain>.from(AnalyzerDomain.values);
  final analyzerCount = analyzers.length;
  final sharePerAnalyzer = analyzerCount == 0
      ? _percentageMultiplier.toDouble()
      : _percentageMultiplier / analyzerCount;

  print('--------------------------------------------');
  print('Compliance score model from 0% to 100%');
  print('Only enabled analyzers contribute to the score.');
  print('');
  print('Enabled analyzers (current model: $analyzerCount):');
  for (final analyzer in analyzers) {
    print('  - ${analyzer.configName}');
  }
  print('');
  print('How is the 100% distributed:');
  print('  N = number of enabled analyzers');
  print('  each analyzer share = 100 / N');
  print(
      '  Current: $analyzerCount analyzers -> ${_formatCompactDecimal(sharePerAnalyzer)}% each');
  print('');
  print('Per-analyzer domain score is clamped to [0.0, 1.0].');
  print('One domain can only consume its own share, never more.');
  print('');
  print('Domain formulas used:');
  print('  - one_class_per_file: 1 - (violations / max(1, dartFiles))');
  print(
      '  - hardcoded_strings: 1 - (issues / max(3.0, dartFiles * (l10n ? 0.8 : 2.0)))');
  print(
      '  - magic_numbers: 1 - (issues / max(4.0, dartFiles * 2.5 + loc / 450))');
  print('  - source_sorting: 1 - (issues / max(2.0, dartFiles * 0.75))');
  print('  - layers: 1 - (issues / max(2.0, max(1, edges) * 0.20))');
  print('  - secrets: 1 - (issues / 1.5)');
  print('  - dead_code: 1 - (issues / max(3.0, dartFiles * 0.8))');
  print('  - duplicate_code: 1 - ((impactLines / max(1, loc)) * 2.5)');
  print('    impactLines = sum(issue.lineCount * issue.similarity)');
  print('');
  print('Suppression penalty (budget-based):');
  print(
      '  - ignore directives budget: max(3.0, dartFiles * 0.12 + loc / 2500)');
  print(
      '  - custom excludes budget: max(2.0, (dartFiles + customExcluded) * 0.08)');
  print('  - disabled analyzers budget: 1.0');
  print('  - weightedOveruse =');
  print('      over(ignore) * 0.45 + over(customExcluded) * 0.35 +');
  print('      over(disabledAnalyzers) * 0.20');
  print('  - suppressionPenaltyPoints =');
  print('      round(clamp(weightedOveruse * 25, 0, 25))');
  print('    over(x) = max(0, (used - budget) / budget)');
  print('');
  print('Final score:');
  print('  average = sum(enabledDomainScores) / N');
  print('  baseScore = clamp(average * 100, 0, 100)');
  print(
      '  complianceScore = round(clamp(baseScore - suppressionPenalty, 0, 100))');
  print('  Special rule: if rounded score is 100 but any enabled domain');
  print('  score is below 1.0, or suppression penalty > 0, final score is 99.');
  print('');
  print('Focus Area and Invest Next:');
  print(
      '  - Focus Area is the enabled domain with the highest penalty impact.');
  print('  - Tie-breaker: domain with more issues.');
  print(
      '  - Invest Next recommendation is mapped from the selected focus area.');
}

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
  print('Error: Directory "$path" does not exist.');
}

/// Prints a configuration error for invalid `.fcheck` content.
void printConfigurationError(String message) {
  print('Error: Invalid .fcheck configuration. $message');
}

/// Prints the run header before analysis starts.
///
/// Includes tool version and normalized input directory path.
void printRunHeader({
  required String version,
  required Directory directory,
}) {
  print(dividerLine('fCheck $version', downPointer: true));
  print(_labelValueLine(label: 'Input', value: directory.absolute.path));
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
///
/// [label] is expected to be pre-padded by the caller for visual alignment.
void printOutputFileLine({
  required String label,
  required String path,
}) {
  final normalizedPath = normalizeIssueLocation(path).path;
  print('$label ${_separatorColon()} $normalizedPath');
}

/// Prints run completion footer with elapsed time in seconds.
void printRunCompleted(String elapsedSeconds) {
  print(dividerLine('fCheck completed (${elapsedSeconds}s)',
      dot: false, downPointer: false));
}

/// Prints fatal analysis error and stack trace details.
///
/// This keeps CLI failures transparent for local debugging and CI logs.
void printAnalysisError(Object error, StackTrace stack) {
  print('Error during analysis: $error');
  print(stack);
}

/// Length of the header and footer lines
final int dividerLength = 40;
const int _halfTitleLengthDivisor = 2;

bool get _supportsAnsiEscapes =>
    stdout.hasTerminal && stdout.supportsAnsiEscapes;

const int _ansiGreen = 32;
const int _ansiGreenBright = 92;
const int _ansiYellow = 33;
const int _ansiYellowBright = 93;
const int _ansiOrange = 33;
const int _ansiRed = 31;
const int _ansiRedBright = 91;
const int _ansiGray = 90;

String _colorize(String text, int colorCode) =>
    _supportsAnsiEscapes ? '\x1B[${colorCode}m$text\x1B[0m' : text;

String _colorizeBold(String text, int colorCode) =>
    _supportsAnsiEscapes ? '\x1B[1;${colorCode}m$text\x1B[0m' : text;

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
///
/// [title] is centered between repeated side characters.
/// [downPointer] controls arrow direction (`↓` vs `↑`).
/// [dot] switches from `-` to `·` style separators.
String dividerLine(String title, {bool? downPointer, bool dot = false}) {
  title = ' $title ';
  final lineType = dot ? '·' : '-';
  final directionChar = downPointer == null
      ? lineType
      : downPointer == true
          ? '↓'
          : '↑';
  final sideLines =
      lineType * (dividerLength - (title.length ~/ _halfTitleLengthDivisor));

  String lineAndTitle = '$sideLines$title$sideLines';

  if (lineAndTitle.length % _halfTitleLengthDivisor == 0) {
    lineAndTitle += lineType;
  }

  return '$directionChar$lineAndTitle$directionChar';
}
