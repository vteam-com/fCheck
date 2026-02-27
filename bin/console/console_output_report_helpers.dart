part of 'console_output.dart';

const int _percentageMultiplier = 100;
const int _gridLabelWidth = 18;
const int _gridValueWidth = 15;
const int _perfectScoreThreshold = 95;
const int _goodScoreThreshold = 85;
const int _fairScoreThreshold = 70;
const int _minHealthyCommentRatioPercent = 10;
const int _compactDecimalPlaces = 2;
const int _percentMultiplier = 100;
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
  'code_size': 'Code size',
  'one_class_per_file': 'One class per file',
  'hardcoded_strings': 'Hardcoded strings',
  'magic_numbers': 'Magic numbers',
  'source_sorting': 'Source sorting',
  'layers': 'Layers architecture',
  'secrets': 'Secrets',
  'dead_code': 'Dead code',
  'duplicate_code': 'Duplicate code',
  'documentation': 'Documentation',
  'suppression_hygiene': 'Checks bypassed',
};

/// Returns all issues or a limited preview depending on the selected list mode.
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

/// Returns unique normalized issue paths while preserving first-seen order.
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

/// Returns the maximum string width needed to display the provided integers.
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

/// Formats a single dashboard cell with aligned label and value columns.
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

/// Formats and colorizes the overall compliance score percentage.
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

/// Returns the status badge token for an analyzer summary header.
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

/// Builds an analyzer header line with title, status, and deduction.
String _analyzerSectionHeader({
  required String title,
  required bool enabled,
  required int issueCount,
  required double deductionPercent,
}) {
  final titleColor = enabled ? _ansiWhiteBright : _ansiGray;
  final headerTitle = _colorizeBold(
    title.padRight(_analyzerHeaderTitleWidth),
    titleColor,
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

/// Formats the deduction suffix shown in analyzer section headers.
String _analyzerDeductionValue({
  required bool enabled,
  required int issueCount,
  required double deductionPercent,
}) {
  if (!enabled || issueCount == 0) {
    return '';
  }
  final normalizedDeduction = deductionPercent
      .clamp(0, _percentageMultiplier)
      .toDouble();
  final deductionText = '-${_formatCompactDecimal(normalizedDeduction)}%';
  final issueText = formatCount(issueCount);
  return _colorize('$deductionText ($issueText)', _ansiYellow);
}

/// Formats the comment summary as percent and absolute line count.
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

/// Formats literal inventory count and duplicate ratio.
///
/// Example: `3 Strings (66% dupe)` when duplicated values exist.
/// Example: `3 Strings` when there are no duplicates.
String _literalInventorySummary({
  required int totalCount,
  required int duplicatedCount,
  required int hardcodedCount,
  int countWidth = 0,
}) {
  final rawTotalText = formatCount(totalCount);
  final totalText = countWidth > 0
      ? rawTotalText.padLeft(countWidth)
      : rawTotalText;
  final hardcodedLabel =
      '(${formatCount(hardcodedCount)} ${AppStrings.hardcodedSuffix})';
  final hardcodedText = hardcodedCount == 0
      ? _colorize(hardcodedLabel, _ansiGray)
      : _colorize(hardcodedLabel, _ansiOrange);

  if (duplicatedCount <= 0 || totalCount <= 0) {
    return '$totalText, $hardcodedText';
  }

  final duplicatePercent = ((duplicatedCount / totalCount) * _percentMultiplier)
      .floor();
  return '$totalText (${formatCount(duplicatePercent)}% ${AppStrings.dupeSuffix}), $hardcodedText';
}

/// Formats suppression penalty points with severity-based color emphasis.
String _suppressionPenaltyValue({required int penaltyPoints, int width = 0}) {
  final rawText = penaltyPoints == 0
      ? '0 pts'
      : '-${formatCount(penaltyPoints)} pts';
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

/// Formats suppression-related counts with zero/non-zero color treatment.
String _suppressionCountValue({required int count, int width = 0}) {
  final rawText = formatCount(count);
  final text = width <= 0 ? rawText : rawText.padLeft(width);
  if (count == 0) {
    return _colorize(text, _ansiGreen);
  }
  return _colorize(text, _ansiOrange);
}

/// Formats decimals compactly by trimming trailing zeros and separators.
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

/// Adds a prepared analyzer list block with derived analyzer metadata.
void _addListBlock(
  List<_ListBlock> listBlocks, {
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

/// Maps a user-facing sort label to its canonical analyzer key.
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
