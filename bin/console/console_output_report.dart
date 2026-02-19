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
}

/// Appends the two-column dashboard section with project stats and counts.
void _appendDashboardSection(List<String> lines, _ReportContext ctx) {
  final localizationCell = _gridCell(
    label: AppStrings.localization,
    value: ctx.usesLocalization ? AppStrings.on : AppStrings.off,
  );

  lines.add(dividerLine(AppStrings.dashboardDivider));
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
    _gridCell(label: AppStrings.loc, value: formatCount(ctx.totalLinesOfCode)),
    _gridCell(
      label: AppStrings.comments,
      value: ctx.commentSummary,
      valuePreAligned: true,
    ),
  ];
  final rightDashboardRows = <String>[
    _gridCell(
      label: AppStrings.dependency,
      value: formatCount(ctx.dependencyCount),
    ),
    _gridCell(
      label: AppStrings.devDependency,
      value: formatCount(ctx.devDependencyCount),
    ),
    _gridCell(label: AppStrings.classes, value: formatCount(ctx.classCount)),
    _gridCell(label: AppStrings.methods, value: formatCount(ctx.methodCount)),
    _gridCell(
      label: AppStrings.functions,
      value: formatCount(ctx.functionCount),
    ),
    localizationCell,
  ];
  for (var index = 0; index < leftDashboardRows.length; index++) {
    final rightCell = index < rightDashboardRows.length
        ? rightDashboardRows[index]
        : ''.padRight(
            _gridLabelWidth + _gridValueWidth + _emptyRightDashboardCellPadding,
          );
    lines.add(_gridRow([leftDashboardRows[index], rightCell]));
  }
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
