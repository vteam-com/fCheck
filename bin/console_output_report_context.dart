part of 'console_output.dart';

class _ReportContext {
  final ReportListMode listMode;
  final int effectiveListItemLimit;
  final bool filenamesOnly;

  final String projectName;
  final String version;
  final int totalFolders;
  final int totalFiles;
  final int totalDartFiles;
  final int excludedFilesCount;
  final int customExcludedFilesCount;
  final int ignoreDirectivesCount;
  final List<MapEntry<String, int>> ignoreDirectiveEntries;
  final int ignoreDirectiveFileCount;
  final int disabledAnalyzersCount;
  final int totalLinesOfCode;
  final int totalCommentLines;
  final double commentRatio;
  final int dependencyCount;
  final int devDependencyCount;
  final int classCount;
  final int methodCount;
  final int functionCount;
  final String commentSummary;
  final ProjectType projectType;

  final List hardcodedStringIssues;
  final bool usesLocalization;
  final List magicNumberIssues;
  final List secretIssues;
  final List deadCodeIssues;
  final List deadFileIssues;
  final List deadClassIssues;
  final List deadFunctionIssues;
  final List unusedVariableIssues;
  final List documentationIssues;
  final List duplicateCodeIssues;
  final List sourceSortIssues;
  final List layersIssues;
  final List nonCompliant;

  final bool codeSizeAnalyzerEnabled;
  final bool oneClassPerFileAnalyzerEnabled;
  final bool hardcodedStringsAnalyzerEnabled;
  final bool magicNumbersAnalyzerEnabled;
  final bool sourceSortingAnalyzerEnabled;
  final bool secretsAnalyzerEnabled;
  final bool deadCodeAnalyzerEnabled;
  final bool duplicateCodeAnalyzerEnabled;
  final bool documentationAnalyzerEnabled;
  final bool layersAnalyzerEnabled;

  final List<({String title, int threshold, List<CodeSizeArtifact> artifacts})>
  codeSizeSections;

  final List<String> disabledAnalyzerKeys;
  final int complianceScore;
  final int suppressionPenaltyPoints;
  final String complianceFocusAreaLabel;
  final int complianceFocusAreaIssueCount;
  final String complianceNextInvestment;
  final Map<String, int> analyzerScoresByKey;
  final Map<String, int> analyzerIssueCountsByKey;
  final Map<String, bool> analyzerEnabledByKey;
  final Map<String, double> analyzerDeductionPercentByKey;

  const _ReportContext({
    required this.listMode,
    required this.effectiveListItemLimit,
    required this.filenamesOnly,
    required this.projectName,
    required this.version,
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.excludedFilesCount,
    required this.customExcludedFilesCount,
    required this.ignoreDirectivesCount,
    required this.ignoreDirectiveEntries,
    required this.ignoreDirectiveFileCount,
    required this.disabledAnalyzersCount,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.commentRatio,
    required this.dependencyCount,
    required this.devDependencyCount,
    required this.classCount,
    required this.methodCount,
    required this.functionCount,
    required this.commentSummary,
    required this.projectType,
    required this.hardcodedStringIssues,
    required this.usesLocalization,
    required this.magicNumberIssues,
    required this.secretIssues,
    required this.deadCodeIssues,
    required this.deadFileIssues,
    required this.deadClassIssues,
    required this.deadFunctionIssues,
    required this.unusedVariableIssues,
    required this.documentationIssues,
    required this.duplicateCodeIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.nonCompliant,
    required this.codeSizeAnalyzerEnabled,
    required this.oneClassPerFileAnalyzerEnabled,
    required this.hardcodedStringsAnalyzerEnabled,
    required this.magicNumbersAnalyzerEnabled,
    required this.sourceSortingAnalyzerEnabled,
    required this.secretsAnalyzerEnabled,
    required this.deadCodeAnalyzerEnabled,
    required this.duplicateCodeAnalyzerEnabled,
    required this.documentationAnalyzerEnabled,
    required this.layersAnalyzerEnabled,
    required this.codeSizeSections,
    required this.disabledAnalyzerKeys,
    required this.complianceScore,
    required this.suppressionPenaltyPoints,
    required this.complianceFocusAreaLabel,
    required this.complianceFocusAreaIssueCount,
    required this.complianceNextInvestment,
    required this.analyzerScoresByKey,
    required this.analyzerIssueCountsByKey,
    required this.analyzerEnabledByKey,
    required this.analyzerDeductionPercentByKey,
  });

