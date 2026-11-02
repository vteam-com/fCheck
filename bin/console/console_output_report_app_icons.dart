part of 'console_output.dart';

/// Adds the app icons block: a passed line, or the problems found with
/// each platform's icons (just the files in filenames-only mode).
void _addAppIconIssuesBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (ctx.appIconIssues.isEmpty) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: 'App icons',
      blockLines: ['${okTag()} App icons check ${AppStrings.checkPassed}'],
    );
    return;
  }

  final blockLines = <String>[
    '${warnTag()} ${formatCount(ctx.appIconIssues.length)} app icon issues',
  ];
  if (ctx.filenamesOnly) {
    final paths =
        ctx.appIconIssues
            .map((issue) => issue.filePath as String)
            .toSet()
            .toList()
          ..sort();
    for (final path in paths) {
      blockLines.add('  - ${_colorize(path, _ansiBlueBright)}');
    }
  } else {
    for (final issue in ctx.appIconIssues) {
      blockLines.add(
        '  • ${issue.platform.label}: '
        '${_colorize(issue.filePath as String, _ansiBlueBright)} '
        '${_colorize(issue.message as String, _ansiGray)}',
      );
    }
  }

  _addListBlock(
    listBlocks,
    status: _ListBlockStatus.warning,
    sortKey: 'App icons',
    blockLines: blockLines,
  );
}
