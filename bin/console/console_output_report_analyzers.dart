part of 'console_output.dart';

/// Builds analyzer-specific blocks in report display order.
void _populateAnalyzerBlocks(_ReportContext ctx, List<_ListBlock> listBlocks) {
  _addCodeSizeBlock(ctx, listBlocks);
  _addSuppressionsBlock(ctx, listBlocks);
  _addOneClassPerFileBlock(ctx, listBlocks);
  _addHardcodedStringsBlock(ctx, listBlocks);
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.magicNumbersAnalyzerEnabled,
    sortKey: 'magic numbers',
    skippedLine:
        '${skipTag()} Magic numbers check skipped (${AppStrings.disabled}).',
    passedLine: '${okTag()} Magic numbers check ${AppStrings.checkPassed}',
    issues: ctx.magicNumberIssues,
    summaryLine:
        '${warnTag()} ${formatCount(ctx.magicNumberIssues.length)} ${AppStrings.magicNumbersDetected}',
    status: _ListBlockStatus.warning,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => issue.format() as String,
    moreConnector: AppStrings.and,
  );
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.sourceSortingAnalyzerEnabled,
    sortKey: 'source sorting',
    skippedLine:
        '${skipTag()} Flutter class member sorting skipped (${AppStrings.disabled}).',
    passedLine:
        '${okTag()} Flutter class member sorting ${AppStrings.checkPassed}',
    issues: ctx.sourceSortIssues,
    summaryLine:
        '${warnTag()} ${formatCount(ctx.sourceSortIssues.length)} ${AppStrings.unsortedMembers}',
    status: _ListBlockStatus.warning,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => issue.format() as String,
    moreConnector: AppStrings.and,
  );
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.secretsAnalyzerEnabled,
    sortKey: 'secrets',
    skippedLine:
        '${skipTag()} ${AppStrings.secretsScan} skipped (${AppStrings.disabled}).',
    passedLine:
        '${okTag()} ${AppStrings.secretsScan} ${AppStrings.checkPassed}',
    issues: ctx.secretIssues,
    summaryLine:
        '${warnTag()} ${formatCount(ctx.secretIssues.length)} ${AppStrings.potentialSecretsDetected}',
    status: _ListBlockStatus.warning,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => issue.format() as String,
    moreConnector: AppStrings.and,
  );
  _addDeadCodeBlock(ctx, listBlocks);
  _addDuplicateCodeBlock(ctx, listBlocks);
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.documentationAnalyzerEnabled,
    sortKey: 'documentation',
    skippedLine:
        '${skipTag()} ${AppStrings.documentationCheck} skipped (${AppStrings.disabled}).',
    passedLine:
        '${okTag()} ${AppStrings.documentationCheck} ${AppStrings.checkPassed}',
    issues: ctx.documentationIssues,
    summaryLine:
        '${warnTag()} ${formatCount(ctx.documentationIssues.length)} ${AppStrings.documentationIssuesDetected}',
    status: _ListBlockStatus.warning,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => issue.format() as String,
    moreConnector: AppStrings.and,
  );
  _addLayersBlock(ctx, listBlocks);
}

