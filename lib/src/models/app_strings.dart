// ignore_for_file: public_member_api_docs

/// Shared string constants for the fcheck project.
///
/// This class provides a central location for all user-facing strings,
/// CLI labels, and error messages used throughout the application.
class AppStrings {
  // CLI Common
  static const String usageLine = 'Usage: dart run fcheck [options] [<folder>]';
  static const String descriptionLine =
      'Analyze Flutter/Dart code quality and provide metrics.';
  static const String invalidArgumentsLine =
      'Error: Invalid arguments provided.';

  // Report Sections
  static const String scorecardDivider = 'Scorecard';
  static const String dashboardDivider = 'Dashboard';
  static const String literalsDivider = 'Literals';
  static const String listsDivider = 'Lists';

  // Labels
  static const String complianceScore = 'Compliance Score';
  static const String suppressions = 'Suppressions';
  static const String investNext = 'Invest Next';
  static const String focusArea = 'Focus Area';
  static const String files = 'Files';
  static const String filesSmall = 'files';
  static const String file = 'file';
  static const String dartFiles = 'Dart Files';
  static const String dartFileExcluded = 'Dart file excluded';
  static const String dartFilesExcluded = 'Dart files excluded';
  static const String analyzerSmall = 'analyzer';
  static const String analyzersSmall = 'analyzers';
  static const String excludedFiles = 'Excluded Files';
  static const String customExcludes = 'Custom Excludes';
  static const String ignoreDirectives = 'Ignore Directives';
  static const String disabledRules = 'Disabled Rules';
  static const String folders = 'Folders';
  static const String loc = 'Lines of Code';
  static const String comments = 'Comments';
  static const String classes = 'Classes';
  static const String methods = 'Methods';
  static const String functions = 'Functions';
  static const String stringLiterals = 'String Literals';
  static const String numberLiterals = 'Number Literals';
  static const String strings = 'Strings';
  static const String numbers = 'Numbers';
  static const String dupeSuffix = 'dupe';
  static const String hardcodedSuffix = 'hardcoded';
  static const String oneClassPerFile = 'One Class/File';
  static const String hardcodedStrings = 'Hardcoded Strings';
  static const String magicNumbers = 'Magic Numbers';
  static const String secrets = 'Secrets';
  static const String deadCode = 'Dead Code';
  static const String layers = 'Layers';
  static const String sourceSorting = 'Source Sorting';
  static const String dependency = 'Dependency';
  static const String devDependency = 'DevDependency';
  static const String dependencies = 'Dependencies';
  static const String duplicateCode = 'Duplicate Code';

  // Indicators
  static const String noneIndicator = '  (none)';
  static const String checkPassed = 'passed.';
  static const String checkPassedCapital = 'Passed.';
  static const String disabled = 'disabled';
  static const String enabled = 'enabled';
  static const String on = 'ON';
  static const String off = 'OFF';
  static const String unknownLocation = 'unknown location';

  // Specific Messages
  static const String secretsScan = 'Secrets scan';
  static const String deadCodeCheck = 'Dead code check';
  static const String documentationCheck = 'Documentation check';
  static const String layersCheck = 'Layers architecture check';
  static const String duplicateCodeCheck = 'Duplicate code check';
  static const String potentialSecretsDetected = 'potential secrets detected:';
  static const String deadCodeIssuesDetected = 'dead code issues detected:';
  static const String documentationIssuesDetected =
      'documentation issues detected:';
  static const String layersViolationsDetected =
      'layers architecture violations detected:';
  static const String duplicateBlocksDetected =
      'duplicate code blocks detected:';
  static const String deadFiles = 'Dead files';
  static const String deadClasses = 'Dead classes';
  static const String deadFunctions = 'Dead functions';
  static const String unusedVariables = 'Unused variables';
  static const String svgLayers = 'SVG Files';
  static const String svgLayersFolder = 'SVG Folders';
  static const String svgCodeSizeTreemap = 'SVG Lines of Code';
  static const String mermaidLayers = 'Mermaid layers';
  static const String plantUmlLayers = 'PlantUML layers';
  static const String input = 'Input';
  static const String oneClassPerFileViolate =
      'files violate the "one class per file" rule:';
  static const String hardcodedStringsDetected = 'hardcoded strings detected';
  static const String magicNumbersDetected = 'magic numbers detected:';
  static const String unsortedMembers =
      'Flutter classes have unsorted members:';
  static const String suppressionsSummary = 'Suppressions summary';
  static const String ignoreDirectivesAcross = 'across';
  static const String acrossFiles = 'across';
  static const String project = 'Project';
  static const String version = 'version:';
  static const String issues = 'issues';
  static const String more = 'more';
  static const String and = 'and';
  static const String skipped = 'skipped';
  static const String localization = 'Localization';
  static const String itemsPerList = 'items per list';
  static const String showAllEntries = 'Show all list entries';
  static const String uniqueFileNamesOnly = 'Show unique file names only';
  static const String summaryOnly = 'Summary only (no Lists section)';

