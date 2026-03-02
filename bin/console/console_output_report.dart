part of 'console_output.dart';

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
  int listItemLimit = defaultListItemLimit,
}) {
  final ctx = _ReportContext.fromMetrics(
    metrics,
    listMode: listMode,
    listItemLimit: listItemLimit,
  );
  final lines = <String>[];

  _appendProjectHeader(lines, ctx);
  _appendDashboardSection(lines, ctx);
  _appendLiteralsSection(lines, ctx);

  lines.add(dividerLine('Analyzers'));
  final listBlocks = <_ListBlock>[];
  _populateAnalyzerBlocks(ctx, listBlocks);
  _appendOrderedAnalyzerBlocks(lines, listBlocks, ctx);

  lines.add('');
  _appendScorecardSection(lines, ctx);
  return lines;
}

/// Appends the first line describing project type, name, and version.
void _appendProjectHeader(List<String> lines, _ReportContext ctx) {
  lines.add(
    _labelValueLine(
      label: '${ctx.projectType.label} ${AppStrings.project}',
      value: '${ctx.projectName} (${AppStrings.version} ${ctx.version})',
    ),
  );
  lines.add(
    _labelValueLine(
      label: AppStrings.platforms,
      value: _platformsSupportSummary(ctx),
    ),
  );
}

/// Builds ordered platform support badges for header display.
///
/// Order is fixed to keep output stable: Android, iOS, MacOS, Windows,
/// Linux, Web.
String _platformsSupportSummary(_ReportContext ctx) {
  final entries = [
    (supported: ctx.supportsAndroid, label: AppStrings.android),
    (supported: ctx.supportsIos, label: AppStrings.ios),
    (supported: ctx.supportsMacos, label: AppStrings.macos),
    (supported: ctx.supportsWindows, label: AppStrings.windows),
    (supported: ctx.supportsLinux, label: AppStrings.linux),
    (supported: ctx.supportsWeb, label: AppStrings.web),
  ];
  final buffer = StringBuffer();
  for (var index = 0; index < entries.length; index++) {
    buffer.write(_platformSupportTag(entries[index]));
    if (index == entries.length - 1) {
      continue;
    }
    final current = entries[index].label;
    final next = entries[index + 1].label;
    final isLinuxToWeb = current == AppStrings.linux && next == AppStrings.web;
    buffer.write(isLinuxToWeb ? '  ' : ' ');
  }
  return buffer.toString();
}

String _platformSupportTag(({bool supported, String label}) entry) {
  final marker = entry.supported ? '✓' : '-';
  final tagText = '[$marker${entry.label}]';
  return entry.supported
      ? _colorize(tagText, _ansiGreen)
      : _colorize(tagText, _ansiGray);
}

