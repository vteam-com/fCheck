import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:fcheck/src/models/project_type.dart';

import 'console_common.dart';

const int _maxIssuesToShow = 10;
const int _percentageMultiplier = 100;
const int _gridLabelWidth = 18;
const int _gridValueWidth = 15;
const int _domainValueWidth = 18;
const int _perfectScoreThreshold = 95;
const int _goodScoreThreshold = 85;
const int _fairScoreThreshold = 70;
const int _minHealthyCommentRatioPercent = 10;
const int _minorIssueCountUpperBound = 3;
const int _compactDecimalPlaces = 2;
const int _hardcodedValueWidth = 3;
const int _emptyRightDashboardCellPadding = 3;
const int _minorSuppressionPenaltyUpperBound = 3;
const int _moderateSuppressionPenaltyUpperBound = 7;
const int _maxSuppressionPenaltyPoints = 25;
const int _analyzerHeaderTitleWidth = 22;
const int _cleanAnalyzerSortGroup = 0;
const int _warningAnalyzerSortGroup = 1;
const int _disabledAnalyzerSortGroup = 2;
const String _noneIndicator = AppStrings.noneIndicator;
const Map<String, String> _analyzerTitleByKey = {
  'one_class_per_file': 'One class per file',
  'hardcoded_strings': 'Hardcoded strings',
  'magic_numbers': 'Magic numbers',
  'source_sorting': 'Source sorting',
  'layers': 'Layers architecture',
  'secrets': 'Secrets',
  'dead_code': 'Dead code',
  'duplicate_code': 'Duplicate code',
  'documentation': 'Documentation',
  'suppression_hygiene': 'Suppression hygiene',
};

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
    final value = path == null
        ? AppStrings.unknownLocation
        : normalizeIssueLocation(path).path;
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
String _pathText(String path) => colorizePathFilename(path);

String _labelValueLine({
  required String label,
  required String value,
  int labelWidth = _gridLabelWidth,
}) =>
    '${_colorize(label.padRight(labelWidth), _ansiGray)} ${_separatorColon()} $value';

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

/// Returns the analyzer status badge used in analyzer section headers.
///
/// Badge selection depends on enablement, effective score, and issue count.
String _analyzerStatusIndicator({
  required bool enabled,
  required int scorePercent,
  required int issueCount,
}) {
  if (!enabled) {
    return _colorize('[-]', _ansiGray);
  }
  if (issueCount == 0 && scorePercent == _percentageMultiplier) {
    return _colorize('[✓]', _ansiGreen);
  }
  if (scorePercent >= _fairScoreThreshold) {
    return _colorize('[!]', _ansiYellowBright);
  }
  return _colorize('[x]', _ansiRedBright);
}

/// Builds a formatted analyzer section header with optional deduction suffix.
///
/// The header includes the status badge, aligned analyzer title, and when
/// applicable the deduction percentage with issue count.
String _analyzerSectionHeader({
  required String title,
  required bool enabled,
  required int issueCount,
  required double deductionPercent,
}) {
  final headerTitle = _colorizeBold(
    title.padRight(_analyzerHeaderTitleWidth),
    _ansiWhiteBright,
  );
  final statusText = _analyzerStatusIndicator(
    enabled: enabled,
    scorePercent: _percentageMultiplier - deductionPercent.round(),
    issueCount: issueCount,
  );
  final deductionText = _analyzerDeductionValue(
    enabled: enabled,
    issueCount: issueCount,
    deductionPercent: deductionPercent,
  );
  if (deductionText.isEmpty) {
    return '$statusText $headerTitle';
  }
  return '$statusText $headerTitle $deductionText';
}