  // File Patterns
  static const String analysisError = 'Error during analysis:';
  static const String pubspecYaml = 'pubspec.yaml';
  static const String fcheckConfig = '.fcheck';

  // Ignore Guide
  static const String setupIgnoresInDartFile =
      'Setup ignores directly in Dart file';
  static const String topOfFileDirectivesPosition =
      'Top-of-file directives must be placed before any Dart code in the file.';
  static const String hardcodedStringsFlutterStyles =
      'Hardcoded strings also support Flutter-style ignore comments:';
  static const String ignoreForFileHardcoded =
      '  - // ignore_for_file: avoid_hardcoded_strings_in_widgets';
  static const String setupUsingFcheckFile = 'Setup using the .fcheck file';
  static const String createFcheckInInput =
      'Create .fcheck in the --input directory (or current directory).';
  static const String supportedExample = 'Supported example:';
  static const String exampleInput = '  input:';
  static const String exampleExclude = '    exclude:';
  static const String exampleExcludePattern = '      - "**/example/**"';
  static const String exampleAnalyzers = '  analyzers:';
  static const String exampleDefault = '    default: on|off';
  static const String exampleDisabled = '    disabled: # or enabled';
  static const String exampleHardcodedStrings = '      - hardcoded_strings';
  static const String exampleOptions = '    options:';
  static const String exampleDuplicateCode = '      duplicate_code:';
  static const String exampleCodeSize = '      code_size:';
  static const String exampleSimilarityThreshold =
      '        similarity_threshold: 0.90 # 0.0 to 1.0';
  static const String exampleMinTokens = '        min_tokens: 20';
  static const String exampleMinNonEmptyLines =
      '        min_non_empty_lines: 8';
  static const String exampleMaxFileLoc = '        max_file_loc: 900';
  static const String exampleMaxClassLoc = '        max_class_loc: 800';
  static const String exampleMaxFunctionLoc = '        max_function_loc: 700';
  static const String exampleMaxMethodLoc = '        max_method_loc: 500';
  static const String availableAnalyzerNames = 'Available analyzer names:';

