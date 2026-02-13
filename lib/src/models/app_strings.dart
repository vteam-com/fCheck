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
  static const String oneClassPerFile = 'One Class/File';
  static const String magicNumbers = 'Magic Numbers';
  static const String secrets = 'Secrets';
  static const String deadCode = 'Dead Code';
  static const String layers = 'Layers';
  static const String sourceSorting = 'Source Sorting';
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
  static const String svgLayers = 'SVG layers';
  static const String svgLayersFolder = 'SVG layers (folder)';
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
}