/// Sorts and appends analyzer blocks using score and status ordering rules.
void _appendOrderedAnalyzerBlocks(
  List<String> lines,
  List<_ListBlock> listBlocks,
  _ReportContext ctx,
) {
  final orderedBlocks = List<_ListBlock>.from(listBlocks)
    ..sort((left, right) {
      final leftEnabled = ctx.analyzerEnabledByKey[left.analyzerKey] ?? false;
      final rightEnabled = ctx.analyzerEnabledByKey[right.analyzerKey] ?? false;
      final leftScore = ctx.analyzerScoresByKey[left.analyzerKey] ?? 0;
      final rightScore = ctx.analyzerScoresByKey[right.analyzerKey] ?? 0;
      final leftIssueCount =
          ctx.analyzerIssueCountsByKey[left.analyzerKey] ?? 0;
      final rightIssueCount =
          ctx.analyzerIssueCountsByKey[right.analyzerKey] ?? 0;
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
    final analyzerScore = ctx.analyzerScoresByKey[block.analyzerKey] ?? 0;
    final analyzerIssueCount =
        ctx.analyzerIssueCountsByKey[block.analyzerKey] ?? 0;
    final analyzerEnabled =
        ctx.analyzerEnabledByKey[block.analyzerKey] ?? false;
    final analyzerDeductionPercent =
        ctx.analyzerDeductionPercentByKey[block.analyzerKey] ?? 0;
    final hidePassedSummaryLine =
        analyzerEnabled &&
        analyzerScore == _percentageMultiplier &&
        analyzerIssueCount == 0;
    lines.add(
      _analyzerSectionHeader(
        title: block.analyzerTitle,
        enabled: analyzerEnabled,
        issueCount: analyzerIssueCount,
        deductionPercent: analyzerDeductionPercent,
      ),
    );
    if (!hidePassedSummaryLine) {
      lines.add(_withoutLeadingStatusTag(block.lines.first).trimLeft());
    }
    if (ctx.listMode != ReportListMode.none) {
      for (final blockLine in block.lines.skip(1)) {
        if (blockLine.trim().isEmpty) {
          continue;
        }
        lines.add(_withoutLeadingStatusTag(blockLine));
      }
    }
    final printedWarningDetails =
        analyzerIssueCount > 0 && ctx.listMode != ReportListMode.none;
    if (printedWarningDetails && index < orderedBlocks.length - 1) {
      lines.add('');
    }
  }
}

/// Adds the code-size analyzer block with grouped threshold violations.
void _addCodeSizeBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  final codeSizeIssueCount = ctx.analyzerIssueCountsByKey['code_size'] ?? 0;
  if (!ctx.codeSizeAnalyzerEnabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'code size',
      blockLines: [
        '${skipTag()} Code size check skipped (${AppStrings.disabled}).',
      ],
    );
    return;
  }

  final codeSizeStatus = codeSizeIssueCount == 0
      ? _ListBlockStatus.success
      : _ListBlockStatus.warning;
  final codeSizeBlockLines = <String>[
    if (codeSizeIssueCount == 0)
      '${okTag()} Code size is within configured LOC thresholds.'
    else
      '${warnTag()} ${formatCount(codeSizeIssueCount)} source code entries exceed configured LOC thresholds.',
  ];
  if (codeSizeIssueCount > 0) {
    for (final section in ctx.codeSizeSections) {
      final violating = section.artifacts
          .where((artifact) => artifact.linesOfCode > section.threshold)
          .toList(growable: false);
      if (violating.isEmpty) {
        continue;
      }
      codeSizeBlockLines.add(
        '  - ${formatCount(violating.length)} ${section.title} > ${formatCount(section.threshold)}',
      );
      if (ctx.listMode == ReportListMode.none) {
        continue;
      }
      final visibleViolating = _issuesForMode(
        violating,
        ctx.listMode,
        ctx.effectiveListItemLimit,
      ).toList(growable: false);
      for (final artifact in visibleViolating) {
        final path = normalizeIssueLocation(artifact.filePath).path;
        final range = '${artifact.startLine}';
        final detailedLabel = artifact.kind == CodeSizeArtifactKind.file
            ? '${_pathText(path)} ${_colorize("(${formatCount(artifact.linesOfCode)} LOC)", _ansiYellow)}'
            : artifact.kind == CodeSizeArtifactKind.classDeclaration
            ? '${_pathText(path)}:$range ${_colorizeWithCode(artifact.qualifiedName, _ansiOrangeCode)} ${_colorize("(${formatCount(artifact.linesOfCode)} LOC)", _ansiYellow)}'
            : '${_pathText(path)}:$range ${_colorizeWithCode(artifact.qualifiedName, _ansiOrangeCode)} ${_colorize("(${formatCount(artifact.linesOfCode)} LOC)", _ansiYellow)}';
        final line = ctx.listMode == ReportListMode.filenames
            ? '    - ${_pathText(path)}'
            : '    - $detailedLabel';
        codeSizeBlockLines.add(line);
      }
      if (ctx.listMode == ReportListMode.partial &&
          violating.length > ctx.effectiveListItemLimit) {
        codeSizeBlockLines.add(
          '    ... ${AppStrings.and} ${formatCount(violating.length - ctx.effectiveListItemLimit)} ${AppStrings.more}',
        );
      }
    }
  }
  codeSizeBlockLines.add('');
  _addListBlock(
    listBlocks,
    status: codeSizeStatus,
    sortKey: 'code size',
    blockLines: codeSizeBlockLines,
  );
}