/// Appends the two-column dashboard section with project stats and counts.
void _appendDashboardSection(List<String> lines, _ReportContext ctx) {
  lines.add(dividerLine(AppStrings.dashboardDivider));
  lines.add(
    _gridRow([
      _gridCell(
        label: AppStrings.dependency,
        value: formatCount(ctx.dependencyCount),
      ),
      _gridCell(
        label: AppStrings.devDependency,
        value: formatCount(ctx.devDependencyCount),
      ),
    ]),
  );
  final leftDashboardRows = <String>[
    _gridCell(label: AppStrings.folders, value: formatCount(ctx.totalFolders)),
    _gridCell(label: AppStrings.files, value: formatCount(ctx.totalFiles)),
    _gridCell(
      label: AppStrings.excludedFiles,
      value: formatCount(ctx.excludedFilesCount),
    ),
    _gridCell(
      label: AppStrings.dartFiles,
      value: formatCount(ctx.totalDartFiles),
    ),
    _gridCell(
      label: AppStrings.testDartFiles,
      value: _dashboardCountOrDash(ctx.testDartFilesCount),
      valuePreAligned: true,
    ),
    _gridCell(
      label: AppStrings.testCases,
      value: _dashboardCountOrDash(ctx.testCaseCount),
      valuePreAligned: true,
    ),
  ];
  final rightDashboardRows = <String>[
    _gridCell(label: AppStrings.classes, value: formatCount(ctx.classCount)),
    _gridCell(
      label: AppStrings.statefulWidgets,
      value: _dashboardCountOrDash(ctx.statefulWidgetCount),
      valuePreAligned: true,
    ),
    _gridCell(
      label: AppStrings.statelessWidgets,
      value: _dashboardCountOrDash(ctx.statelessWidgetCount),
      valuePreAligned: true,
    ),
    _gridCell(label: AppStrings.methods, value: formatCount(ctx.methodCount)),
    _gridCell(
      label: AppStrings.functions,
      value: formatCount(ctx.functionCount),
    ),
    _gridCell(label: AppStrings.loc, value: formatCount(ctx.totalLinesOfCode)),
    _gridCell(
      label: AppStrings.comments,
      value: ctx.commentSummary,
      valuePreAligned: true,
    ),
  ];
  final dashboardRowCount =
      leftDashboardRows.length >= rightDashboardRows.length
      ? leftDashboardRows.length
      : rightDashboardRows.length;
  for (var index = 0; index < dashboardRowCount; index++) {
    final leftCell = index < leftDashboardRows.length
        ? leftDashboardRows[index]
        : ''.padRight(
            _gridLabelWidth + _gridValueWidth + _emptyRightDashboardCellPadding,
          );
    final rightCell = index < rightDashboardRows.length
        ? rightDashboardRows[index]
        : ''.padRight(
            _gridLabelWidth + _gridValueWidth + _emptyRightDashboardCellPadding,
          );
    lines.add(_gridRow([leftCell, rightCell]));
  }
}

/// Appends a compact literals inventory block.
void _appendLiteralsSection(List<String> lines, _ReportContext ctx) {
  final literalCounts = [
    formatCount(ctx.totalStringLiteralCount),
    formatCount(ctx.totalNumberLiteralCount),
  ];
  var literalCountWidth = 0;
  for (final count in literalCounts) {
    if (count.length > literalCountWidth) {
      literalCountWidth = count.length;
    }
  }

  lines.add(dividerLine(AppStrings.literalsDivider));
  lines.add(
    _labelValueLine(
      label: AppStrings.localization,
      value: ctx.usesLocalization ? AppStrings.on : AppStrings.off,
    ),
  );
  lines.add(
    _labelValueLine(
      label: AppStrings.strings,
      value: _literalInventorySummary(
        totalCount: ctx.totalStringLiteralCount,
        duplicatedCount: ctx.duplicatedStringLiteralCount,
        hardcodedCount: ctx.hardcodedStringIssues.length,
        countWidth: literalCountWidth,
      ),
    ),
  );
  lines.add(
    _labelValueLine(
      label: AppStrings.numbers,
      value: _literalInventorySummary(
        totalCount: ctx.totalNumberLiteralCount,
        duplicatedCount: ctx.duplicatedNumberLiteralCount,
        hardcodedCount: ctx.magicNumberIssues.length,
        countWidth: literalCountWidth,
      ),
    ),
  );
}

/// Appends the final scorecard section with score, focus area, and next step.
void _appendScorecardSection(List<String> lines, _ReportContext ctx) {
  lines.add(dividerLine(AppStrings.scorecardDivider));
  lines.add(
    _labelValueLine(
      label: 'Total Score',
      value: _scoreValue(ctx.complianceScore),
    ),
  );
  if (ctx.suppressionPenaltyPoints > 0) {
    lines.add(
      _labelValueLine(
        label: AppStrings.suppressions,
        value: _suppressionPenaltyValue(
          penaltyPoints: ctx.suppressionPenaltyPoints,
        ),
      ),
    );
  }
  if (ctx.complianceFocusAreaLabel == 'None') {
    lines.add(
      _labelValueLine(
        label: AppStrings.investNext,
        value: ctx.complianceNextInvestment,
      ),
    );
    return;
  }
  lines.add(
    _labelValueLine(
      label: AppStrings.focusArea,
      value:
          '${ctx.complianceFocusAreaLabel} (${formatCount(ctx.complianceFocusAreaIssueCount)} ${AppStrings.issues})',
    ),
  );
  lines.add(
    _labelValueLine(
      label: AppStrings.investNext,
      value: ctx.complianceNextInvestment,
    ),
  );
}