  // Scoring Guide
  static const String complianceScoreModel =
      'Compliance score model from 0% to 100%';
  static const String onlyEnabledAnalyzersContribute =
      'Only enabled analyzers contribute to the score.';
  static const String enabledAnalyzersCurrentModel =
      'Enabled analyzers (current model: ';
  static const String howIs100Distributed = 'How is the 100% distributed:';
  static const String nAsNumberOfEnabled = '  N = number of enabled analyzers';
  static const String eachAnalyzerShare = '  each analyzer share = 100 / N';
  static const String currentAnalyzerCountPrefix = '  Current: ';
  static const String eachSmall = ' each';
  static const String perAnalyzerDomainScoreClamped =
      'Per-analyzer domain score is clamped to [0.0, 1.0].';
  static const String oneDomainCanOnlyConsumeShare =
      'One domain can only consume its own share, never more.';
  static const String domainFormulasUsed = 'Domain formulas used:';
  static const String formulaCodeSize =
      '  - code_size: threshold overage model by artifact kind (file/class/function/method)';
  static const String formulaCodeSizeThresholds =
      '    defaults: file>900, class>800, function>700, method>500 LOC';
  static const String formulaCodeSizeComputation =
      '    score = 1 - (sum(overageRatio for violating artifacts) / totalArtifacts), overageRatio=(loc-threshold)/threshold';
  static const String formulaOneClassPerFile =
      '  - one_class_per_file: 1 - (violations / max(1, dartFiles))';
  static const String formulaHardcodedStrings =
      '  - hardcoded_strings: when localization is ON -> 1 - (issues / max(3.0, dartFiles * 0.8)); when localization is OFF -> passive (excluded from score)';
  static const String formulaMagicNumbers =
      '  - magic_numbers: 1 - (issues / max(4.0, dartFiles * 2.5 + loc / 450))';
  static const String formulaSourceSorting =
      '  - source_sorting: 1 - (issues / max(2.0, dartFiles * 0.75))';
  static const String formulaLayers =
      '  - layers: 1 - (issues / max(2.0, max(1, edges) * 0.20))';
  static const String formulaSecrets = '  - secrets: 1 - (issues / 1.5)';
  static const String formulaDeadCode =
      '  - dead_code: 1 - (issues / max(3.0, dartFiles * 0.8))';
  static const String formulaDuplicateCode =
      '  - duplicate_code: 1 - ((impactLines / max(1, loc)) * 2.5)';
  static const String impactLinesSum =
      '    impactLines = sum(issue.lineCount * issue.similarity)';
  static const String suppressionPenaltyBudget =
      'Suppression penalty (budget-based):';
  static const String formulaIgnoreBudget =
      '  - ignore directives budget: max(3.0, dartFiles * 0.12 + loc / 2500)';
  static const String formulaCustomExcludedBudget =
      '  - custom excludes budget: max(2.0, (dartFiles + customExcluded) * 0.08)';
  static const String formulaDisabledAnalyzersBudget =
      '  - disabled analyzers budget: 1.0';
  static const String weightedOverusePrefix = '  - weightedOveruse =';
  static const String weightedOveruseFormulaLine1 =
      '      over(ignore) * 0.45 + over(customExcluded) * 0.35 +';
  static const String weightedOveruseFormulaLine2 =
      '      over(disabledAnalyzers) * 0.20';
  static const String suppressionPenaltyPointsPrefix =
      '  - suppressionPenaltyPoints =';
  static const String suppressionPenaltyPointsFormula =
      '      round(clamp(weightedOveruse * 25, 0, 25))';
  static const String overXFormula =
      '    over(x) = max(0, (used - budget) / budget)';
  static const String finalScoreLabel = 'Final score:';
  static const String formulaAverage =
      '  average = sum(enabledDomainScores) / N';
  static const String formulaBaseScore =
      '  baseScore = clamp(average * 100, 0, 100)';
  static const String formulaComplianceScore =
      '  complianceScore = round(clamp(baseScore - suppressionPenalty, 0, 100))';
  static const String specialRulePrefix =
      '  Special rule: if rounded score is 100 but any enabled domain';
  static const String specialRuleSuffix =
      '  score is below 1.0, or suppression penalty > 0, final score is 99.';
  static const String focusAreaAndInvestNextLabel =
      'Focus Area and Invest Next:';
  static const String focusAreaExplanation =
      '  - Focus Area is the enabled domain with the highest penalty impact (or checks bypassed when suppression penalties apply).';
  static const String tieBreakerExplanation =
      '  - Tie-breaker: domain with more issues.';
  static const String investNextExplanation =
      '  - Invest Next recommendation is mapped from the selected focus area.';

  // Dynamic messages
  /// Builds a generic `<label> found (<count>):` section header.
  static String foundItemsHeader({
    required String label,
    required String count,
  }) => '$label found ($count):';

  /// Builds a generic `Unique <label> found (<count>):` section header.
  static String uniqueFoundItemsHeader({
    required String label,
    required String count,
  }) => 'Unique $label found ($count):';

  /// Formats the current enabled analyzer count and percentage share line.
  static String currentAnalyzerCountLine(int analyzerCount, String share) =>
      '  Current: $analyzerCount analyzers -> $share% each';

  /// Builds the missing-directory error shown for an invalid input path.
  static String missingDirectoryError(String path) =>
      'Error: Directory "$path" does not exist.';

  /// Builds the invalid `.fcheck` configuration error message.
  static String invalidFcheckConfigurationError(String message) =>
      'Error: Invalid .fcheck configuration. $message';

  /// Builds the header for excluded Dart files in `--excluded` output.
  static String excludedDartFilesHeader(String count) =>
      'Excluded Dart files ($count):';

  /// Builds the header for excluded non-Dart files in `--excluded` output.
  static String excludedNonDartFilesHeader(String count) =>
      '\nExcluded non-Dart files ($count):';

  /// Builds the header for excluded directories in `--excluded` output.
  static String excludedDirectoriesHeader(String count) =>
      '\nExcluded directories ($count):';

  /// Builds the analysis failure prefix line with the caught [error].
  static String analysisErrorLine(Object error) => '$analysisError $error';
}