/// Adds the suppression-hygiene analyzer block and penalty details.
void _addSuppressionsBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (ctx.ignoreDirectivesCount == 0 &&
      ctx.customExcludedFilesCount == 0 &&
      ctx.disabledAnalyzersCount == 0) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: 'suppressions',
      blockLines: ['${okTag()} Suppressions check ${AppStrings.checkPassed}'],
    );
    return;
  }

  final suppressionTag = ctx.suppressionPenaltyPoints > 0
      ? failTag()
      : warnTag();
  final suffix = ctx.suppressionPenaltyPoints > 0
      ? '(score deduction applied: ${_suppressionPenaltyValue(penaltyPoints: ctx.suppressionPenaltyPoints)})'
      : '(within budget, no score deduction)';
  final blockLines = <String>[
    '$suppressionTag ${AppStrings.suppressionsSummary} $suffix:',
  ];
  if (ctx.ignoreDirectivesCount > 0) {
    final fileLabel = ctx.ignoreDirectiveFileCount == 1
        ? AppStrings.file
        : AppStrings.filesSmall;
    blockLines.add(
      '  - Ignore directives: ${_suppressionCountValue(count: ctx.ignoreDirectivesCount)} ${AppStrings.ignoreDirectivesAcross} ${_suppressionCountValue(count: ctx.ignoreDirectiveFileCount)} $fileLabel',
    );
    if (ctx.ignoreDirectiveEntries.isNotEmpty) {
      final visibleIgnoreDirectiveEntries = _issuesForMode(
        ctx.ignoreDirectiveEntries,
        ctx.listMode,
        ctx.effectiveListItemLimit,
      ).toList();
      for (final entry in visibleIgnoreDirectiveEntries) {
        if (ctx.filenamesOnly) {
          blockLines.add('    - ${_pathText(entry.key)}');
          continue;
        }
        blockLines.add(
          '    - ${_pathText(entry.key)} (${_suppressionCountValue(count: entry.value)})',
        );
      }
      if (ctx.listMode == ReportListMode.partial &&
          ctx.ignoreDirectiveEntries.length > ctx.effectiveListItemLimit) {
        blockLines.add(
          '    ... ${AppStrings.and} ${formatCount(ctx.ignoreDirectiveEntries.length - ctx.effectiveListItemLimit)} ${AppStrings.more}',
        );
      }
    }
  } else {
    blockLines.add(
      '  - Ignore directives: ${_suppressionCountValue(count: ctx.ignoreDirectivesCount)}',
    );
  }
  if (ctx.customExcludedFilesCount > 0) {
    final customExcludeFileLabel = ctx.customExcludedFilesCount == 1
        ? AppStrings.dartFileExcluded
        : AppStrings.dartFilesExcluded;
    blockLines.add(
      '  - ${AppStrings.customExcludes}: ${_suppressionCountValue(count: ctx.customExcludedFilesCount)} $customExcludeFileLabel (file count; from .fcheck input.exclude or --exclude)',
    );
  }
  if (ctx.disabledAnalyzersCount > 0) {
    final analyzerLabel = ctx.disabledAnalyzersCount == 1
        ? AppStrings.analyzerSmall
        : AppStrings.analyzersSmall;
    blockLines.add(
      '  ${skipTag()} ${AppStrings.disabledRules}: ${_suppressionCountValue(count: ctx.disabledAnalyzersCount)} $analyzerLabel:',
    );
    for (final analyzerKey in ctx.disabledAnalyzerKeys) {
      blockLines.add('    ${skipTag()} $analyzerKey');
    }
  }
  blockLines.add('');
  _addListBlock(
    listBlocks,
    status: ctx.suppressionPenaltyPoints > 0
        ? _ListBlockStatus.failure
        : _ListBlockStatus.warning,
    sortKey: 'suppressions',
    blockLines: blockLines,
  );
}

