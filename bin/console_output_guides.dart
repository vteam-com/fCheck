part of 'console_output.dart';

/// Returns the in-file ignore directive for an analyzer, when supported.
///
/// Some analyzers intentionally do not support per-file ignore comments and
/// return `null`.
String? _ignoreDirectiveForAnalyzer(AnalyzerDomain analyzer) {
  switch (analyzer) {
    case AnalyzerDomain.codeSize:
      return null;
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
  print(AppStrings.exampleCodeSize);
  print(AppStrings.exampleMaxFileLoc);
  print(AppStrings.exampleMaxClassLoc);
  print(AppStrings.exampleMaxFunctionLoc);
  print(AppStrings.exampleMaxMethodLoc);
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
  print(AppStrings.formulaCodeSize);
  print(AppStrings.formulaCodeSizeThresholds);
  print(AppStrings.formulaCodeSizeComputation);
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