/// Formats the deduction segment shown in analyzer section headers.
///
/// Returns an empty string when the analyzer is disabled or has no issues.
String _analyzerDeductionValue({
  required bool enabled,
  required int issueCount,
  required double deductionPercent,
}) {
  if (!enabled || issueCount == 0) {
    return '';
  }
  final normalizedDeduction =
      deductionPercent.clamp(0, _percentageMultiplier).toDouble();
  final deductionText = '-${_formatCompactDecimal(normalizedDeduction)}%';
  final issueText = formatCount(issueCount);
  return _colorize('$deductionText ($issueText)', _ansiYellow);
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
      return AppStrings.disabled;
    }
    return AppStrings.disabled.padLeft(width);
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
      '(${formatCount(ratioPercent)}%) ${formatCount(totalCommentLines)}';
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
/// - Analyzers (grouped per analyzer with score, summary, and optional details)
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
          : () {
              final normalizedCounts = <String, int>{};
              for (final entry in metrics.ignoreDirectiveCountsByFile.entries) {
                final normalizedPath = normalizeIssueLocation(entry.key).path;
                normalizedCounts[normalizedPath] =
                    (normalizedCounts[normalizedPath] ?? 0) + entry.value;
              }
              return normalizedCounts;
            }();
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
  final analyzerScoresByKey = <String, int>{
    for (final score in metrics.analyzerScores) score.key: score.scorePercent,
    'suppression_hygiene': (_percentageMultiplier -
            ((suppressionPenaltyPoints / _maxSuppressionPenaltyPoints) *
                    _percentageMultiplier)
                .round())
        .clamp(0, _percentageMultiplier),
  };
  final analyzerIssueCountsByKey = <String, int>{
    for (final score in metrics.analyzerScores) score.key: score.issueCount,
    'suppression_hygiene': ignoreDirectivesCount +
        customExcludedFilesCount +
        disabledAnalyzersCount,
  };
  final analyzerEnabledByKey = <String, bool>{
    for (final score in metrics.analyzerScores) score.key: score.enabled,
    'suppression_hygiene': true,
  };
  final enabledScoredAnalyzerCount = metrics.analyzerScores
      .where((score) => score.enabled)
      .where(
        (score) =>
            score.key != 'documentation' || documentationIssues.isNotEmpty,
      )
      .length;
  final safeEnabledScoredAnalyzerCount =
      enabledScoredAnalyzerCount == 0 ? 1 : enabledScoredAnalyzerCount;
  final analyzerDeductionPercentByKey = <String, double>{
    for (final score in metrics.analyzerScores)
      score.key: score.enabled
          ? ((1 - score.score).clamp(0.0, 1.0) * _percentageMultiplier) /
              safeEnabledScoredAnalyzerCount
          : 0,
    'suppression_hygiene': suppressionPenaltyPoints.toDouble(),
  };
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
  void appendScorecardSection() {
    addLine(dividerLine(AppStrings.scorecardDivider));
    addLine(
      _labelValueLine(
        label: 'Total Score',
        value: _scoreValue(complianceScore),
      ),
    );
    if (suppressionPenaltyPoints > 0) {
      addLine(
        _labelValueLine(
          label: AppStrings.suppressions,
          value: _suppressionPenaltyValue(
            penaltyPoints: suppressionPenaltyPoints,
          ),
        ),
      );
    }
    if (complianceFocusAreaLabel == 'None') {
      addLine(
        _labelValueLine(
          label: AppStrings.investNext,
          value: complianceNextInvestment,
        ),
      );
    } else {
      addLine(
        _labelValueLine(
          label: AppStrings.focusArea,
          value:
              '$complianceFocusAreaLabel (${formatCount(complianceFocusAreaIssueCount)} ${AppStrings.issues})',
        ),
      );
      addLine(
        _labelValueLine(
          label: AppStrings.investNext,
          value: complianceNextInvestment,
        ),
      );
    }
  }

  final filenamesOnly = listMode == ReportListMode.filenames;

  addLine(
    _labelValueLine(
      label: '${metrics.projectType.label} ${AppStrings.project}',
      value: '$projectName (${AppStrings.version} $version)',
    ),
  );
  final hardcodedSummary = _domainValue(
    enabled: hardcodedStringsAnalyzerEnabled,
    issueCount: hardcodedStringIssues.length,
    width: _hardcodedValueWidth,
  );
  final localizationLabel =
      '${AppStrings.localization} (${usesLocalization ? AppStrings.on : AppStrings.off})';
  final hardcodedCountText = hardcodedStringsAnalyzerEnabled
      ? formatCount(hardcodedStringIssues.length).padLeft(_hardcodedValueWidth)
      : AppStrings.disabled;
  final localizationHardcodedValue = hardcodedSummary;
  final localizationHardcodedPlain =
      'Hardcoded $hardcodedCountText'.padLeft(_gridValueWidth);
  final localizationHardcodedSummary = localizationHardcodedPlain.replaceRange(
    localizationHardcodedPlain.length - hardcodedCountText.length,
    localizationHardcodedPlain.length,
    localizationHardcodedValue,
  );
  final localizationCell = _labelValueLine(
    label: localizationLabel,
    value: localizationHardcodedSummary,
  );
  addLine(dividerLine(AppStrings.dashboardDivider));
  final leftDashboardRows = <String>[
    _gridCell(label: AppStrings.folders, value: formatCount(totalFolders)),
    _gridCell(label: AppStrings.files, value: formatCount(totalFiles)),
    _gridCell(
      label: AppStrings.excludedFiles,
      value: formatCount(excludedFilesCount),
    ),
    _gridCell(label: AppStrings.dartFiles, value: formatCount(totalDartFiles)),
    _gridCell(label: AppStrings.loc, value: formatCount(totalLinesOfCode)),
    _gridCell(
      label: AppStrings.comments,
      value: commentSummary,
      valuePreAligned: true,
    ),
  ];
  final rightDashboardRows = <String>[
    localizationCell,
    _gridCell(
      label: AppStrings.customExcludes,
      value: _suppressionCountValue(
        count: customExcludedFilesCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
    _gridCell(
      label: AppStrings.ignoreDirectives,
      value: _suppressionCountValue(
        count: ignoreDirectivesCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
    _gridCell(
      label: AppStrings.disabledRules,
      value: _suppressionCountValue(
        count: disabledAnalyzersCount,
        width: _gridValueWidth,
      ),
      valuePreAligned: true,
    ),
    _gridCell(
      label: AppStrings.dependencies,
      value: layersAnalyzerEnabled
          ? formatCount(layersEdgeCount)
          : AppStrings.disabled,
    ),
  ];
  for (var index = 0; index < leftDashboardRows.length; index++) {
    final rightCell = index < rightDashboardRows.length
        ? rightDashboardRows[index]
        : ''.padRight(
            _gridLabelWidth + _gridValueWidth + _emptyRightDashboardCellPadding,
          );
    addLine(_gridRow([leftDashboardRows[index], rightCell]));
  }

  addLine(dividerLine('Analyzers'));
  final listBlocks = <_ListBlock>[];

  void addListBlock({
    required _ListBlockStatus status,
    required String sortKey,
    required List<String> blockLines,
  }) {
    if (blockLines.isEmpty) {
      return;
    }
    final analyzerKey = _analyzerKeyForSortKey(sortKey);
    listBlocks.add(
      _ListBlock(
        status: status,
        analyzerKey: analyzerKey,
        analyzerTitle: _analyzerTitleForKey(analyzerKey),
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
      blockLines: ['${okTag()} Suppressions check ${AppStrings.checkPassed}'],
    );
  } else {
    final suppressionTag = suppressionPenaltyPoints > 0 ? failTag() : warnTag();
    final suffix = suppressionPenaltyPoints > 0
        ? '(score deduction applied: ${_suppressionPenaltyValue(penaltyPoints: suppressionPenaltyPoints)})'
        : '(within budget, no score deduction)';
    final blockLines = <String>[
      '$suppressionTag ${AppStrings.suppressionsSummary} $suffix:',
    ];
    if (ignoreDirectivesCount > 0) {
      final fileLabel = ignoreDirectiveFileCount == 1
          ? AppStrings.file
          : AppStrings.filesSmall;
      blockLines.add(
        '  - Ignore directives: ${_suppressionCountValue(count: ignoreDirectivesCount)} ${AppStrings.ignoreDirectivesAcross} ${_suppressionCountValue(count: ignoreDirectiveFileCount)} $fileLabel',
      );
      if (ignoreDirectiveEntries.isNotEmpty) {
        final visibleIgnoreDirectiveEntries = _issuesForMode(
          ignoreDirectiveEntries,
          listMode,
        ).toList();
        for (final entry in visibleIgnoreDirectiveEntries) {
          if (filenamesOnly) {
            blockLines.add('    - ${_pathText(entry.key)}');
            continue;
          }
          blockLines.add(
            '    - ${_pathText(entry.key)} (${_suppressionCountValue(count: entry.value)})',
          );
        }
        if (listMode == ReportListMode.partial &&
            ignoreDirectiveEntries.length > _maxIssuesToShow) {
          blockLines.add(
            '    ... ${AppStrings.and} ${formatCount(ignoreDirectiveEntries.length - _maxIssuesToShow)} ${AppStrings.more}',
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
          ? AppStrings.dartFileExcluded
          : AppStrings.dartFilesExcluded;
      blockLines.add(
        '  - ${AppStrings.customExcludes}: ${_suppressionCountValue(count: customExcludedFilesCount)} $customExcludeFileLabel (file count; from .fcheck input.exclude or --exclude)',
      );
    }
    if (disabledAnalyzersCount > 0) {
      final analyzerLabel = disabledAnalyzersCount == 1
          ? AppStrings.analyzerSmall
          : AppStrings.analyzersSmall;
      blockLines.add(
        '  ${skipTag()} ${AppStrings.disabledRules}: ${_suppressionCountValue(count: disabledAnalyzersCount)} $analyzerLabel:',
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
      blockLines: [
        '${skipTag()} One class per file check skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (nonCompliant.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'one class per file',
      blockLines: [
        '${okTag()} One class per file check ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${failTag()} ${formatCount(nonCompliant.length)} ${AppStrings.oneClassPerFileViolate}',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(nonCompliant.map((m) => m.path));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
      }
    } else {
      final classCountWidth =
          _maxIntWidth(nonCompliant.map((metric) => metric.classCount));
      for (final metric in nonCompliant) {
        final classCountText =
            metric.classCount.toString().padLeft(classCountWidth);
        final normalizedPath = normalizeIssueLocation(metric.path).path;
        blockLines.add(
          '  - ${_pathText(normalizedPath)} ($classCountText classes found)',
        );
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
      blockLines: [
        '${skipTag()} Hardcoded strings check skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (hardcodedStringIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'hardcoded strings',
      blockLines: [
        '${okTag()} Hardcoded strings check ${AppStrings.checkPassed}'
      ],
    );
  } else if (usesLocalization) {
    final blockLines = <String>[
      '${failTag()} ${formatCount(hardcodedStringIssues.length)} ${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.enabled}):',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(hardcodedStringIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
            '  ... ${AppStrings.and} ${formatCount(hardcodedStringIssues.length - _maxIssuesToShow)} ${AppStrings.more}');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.failure,
      sortKey: 'hardcoded strings',
      blockLines: blockLines,
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(hardcodedStringIssues.length)} ${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.off}):',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(hardcodedStringIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
            '  ... ${AppStrings.and} ${formatCount(hardcodedStringIssues.length - _maxIssuesToShow)} ${AppStrings.more}');
      }
    }
    blockLines.add('');
    addListBlock(
      status: _ListBlockStatus.warning,
      sortKey: 'hardcoded strings',
      blockLines: blockLines,
    );
  }

  if (!magicNumbersAnalyzerEnabled) {
    addListBlock(
      status: _ListBlockStatus.disabled,
      sortKey: 'magic numbers',
      blockLines: [
        '${skipTag()} Magic numbers check skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (magicNumberIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'magic numbers',
      blockLines: ['${okTag()} Magic numbers check ${AppStrings.checkPassed}'],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(magicNumberIssues.length)} ${AppStrings.magicNumbersDetected}',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(magicNumberIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
            '  ... ${AppStrings.and} ${formatCount(magicNumberIssues.length - _maxIssuesToShow)} ${AppStrings.more}');
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
        '${skipTag()} Flutter class member sorting skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (sourceSortIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'source sorting',
      blockLines: [
        '${okTag()} Flutter class member sorting ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(sourceSortIssues.length)} ${AppStrings.unsortedMembers}',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(sourceSortIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
      blockLines: [
        '${skipTag()} ${AppStrings.secretsScan} skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (secretIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'secrets',
      blockLines: [
        '${okTag()} ${AppStrings.secretsScan} ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(secretIssues.length)} ${AppStrings.potentialSecretsDetected}',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(secretIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
      blockLines: [
        '${skipTag()} ${AppStrings.deadCodeCheck} skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (deadCodeIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'dead code',
      blockLines: [
        '${okTag()} ${AppStrings.deadCodeCheck} ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(deadCodeIssues.length)} ${AppStrings.deadCodeIssuesDetected}',
    ];
    if (deadFileIssues.isNotEmpty) {
      final deadFilePaths = filenamesOnly
          ? _uniqueFilePaths(deadFileIssues.map((i) => i.filePath))
          : const <String>[];
      final deadFileCount =
          filenamesOnly ? deadFilePaths.length : deadFileIssues.length;
      blockLines
          .add('  ${AppStrings.deadFiles} (${formatCount(deadFileCount)}):');
      if (filenamesOnly) {
        for (final path in deadFilePaths) {
          blockLines.add('    - ${_pathText(path)}');
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
      blockLines
          .add('  ${AppStrings.deadClasses} (${formatCount(deadClassCount)}):');
      if (filenamesOnly) {
        for (final path in deadClassPaths) {
          blockLines.add('    - ${_pathText(path)}');
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
      blockLines.add(
          '  ${AppStrings.deadFunctions} (${formatCount(deadFunctionCount)}):');
      if (filenamesOnly) {
        for (final path in deadFunctionPaths) {
          blockLines.add('    - ${_pathText(path)}');
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
      blockLines.add(
          '  ${AppStrings.unusedVariables} (${formatCount(unusedVariableCount)}):');
      if (filenamesOnly) {
        for (final path in unusedVariablePaths) {
          blockLines.add('    - ${_pathText(path)}');
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
      blockLines: [
        '${skipTag()} ${AppStrings.duplicateCodeCheck} skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (duplicateCodeIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'duplicate code',
      blockLines: [
        '${okTag()} ${AppStrings.duplicateCodeCheck} ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(duplicateCodeIssues.length)} ${AppStrings.duplicateBlocksDetected}',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(
        duplicateCodeIssues.expand((issue) => [
              issue.firstFilePath,
              issue.secondFilePath,
            ]),
      );
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
      blockLines: [
        '${skipTag()} ${AppStrings.documentationCheck} skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (documentationIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'documentation',
      blockLines: [
        '${okTag()} ${AppStrings.documentationCheck} ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${warnTag()} ${formatCount(documentationIssues.length)} ${AppStrings.documentationIssuesDetected}',
    ];
    if (filenamesOnly) {
      final filePaths =
          _uniqueFilePaths(documentationIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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
        '${skipTag()} ${AppStrings.layersCheck} skipped (${AppStrings.disabled}).'
      ],
    );
  } else if (layersIssues.isEmpty) {
    addListBlock(
      status: _ListBlockStatus.success,
      sortKey: 'layers architecture',
      blockLines: [
        '${okTag()} ${AppStrings.layersCheck} ${AppStrings.checkPassed}'
      ],
    );
  } else {
    final blockLines = <String>[
      '${failTag()} ${formatCount(layersIssues.length)} ${AppStrings.layersViolationsDetected}',
    ];
    if (filenamesOnly) {
      final filePaths = _uniqueFilePaths(layersIssues.map((i) => i.filePath));
      for (final path in filePaths) {
        blockLines.add('  - ${_pathText(path)}');
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

  final orderedBlocks = List<_ListBlock>.from(listBlocks)
    ..sort((left, right) {
      final leftEnabled = analyzerEnabledByKey[left.analyzerKey] ?? false;
      final rightEnabled = analyzerEnabledByKey[right.analyzerKey] ?? false;
      final leftScore = analyzerScoresByKey[left.analyzerKey] ?? 0;
      final rightScore = analyzerScoresByKey[right.analyzerKey] ?? 0;
      final leftIssueCount = analyzerIssueCountsByKey[left.analyzerKey] ?? 0;
      final rightIssueCount = analyzerIssueCountsByKey[right.analyzerKey] ?? 0;
      final leftGroup = !leftEnabled
          ? _disabledAnalyzerSortGroup
          : (leftIssueCount == 0 && leftScore == _percentageMultiplier
              ? _cleanAnalyzerSortGroup
              : _warningAnalyzerSortGroup);
      final rightGroup = !rightEnabled
          ? _disabledAnalyzerSortGroup
          : (rightIssueCount == 0 && rightScore == _percentageMultiplier
              ? _cleanAnalyzerSortGroup
              : _warningAnalyzerSortGroup);
      final groupCompare = leftGroup.compareTo(rightGroup);
      if (groupCompare != 0) {
        return groupCompare;
      }

      if (leftGroup == _warningAnalyzerSortGroup) {
        final scoreCompare = rightScore.compareTo(leftScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
      }
      return left.analyzerTitle.compareTo(right.analyzerTitle);
    });

  for (var index = 0; index < orderedBlocks.length; index++) {
    final block = orderedBlocks[index];
    final analyzerScore = analyzerScoresByKey[block.analyzerKey] ?? 0;
    final analyzerIssueCount = analyzerIssueCountsByKey[block.analyzerKey] ?? 0;
    final analyzerEnabled = analyzerEnabledByKey[block.analyzerKey] ?? false;
    final analyzerDeductionPercent =
        analyzerDeductionPercentByKey[block.analyzerKey] ?? 0;
    final hidePassedSummaryLine = analyzerEnabled &&
        analyzerScore == _percentageMultiplier &&
        analyzerIssueCount == 0;
    addLine(
      _analyzerSectionHeader(
        title: block.analyzerTitle,
        enabled: analyzerEnabled,
        issueCount: analyzerIssueCount,
        deductionPercent: analyzerDeductionPercent,
      ),
    );
    if (!hidePassedSummaryLine) {
      addLine(_withoutLeadingStatusTag(block.lines.first).trimLeft());
    }
    if (listMode != ReportListMode.none) {
      for (final blockLine in block.lines.skip(1)) {
        if (blockLine.trim().isEmpty) {
          continue;
        }
        addLine(_withoutLeadingStatusTag(blockLine));
      }
    }
    final printedWarningDetails =
        analyzerIssueCount > 0 && listMode != ReportListMode.none;
    if (printedWarningDetails && index < orderedBlocks.length - 1) {
      addLine('');
    }
  }

  addLine('');
  appendScorecardSection();

  return lines;
}

enum _ListBlockStatus { success, disabled, warning, failure }

class _ListBlock {
  final _ListBlockStatus status;
  final String analyzerKey;
  final String analyzerTitle;
  final List<String> lines;

  const _ListBlock({
    required this.status,
    required this.analyzerKey,
    required this.analyzerTitle,
    required this.lines,
  });
}

/// Maps list sorting labels to canonical analyzer keys.
///
/// Known analyzer titles are resolved through [_analyzerTitleByKey]. Unknown
/// labels fall back to snake_case conversion.
String _analyzerKeyForSortKey(String sortKey) {
  final normalized = sortKey.toLowerCase();
  for (final entry in _analyzerTitleByKey.entries) {
    if (entry.value.toLowerCase() == normalized) {
      return entry.key;
    }
  }
  if (normalized == 'suppressions') {
    return 'suppression_hygiene';
  }
  return sortKey.replaceAll(' ', '_');
}

String _analyzerTitleForKey(String analyzerKey) {
  return _analyzerTitleByKey[analyzerKey] ?? analyzerKey;
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
  print(AppStrings.setupIgnoresInDartFile);
  print(AppStrings.topOfFileDirectivesPosition);
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
  print(AppStrings.hardcodedStringsFlutterStyles);
  print(AppStrings.ignoreForFileHardcoded);

  print('--------------------------------------------');
  print(AppStrings.setupUsingFcheckFile);
  print(AppStrings.createFcheckInInput);
  print(AppStrings.supportedExample);
  print(AppStrings.exampleInput);
  print(AppStrings.exampleExclude);
  print(AppStrings.exampleExcludePattern);
  print('');
  print(AppStrings.exampleAnalyzers);
  print(AppStrings.exampleDefault);
  print(AppStrings.exampleDisabled);
  print(AppStrings.exampleHardcodedStrings);
  print(AppStrings.exampleOptions);
  print(AppStrings.exampleDuplicateCode);
  print(AppStrings.exampleSimilarityThreshold);
  print(AppStrings.exampleMinTokens);
  print(AppStrings.exampleMinNonEmptyLines);
  print('');
  print(AppStrings.availableAnalyzerNames);
  for (final analyzer in sortedAnalyzers) {
    print('      - ${analyzer.configName}');
  }
}

/// Prints scoring model guidance for compliance score calculation.
///
/// The formulas mirror `ProjectMetricsAnalyzer` so users can understand how
/// issue counts map to a 0-100 compliance score.
void printScoreSystemGuide() {
  final analyzers = List<AnalyzerDomain>.from(AnalyzerDomain.values);
  final analyzerCount = analyzers.length;
  final sharePerAnalyzer = analyzerCount == 0
      ? _percentageMultiplier.toDouble()
      : _percentageMultiplier / analyzerCount;

  print('--------------------------------------------');
  print(AppStrings.complianceScoreModel);
  print(AppStrings.onlyEnabledAnalyzersContribute);
  print('');
  print('${AppStrings.enabledAnalyzersCurrentModel}$analyzerCount):');
  for (final analyzer in analyzers) {
    print('  - ${analyzer.configName}');
  }
  print('');
  print(AppStrings.howIs100Distributed);
  print(AppStrings.nAsNumberOfEnabled);
  print(AppStrings.eachAnalyzerShare);
  print(
    AppStrings.currentAnalyzerCountLine(
      analyzerCount,
      _formatCompactDecimal(sharePerAnalyzer),
    ),
  );
  print('');
  print(AppStrings.perAnalyzerDomainScoreClamped);
  print(AppStrings.oneDomainCanOnlyConsumeShare);
  print('');
  print(AppStrings.domainFormulasUsed);
  print(AppStrings.formulaOneClassPerFile);
  print(AppStrings.formulaHardcodedStrings);
  print(AppStrings.formulaMagicNumbers);
  print(AppStrings.formulaSourceSorting);
  print(AppStrings.formulaLayers);
  print(AppStrings.formulaSecrets);
  print(AppStrings.formulaDeadCode);
  print(AppStrings.formulaDuplicateCode);
  print(AppStrings.impactLinesSum);
  print('');
  print(AppStrings.suppressionPenaltyBudget);
  print(AppStrings.formulaIgnoreBudget);
  print(AppStrings.formulaCustomExcludedBudget);
  print(AppStrings.formulaDisabledAnalyzersBudget);
  print(AppStrings.weightedOverusePrefix);
  print(AppStrings.weightedOveruseFormulaLine1);
  print(AppStrings.weightedOveruseFormulaLine2);
  print(AppStrings.suppressionPenaltyPointsPrefix);
  print(AppStrings.suppressionPenaltyPointsFormula);
  print(AppStrings.overXFormula);
  print('');
  print(AppStrings.finalScoreLabel);
  print(AppStrings.formulaAverage);
  print(AppStrings.formulaBaseScore);
  print(AppStrings.formulaComplianceScore);
  print(AppStrings.specialRulePrefix);
  print(AppStrings.specialRuleSuffix);
  print('');
  print(AppStrings.focusAreaAndInvestNextLabel);
  print(AppStrings.focusAreaExplanation);
  print(AppStrings.tieBreakerExplanation);
  print(AppStrings.investNextExplanation);
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
  print(AppStrings.missingDirectoryError(path));
}

/// Prints a configuration error for invalid `.fcheck` content.
void printConfigurationError(String message) {
  print(AppStrings.invalidFcheckConfigurationError(message));
}

/// Prints the run header before analysis starts.
///
/// Includes tool version and normalized input directory path.
void printRunHeader({
  required String version,
  required Directory directory,
}) {
  print(dividerLine('fCheck $version', downPointer: true));
  print(
      _labelValueLine(label: AppStrings.input, value: directory.absolute.path));
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
    AppStrings.excludedDartFilesHeader(
      formatCount(excludedDartFiles.length),
    ),
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
void printOutputFileLine({
  required String label,
  required String path,
}) {
  final normalizedPath = normalizeIssueLocation(path).path;
  print(
    _labelValueLine(
      label: label.trimRight(),
      value: _pathText(normalizedPath),
    ),
  );
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
  print(AppStrings.analysisErrorLine(error));
  print(stack);
}

/// Length of the header and footer lines
final int dividerLength = 37;
const int _halfTitleLengthDivisor = 2;

const int _ansiGreen = 32;
const int _ansiGreenBright = 92;
const int _ansiYellow = 33;
const int _ansiYellowBright = 93;
const int _ansiOrange = 33;
const int _ansiRed = 31;
const int _ansiRedBright = 91;
const int _ansiGray = 90;
const int _ansiWhiteBright = 97;
final RegExp _leadingStatusTagPattern = RegExp(
  r'^(\s*)(?:\x1B\[[0-9;]*m)?\[(?:✓|!|✗|-)\](?:\x1B\[[0-9;]*m)?\s*',
);

String _colorize(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[${colorCode}m$text\x1B[0m' : text;

String _colorizeBold(String text, int colorCode) =>
    supportsCliAnsiColors ? '\x1B[1;${colorCode}m$text\x1B[0m' : text;

/// Removes leading status markers (e.g. `[✓]`, `[!]`, `[✗]`, `[-]`).
String _withoutLeadingStatusTag(String line) {
  final match = _leadingStatusTagPattern.firstMatch(line);
  if (match == null) {
    return line;
  }
  final leadingWhitespace = match.group(1) ?? '';
  final rest = line.substring(match.end);
  return '$leadingWhitespace$rest';
}

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

  return _colorize('$directionChar$lineAndTitle$directionChar', _ansiGray);
}