/// Adds one-class-per-file analyzer output for compliant/non-compliant files.
void _addOneClassPerFileBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (!ctx.oneClassPerFileAnalyzerEnabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'one class per file',
      blockLines: [
        '${skipTag()} One class per file check skipped (${AppStrings.disabled}).',
      ],
    );
    return;
  }
  if (ctx.nonCompliant.isEmpty) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: 'one class per file',
      blockLines: [
        '${okTag()} One class per file check ${AppStrings.checkPassed}',
      ],
    );
    return;
  }
  final blockLines = <String>[
    '${failTag()} ${formatCount(ctx.nonCompliant.length)} ${AppStrings.oneClassPerFileViolate}',
  ];
  if (ctx.filenamesOnly) {
    final filePaths = _uniqueFilePaths(ctx.nonCompliant.map((m) => m?.path));
    for (final path in filePaths) {
      blockLines.add('  - ${_pathText(path)}');
    }
  } else {
    final visibleNonCompliant = _issuesForMode(
      ctx.nonCompliant,
      ctx.listMode,
      ctx.effectiveListItemLimit,
    ).toList();
    final classCountWidth = _maxIntWidth(
      visibleNonCompliant.map((metric) => metric?.classCount ?? 0),
    );
    for (final metric in visibleNonCompliant) {
      final classCountText = (metric?.classCount ?? 0).toString().padLeft(
        classCountWidth,
      );
      final normalizedPath = normalizeIssueLocation(
        metric?.path ?? AppStrings.unknownLocation,
      ).path;
      blockLines.add(
        '  - ${_pathText(normalizedPath)} ($classCountText classes found)',
      );
    }
    if (ctx.listMode == ReportListMode.partial &&
        ctx.nonCompliant.length > ctx.effectiveListItemLimit) {
      blockLines.add(
        '  ... ${AppStrings.and} ${formatCount(ctx.nonCompliant.length - ctx.effectiveListItemLimit)} ${AppStrings.more}',
      );
    }
  }
  blockLines.add('');
  _addListBlock(
    listBlocks,
    status: _ListBlockStatus.failure,
    sortKey: 'one class per file',
    blockLines: blockLines,
  );
}

/// Adds hardcoded-strings analyzer output with localization-aware severity.
void _addHardcodedStringsBlock(
  _ReportContext ctx,
  List<_ListBlock> listBlocks,
) {
  if (!ctx.hardcodedStringsAnalyzerEnabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'hardcoded strings',
      blockLines: [
        '${skipTag()} Hardcoded strings check skipped (${AppStrings.disabled}).',
      ],
    );
    return;
  }
  if (!ctx.usesLocalization) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'hardcoded strings',
      blockLines: [
        '${skipTag()} ${formatCount(ctx.hardcodedStringIssues.length)} ${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.off}).',
      ],
    );
    return;
  }

  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: true,
    sortKey: 'hardcoded strings',
    skippedLine:
        '${skipTag()} Hardcoded strings check skipped (${AppStrings.disabled}).',
    passedLine: '${okTag()} Hardcoded strings check ${AppStrings.checkPassed}',
    issues: ctx.hardcodedStringIssues,
    summaryLine:
        '${failTag()} ${formatCount(ctx.hardcodedStringIssues.length)} ${AppStrings.hardcodedStringsDetected} (localization ${AppStrings.enabled}):',
    status: _ListBlockStatus.failure,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => issue.format() as String,
    moreConnector: AppStrings.and,
  );
}