  factory _ReportContext.fromMetrics(
    ProjectMetrics metrics, {
    required ReportListMode listMode,
    required int listItemLimit,
  }) {
    final effectiveListItemLimit = listItemLimit > 0 ? listItemLimit : 1;
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
      final firstPathCompare = left.firstFilePath.compareTo(
        right.firstFilePath,
      );
      if (firstPathCompare != 0) {
        return firstPathCompare;
      }
      final secondPathCompare = left.secondFilePath.compareTo(
        right.secondFilePath,
      );
      if (secondPathCompare != 0) {
        return secondPathCompare;
      }
      final firstLineCompare = left.firstLineNumber.compareTo(
        right.firstLineNumber,
      );
      if (firstLineCompare != 0) {
        return firstLineCompare;
      }
      final secondLineCompare = left.secondLineNumber.compareTo(
        right.secondLineNumber,
      );
      if (secondLineCompare != 0) {
        return secondLineCompare;
      }
      final firstSymbolCompare = left.firstSymbol.compareTo(right.firstSymbol);
      if (firstSymbolCompare != 0) {
        return firstSymbolCompare;
      }
      return left.secondSymbol.compareTo(right.secondSymbol);
    });

    final codeSizeCallableArtifacts = [...metrics.codeSizeCallableArtifacts]
      ..sort((left, right) => right.linesOfCode.compareTo(left.linesOfCode));
    final codeSizeFunctionArtifacts = codeSizeCallableArtifacts
        .where((artifact) => artifact.kind == CodeSizeArtifactKind.function)
        .toList(growable: false);
    final codeSizeMethodArtifacts = codeSizeCallableArtifacts
        .where((artifact) => artifact.kind == CodeSizeArtifactKind.method)
        .toList(growable: false);
    final codeSizeSections =
        <({String title, int threshold, List<CodeSizeArtifact> artifacts})>[
          (
            title: 'Files',
            threshold: metrics.codeSizeThresholds.maxFileLoc,
            artifacts: [...metrics.codeSizeFileArtifacts]
              ..sort(
                (left, right) => right.linesOfCode.compareTo(left.linesOfCode),
              ),
          ),
          (
            title: 'Classes',
            threshold: metrics.codeSizeThresholds.maxClassLoc,
            artifacts: [...metrics.codeSizeClassArtifacts]
              ..sort(
                (left, right) => right.linesOfCode.compareTo(left.linesOfCode),
              ),
          ),
          (
            title: 'Functions',
            threshold: metrics.codeSizeThresholds.maxFunctionLoc,
            artifacts: codeSizeFunctionArtifacts,
          ),
          (
            title: 'Methods',
            threshold: metrics.codeSizeThresholds.maxMethodLoc,
            artifacts: codeSizeMethodArtifacts,
          ),
        ];

    final disabledAnalyzerKeys = <String>[
      if (!metrics.codeSizeAnalyzerEnabled) AnalyzerDomain.codeSize.configName,
      if (!metrics.oneClassPerFileAnalyzerEnabled)
        AnalyzerDomain.oneClassPerFile.configName,
      if (!metrics.hardcodedStringsAnalyzerEnabled)
        AnalyzerDomain.hardcodedStrings.configName,
      if (!metrics.magicNumbersAnalyzerEnabled)
        AnalyzerDomain.magicNumbers.configName,
      if (!metrics.sourceSortingAnalyzerEnabled)
        AnalyzerDomain.sourceSorting.configName,
      if (!metrics.layersAnalyzerEnabled) AnalyzerDomain.layers.configName,
      if (!metrics.secretsAnalyzerEnabled) AnalyzerDomain.secrets.configName,
      if (!metrics.deadCodeAnalyzerEnabled) AnalyzerDomain.deadCode.configName,
      if (!metrics.duplicateCodeAnalyzerEnabled)
        AnalyzerDomain.duplicateCode.configName,
      if (!metrics.documentationAnalyzerEnabled)
        AnalyzerDomain.documentation.configName,
    ]..sort();

    final suppressionPenaltyPoints = metrics.suppressionPenaltyPoints;
    final analyzerScoresByKey = <String, int>{
      for (final score in metrics.analyzerScores) score.key: score.scorePercent,
      'suppression_hygiene':
          (_percentageMultiplier -
                  ((suppressionPenaltyPoints / _maxSuppressionPenaltyPoints) *
                          _percentageMultiplier)
                      .round())
              .clamp(0, _percentageMultiplier),
    };
    final analyzerIssueCountsByKey = <String, int>{
      for (final score in metrics.analyzerScores) score.key: score.issueCount,
      'suppression_hygiene':
          metrics.ignoreDirectivesCount +
          metrics.customExcludedFilesCount +
          metrics.disabledAnalyzersCount,
    };
    final analyzerEnabledByKey = <String, bool>{
      for (final score in metrics.analyzerScores) score.key: score.enabled,
      'suppression_hygiene': true,
    };
    final enabledScoredAnalyzerCount = metrics.analyzerScores
        .where((score) => score.enabled)
        .where(
          (score) =>
              score.key != 'documentation' ||
              metrics.documentationIssues.isNotEmpty,
        )
        .length;
    final safeEnabledScoredAnalyzerCount = enabledScoredAnalyzerCount == 0
        ? 1
        : enabledScoredAnalyzerCount;
    final analyzerDeductionPercentByKey = <String, double>{
      for (final score in metrics.analyzerScores)
        score.key: score.enabled
            ? ((1 - score.score).clamp(0.0, 1.0) * _percentageMultiplier) /
                  safeEnabledScoredAnalyzerCount
            : 0,
      'suppression_hygiene': suppressionPenaltyPoints.toDouble(),
    };

    final classCount = metrics.fileMetrics.fold<int>(
      0,
      (sum, metric) => sum + metric.classCount,
    );
    final methodCount = metrics.fileMetrics.fold<int>(
      0,
      (sum, metric) => sum + metric.methodCount,
    );
    final functionCount = metrics.fileMetrics.fold<int>(
      0,
      (sum, metric) => sum + metric.topLevelFunctionCount,
    );
    return _ReportContext(
      listMode: listMode,
      effectiveListItemLimit: effectiveListItemLimit,
      filenamesOnly: listMode == ReportListMode.filenames,
      projectName: metrics.projectName,
      version: metrics.version,
      totalFolders: metrics.totalFolders,
      totalFiles: metrics.totalFiles,
      totalDartFiles: metrics.totalDartFiles,
      excludedFilesCount: metrics.excludedFilesCount,
      customExcludedFilesCount: metrics.customExcludedFilesCount,
      ignoreDirectivesCount: metrics.ignoreDirectivesCount,
      ignoreDirectiveEntries: ignoreDirectiveEntries,
      ignoreDirectiveFileCount: ignoreDirectiveEntries.length,
      disabledAnalyzersCount: metrics.disabledAnalyzersCount,
      totalLinesOfCode: metrics.totalLinesOfCode,
      totalCommentLines: metrics.totalCommentLines,
      commentRatio: metrics.commentRatio,
      dependencyCount: metrics.dependencyCount,
      devDependencyCount: metrics.devDependencyCount,
      classCount: classCount,
      methodCount: methodCount,
      functionCount: functionCount,
      commentSummary: _commentSummary(
        totalCommentLines: metrics.totalCommentLines,
        commentRatio: metrics.commentRatio,
        width: _gridValueWidth,
      ),
      projectType: metrics.projectType,
      hardcodedStringIssues: metrics.hardcodedStringIssues,
      usesLocalization: metrics.usesLocalization,
      magicNumberIssues: metrics.magicNumberIssues,
      secretIssues: metrics.secretIssues,
      deadCodeIssues: metrics.deadCodeIssues,
      deadFileIssues: metrics.deadFileIssues,
      deadClassIssues: metrics.deadClassIssues,
      deadFunctionIssues: metrics.deadFunctionIssues,
      unusedVariableIssues: metrics.unusedVariableIssues,
      documentationIssues: metrics.documentationIssues,
      duplicateCodeIssues: duplicateCodeIssues,
      sourceSortIssues: metrics.sourceSortIssues,
      layersIssues: metrics.layersIssues,
      nonCompliant: metrics.fileMetrics
          .where((metric) => !metric.isOneClassPerFileCompliant)
          .toList(),
      codeSizeAnalyzerEnabled: metrics.codeSizeAnalyzerEnabled,
      oneClassPerFileAnalyzerEnabled: metrics.oneClassPerFileAnalyzerEnabled,
      hardcodedStringsAnalyzerEnabled: metrics.hardcodedStringsAnalyzerEnabled,
      magicNumbersAnalyzerEnabled: metrics.magicNumbersAnalyzerEnabled,
      sourceSortingAnalyzerEnabled: metrics.sourceSortingAnalyzerEnabled,
      secretsAnalyzerEnabled: metrics.secretsAnalyzerEnabled,
      deadCodeAnalyzerEnabled: metrics.deadCodeAnalyzerEnabled,
      duplicateCodeAnalyzerEnabled: metrics.duplicateCodeAnalyzerEnabled,
      documentationAnalyzerEnabled: metrics.documentationAnalyzerEnabled,
      layersAnalyzerEnabled: metrics.layersAnalyzerEnabled,
      codeSizeSections: codeSizeSections,
      disabledAnalyzerKeys: disabledAnalyzerKeys,
      complianceScore: metrics.complianceScore,
      suppressionPenaltyPoints: suppressionPenaltyPoints,
      complianceFocusAreaLabel: metrics.complianceFocusAreaLabel,
      complianceFocusAreaIssueCount: metrics.complianceFocusAreaIssueCount,
      complianceNextInvestment: metrics.complianceNextInvestment,
      analyzerScoresByKey: analyzerScoresByKey,
      analyzerIssueCountsByKey: analyzerIssueCountsByKey,
      analyzerEnabledByKey: analyzerEnabledByKey,
      analyzerDeductionPercentByKey: analyzerDeductionPercentByKey,
    );
  }
}
