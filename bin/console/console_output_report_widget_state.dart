part of 'console_output.dart';

/// Adds the widget state analyzer block; without a widget `State` to
/// check, a passive one, as the area is left out of the score.
void _addWidgetStateBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (ctx.widgetStateAnalyzerEnabled && ctx.widgetStateCount == 0) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'widget_state',
      blockLines: [''],
    );
    return;
  }
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.widgetStateAnalyzerEnabled,
    sortKey: 'widget_state',
    skippedLine:
        '${skipTag()} ${AppStrings.widgetStateCheck} skipped (${AppStrings.disabled}).',
    passedLine:
        '${okTag()} ${AppStrings.widgetStateCheck} ${AppStrings.checkPassed}',
    issues: ctx.widgetStateIssues,
    summaryLine:
        '${warnTag()} ${formatCount(ctx.widgetStateIssues.length)} ${AppStrings.widgetStateIssuesDetected}',
  );
}