/// Adds dead-code analyzer output grouped by dead symbol category.
void _addDeadCodeBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (!ctx.deadCodeAnalyzerEnabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'dead code',
      blockLines: [
        '${skipTag()} ${AppStrings.deadCodeCheck} skipped (${AppStrings.disabled}).',
      ],
    );
    return;
  }
  if (ctx.deadCodeIssues.isEmpty) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: 'dead code',
      blockLines: [
        '${okTag()} ${AppStrings.deadCodeCheck} ${AppStrings.checkPassed}',
      ],
    );
    return;
  }
  final blockLines = <String>[
    '${warnTag()} ${formatCount(ctx.deadCodeIssues.length)} ${AppStrings.deadCodeIssuesDetected}',
  ];
  _appendDeadCodeCategory(
    ctx,
    blockLines,
    label: AppStrings.deadFiles,
    issues: ctx.deadFileIssues,
  );
  _appendDeadCodeCategory(
    ctx,
    blockLines,
    label: AppStrings.deadClasses,
    issues: ctx.deadClassIssues,
  );
  _appendDeadCodeCategory(
    ctx,
    blockLines,
    label: AppStrings.deadFunctions,
    issues: ctx.deadFunctionIssues,
  );
  _appendDeadCodeCategory(
    ctx,
    blockLines,
    label: AppStrings.unusedVariables,
    issues: ctx.unusedVariableIssues,
  );
  blockLines.add('');
  _addListBlock(
    listBlocks,
    status: _ListBlockStatus.warning,
    sortKey: 'dead code',
    blockLines: blockLines,
  );
}

/// Appends one dead-code issue category and its visible issue entries.
void _appendDeadCodeCategory(
  _ReportContext ctx,
  List<String> blockLines, {
  required String label,
  required List issues,
}) {
  if (issues.isEmpty) {
    return;
  }
  final issuePaths = ctx.filenamesOnly
      ? _uniqueFilePaths(issues.map((i) => i.filePath))
      : const <String>[];
  final issueCount = ctx.filenamesOnly ? issuePaths.length : issues.length;
  blockLines.add('  $label (${formatCount(issueCount)}):');
  if (ctx.filenamesOnly) {
    for (final path in issuePaths) {
      blockLines.add('    - ${_pathText(path)}');
    }
    return;
  }
  final visibleIssues = _issuesForMode(
    issues,
    ctx.listMode,
    ctx.effectiveListItemLimit,
  ).toList();
  for (final issue in visibleIssues) {
    blockLines.add('    - ${issue.formatGrouped()}');
  }
  if (ctx.listMode == ReportListMode.partial &&
      issues.length > ctx.effectiveListItemLimit) {
    blockLines.add(
      '    ... and ${formatCount(issues.length - ctx.effectiveListItemLimit)} more',
    );
  }
}

/// Adds duplicate-code analyzer output with similarity and line statistics.
void _addDuplicateCodeBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  if (!ctx.duplicateCodeAnalyzerEnabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: 'duplicate code',
      blockLines: [
        '${skipTag()} ${AppStrings.duplicateCodeCheck} skipped (${AppStrings.disabled}).',
      ],
    );
    return;
  }
  if (ctx.duplicateCodeIssues.isEmpty) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: 'duplicate code',
      blockLines: [
        '${okTag()} ${AppStrings.duplicateCodeCheck} ${AppStrings.checkPassed}',
      ],
    );
    return;
  }
  final blockLines = <String>[
    '${warnTag()} ${formatCount(ctx.duplicateCodeIssues.length)} ${AppStrings.duplicateBlocksDetected}',
  ];
  if (ctx.filenamesOnly) {
    final filePaths = _uniqueFilePaths(
      ctx.duplicateCodeIssues.expand(
        (issue) => [issue.firstFilePath, issue.secondFilePath],
      ),
    );
    for (final path in filePaths) {
      blockLines.add('  - ${_pathText(path)}');
    }
  } else {
    final visibleDuplicateCodeIssues = _issuesForMode(
      ctx.duplicateCodeIssues,
      ctx.listMode,
      ctx.effectiveListItemLimit,
    ).toList();
    final duplicateSimilarityWidth = _maxIntWidth(
      visibleDuplicateCodeIssues.map(
        (issue) => issue.similarityPercentRoundedDown,
      ),
    );
    final duplicateLineCountWidth = _maxIntWidth(
      visibleDuplicateCodeIssues.map((issue) => issue.lineCount),
    );
    for (final issue in visibleDuplicateCodeIssues) {
      blockLines.add(
        '  - ${issue.format(similarityPercentWidth: duplicateSimilarityWidth, lineCountWidth: duplicateLineCountWidth)}',
      );
    }
    if (ctx.listMode == ReportListMode.partial &&
        ctx.duplicateCodeIssues.length > ctx.effectiveListItemLimit) {
      blockLines.add(
        '  ... and ${formatCount(ctx.duplicateCodeIssues.length - ctx.effectiveListItemLimit)} more',
      );
    }
  }
  blockLines.add('');
  _addListBlock(
    listBlocks,
    status: _ListBlockStatus.warning,
    sortKey: 'duplicate code',
    blockLines: blockLines,
  );
}

/// Adds layers analyzer output and escalates violations as failures.
void _addLayersBlock(_ReportContext ctx, List<_ListBlock> listBlocks) {
  _addIssueListAnalyzerBlock(
    ctx,
    listBlocks,
    enabled: ctx.layersAnalyzerEnabled,
    sortKey: 'layers architecture',
    skippedLine:
        '${skipTag()} ${AppStrings.layersCheck} skipped (${AppStrings.disabled}).',
    passedLine:
        '${okTag()} ${AppStrings.layersCheck} ${AppStrings.checkPassed}',
    issues: ctx.layersIssues,
    summaryLine:
        '${failTag()} ${formatCount(ctx.layersIssues.length)} ${AppStrings.layersViolationsDetected}',
    status: _ListBlockStatus.failure,
    filePathExtractor: (issue) => issue.filePath as String?,
    detailFormatter: (issue) => '$issue',
    moreConnector: AppStrings.and,
    appendTrailingBlankLine: false,
  );
}

/// Adds a generic analyzer block for issue-list based analyzers.
void _addIssueListAnalyzerBlock(
  _ReportContext ctx,
  List<_ListBlock> listBlocks, {
  required bool enabled,
  required String sortKey,
  required String skippedLine,
  required String passedLine,
  required List issues,
  required String summaryLine,
  required _ListBlockStatus status,
  required String? Function(dynamic) filePathExtractor,
  required String Function(dynamic) detailFormatter,
  required String moreConnector,
  bool appendTrailingBlankLine = true,
}) {
  if (!enabled) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.disabled,
      sortKey: sortKey,
      blockLines: [skippedLine],
    );
    return;
  }
  if (issues.isEmpty) {
    _addListBlock(
      listBlocks,
      status: _ListBlockStatus.success,
      sortKey: sortKey,
      blockLines: [passedLine],
    );
    return;
  }

  final blockLines = <String>[summaryLine];
  if (ctx.filenamesOnly) {
    final filePaths = _uniqueFilePaths(
      issues.map(filePathExtractor).whereType<String>(),
    );
    for (final path in filePaths) {
      blockLines.add('  - ${_pathText(path)}');
    }
  } else {
    final visibleIssues = _issuesForMode(
      issues,
      ctx.listMode,
      ctx.effectiveListItemLimit,
    ).toList();
    for (final issue in visibleIssues) {
      blockLines.add('  - ${detailFormatter(issue)}');
    }
    if (ctx.listMode == ReportListMode.partial &&
        issues.length > ctx.effectiveListItemLimit) {
      blockLines.add(
        '  ... $moreConnector ${formatCount(issues.length - ctx.effectiveListItemLimit)} ${AppStrings.more}',
      );
    }
  }
  if (appendTrailingBlankLine) {
    blockLines.add('');
  }
  _addListBlock(
    listBlocks,
    status: status,
    sortKey: sortKey,
    blockLines: blockLines,
  );
}
