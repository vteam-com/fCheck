import 'dart:math' as math;
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/layers/layers_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/models/project_type.dart';

/// Represents the overall quality metrics for a Flutter/Dart project.
///
/// This class aggregates metrics from all analyzed files in a project,
/// providing insights into code quality, size, and compliance with
/// coding standards.
class ProjectMetrics {
  static const double _minHardcodedBudget = 3.0;
  static const double _localizedHardcodedBudgetPerFile = 0.8;
  static const double _nonLocalizedHardcodedBudgetPerFile = 2.0;
  static const double _minMagicNumberBudget = 4.0;
  static const double _magicNumberBudgetPerFile = 2.5;
  static const double _magicNumberBudgetPerLoc = 1 / 450;
  static const double _minSourceSortBudget = 2.0;
  static const double _sourceSortBudgetPerFile = 0.75;
  static const double _minLayersBudget = 2.0;
  static const double _layersBudgetPerEdge = 0.20;
  static const double _secretsBudget = 1.5;
  static const double _minDeadCodeBudget = 3.0;
  static const double _deadCodeBudgetPerFile = 0.8;
  static const double _duplicateRatioPenaltyMultiplier = 2.5;
  static const double _minIgnoreDirectiveBudget = 3.0;
  static const double _ignoreDirectiveBudgetPerFile = 0.12;
  static const double _ignoreDirectiveBudgetPerLoc = 1 / 2500;
  static const double _minCustomExcludedFileBudget = 2.0;
  static const double _customExcludedFileBudgetRatio = 0.08;
  static const double _disabledAnalyzerBudget = 1.0;
  static const double _ignorePenaltyWeight = 0.45;
  static const double _customExcludedPenaltyWeight = 0.35;
  static const double _disabledAnalyzerPenaltyWeight = 0.20;
  static const int _maxSuppressionPenaltyPoints = 25;

  static const int _maxPercent = 100;

  /// The detected type of the analyzed project.
  final ProjectType projectType;

  /// Total number of folders in the project.
  final int totalFolders;

  /// Total number of files in the project.
  final int totalFiles;

  /// Total number of Dart files in the project.
  final int totalDartFiles;

  /// Total lines of code across all Dart files.
  final int totalLinesOfCode;

  /// Total comment lines across all Dart files.
  final int totalCommentLines;

  /// Metrics for each individual Dart file.
  final List<FileMetrics> fileMetrics;

  /// List of secret issues found in the project.
  final List<SecretIssue> secretIssues;

  /// List of hardcoded string issues found in the project.
  final List<HardcodedStringIssue> hardcodedStringIssues;

  /// List of detected magic number literals across the project.
  final List<MagicNumberIssue> magicNumberIssues;

  /// List of source sorting issues found in the project.
  final List<SourceSortIssue> sourceSortIssues;

  /// List of layers architecture issues found in the project.
  final List<LayersIssue> layersIssues;

  /// List of dead code issues found in the project.
  final List<DeadCodeIssue> deadCodeIssues;

  /// List of duplicate code issues found in the project.
  final List<DuplicateCodeIssue> duplicateCodeIssues;

  /// Total number of dependency edges in the layers graph.
  final int layersEdgeCount;

  /// Number of layers in the project.
  final int layersCount;

  /// The dependency graph used for analysis (filePath -> list of dependencies).
  final Map<String, List<String>> dependencyGraph;

  /// Per-file layer assignments computed during layers analysis.
  ///
  /// This is used by CLI graph exporters to avoid re-running layers analysis.
  final Map<String, int> layersByFile;

  /// Number of files successfully skipped based on exclusion glob patterns.
  final int excludedFilesCount;

  /// Number of Dart files excluded by user-provided glob patterns.
  final int customExcludedFilesCount;

  /// Count of `// ignore: fcheck_*` directives found in analyzed Dart files.
  final int ignoreDirectivesCount;

  /// Unique file paths containing at least one `// ignore: fcheck_*` directive.
  final List<String> ignoreDirectiveFiles;

  /// Per-file count of `// ignore: fcheck_*` directives.
  final Map<String, int> ignoreDirectiveCountsByFile;

  /// Whether the project appears to be using Flutter localization (l10n).
  ///
  /// Detection is based on the presence of `l10n.yaml`, `.arb` files,
  /// or imports of generated localization files.
  final bool usesLocalization;

  /// The version of the analyzed project as defined in its pubspec.yaml.
  final String version;

  /// The name of the analyzed project as defined in its pubspec.yaml.
  final String projectName;

  /// Whether the one-class-per-file analyzer was enabled for this run.
  final bool oneClassPerFileAnalyzerEnabled;

  /// Whether the hardcoded-strings analyzer was enabled for this run.
  final bool hardcodedStringsAnalyzerEnabled;

  /// Whether the magic-numbers analyzer was enabled for this run.
  final bool magicNumbersAnalyzerEnabled;

  /// Whether the source-sorting analyzer was enabled for this run.
  final bool sourceSortingAnalyzerEnabled;

  /// Whether the layers analyzer was enabled for this run.
  final bool layersAnalyzerEnabled;

  /// Whether the secrets analyzer was enabled for this run.
  final bool secretsAnalyzerEnabled;

  /// Whether the dead-code analyzer was enabled for this run.
  final bool deadCodeAnalyzerEnabled;

  /// Whether the duplicate-code analyzer was enabled for this run.
  final bool duplicateCodeAnalyzerEnabled;

  /// Creates a new ProjectMetrics instance.
  ///
  /// [totalFolders] Total number of folders in the project.
  /// [totalFiles] Total number of files in the project.
  /// [totalDartFiles] Total number of Dart files in the project.
  /// [totalLinesOfCode] Total lines of code across all Dart files.
  /// [totalCommentLines] Total comment lines across all Dart files.
  /// [fileMetrics] Metrics for each individual Dart file.
  /// [secretIssues] List of secret issues found in the project.
  /// [hardcodedStringIssues] List of hardcoded string issues found in the project.
  /// [magicNumberIssues] List of detected magic number literals across the project.
  /// [sourceSortIssues] List of source sorting issues found in the project.
  /// [layersIssues] List of layers architecture issues found in the project.
  /// [deadCodeIssues] List of dead code issues found in the project.
  /// [duplicateCodeIssues] List of duplicate code issues found in the project.
  /// [layersEdgeCount] Total number of dependency edges in the layers graph.
  /// [layersCount] Number of layers in the project.
  /// [dependencyGraph] The dependency graph used for analysis.
  /// [projectName] The name of the analyzed project.
  /// [version] The version of the analyzed project.
  /// [projectType] The detected project type (Flutter, Dart, or Unknown).
  /// [usesLocalization] Whether the project appears to be using Flutter localization.
  /// [excludedFilesCount] Number of files successfully skipped based on exclusion glob patterns.
  /// [customExcludedFilesCount] Number of Dart files excluded by custom glob patterns.
  /// [ignoreDirectivesCount] Number of `// ignore: fcheck_*` directives found.
  /// [ignoreDirectiveFiles] Unique file paths containing `// ignore: fcheck_*`.
  /// [ignoreDirectiveCountsByFile] Per-file counts for `// ignore: fcheck_*`.
  ProjectMetrics({
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.fileMetrics,
    required this.secretIssues,
    required this.hardcodedStringIssues,
    required this.magicNumberIssues,
    required this.sourceSortIssues,
    required this.layersIssues,
    required this.deadCodeIssues,
    this.duplicateCodeIssues = const [],
    required this.layersEdgeCount,
    required this.layersCount,
    required this.dependencyGraph,
    this.layersByFile = const {},
    required this.projectName,
    required this.version,
    required this.projectType,
    this.usesLocalization = false,
    this.excludedFilesCount = 0,
    this.customExcludedFilesCount = 0,
    this.ignoreDirectivesCount = 0,
    this.ignoreDirectiveFiles = const [],
    this.ignoreDirectiveCountsByFile = const {},
    this.oneClassPerFileAnalyzerEnabled = true,
    this.hardcodedStringsAnalyzerEnabled = true,
    this.magicNumbersAnalyzerEnabled = true,
    this.sourceSortingAnalyzerEnabled = true,
    this.layersAnalyzerEnabled = true,
    this.secretsAnalyzerEnabled = true,
    this.deadCodeAnalyzerEnabled = true,
    this.duplicateCodeAnalyzerEnabled = true,
  });

  /// Converts these metrics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'project': {
          'name': projectName,
          'version': version,
          'type': projectType.label,
        },
        'stats': {
          'folders': totalFolders,
          'files': totalFiles,
          'dartFiles': totalDartFiles,
          'excludedFiles': excludedFilesCount,
          'customExcludedFiles': customExcludedFilesCount,
          'ignoreDirectives': ignoreDirectivesCount,
          'disabledAnalyzers': disabledAnalyzersCount,
          'suppressionPenalty': suppressionPenaltyPoints,
          'linesOfCode': totalLinesOfCode,
          'commentLines': totalCommentLines,
          'commentRatio': commentRatio,
          'hardcodedStrings': hardcodedStringIssues.length,
          'magicNumbers': magicNumberIssues.length,
          'secretIssues': secretIssues.length,
          'deadCodeIssues': deadCodeIssues.length,
          'duplicateCodeIssues': duplicateCodeIssues.length,
          'complianceScore': complianceScore,
        },
        'layers': {
          'count': layersCount,
          'dependencies': layersEdgeCount,
          'violations': layersIssues.map((i) => i.toJson()).toList(),
          'graph': dependencyGraph,
        },
        'files': fileMetrics.map((m) => m.toJson()).toList(),
        'hardcodedStrings':
            hardcodedStringIssues.map((i) => i.toJson()).toList(),
        'magicNumbers': magicNumberIssues.map((i) => i.toJson()).toList(),
        'sourceSorting': sourceSortIssues.map((i) => i.toJson()).toList(),
        'secretIssues': secretIssues.map((i) => i.toJson()).toList(),
        'deadCodeIssues': deadCodeIssues.map((i) => i.toJson()).toList(),
        'duplicateCodeIssues':
            duplicateCodeIssues.map((i) => i.toJson()).toList(),
        'localization': {'usesLocalization': usesLocalization},
        'compliance': {
          'score': complianceScore,
          'suppressionPenalty': suppressionPenaltyPoints,
          'focusArea': complianceFocusAreaKey,
          'focusAreaLabel': complianceFocusAreaLabel,
          'focusAreaIssues': complianceFocusAreaIssueCount,
          'nextInvestment': complianceNextInvestment,
        },
      };

  /// The ratio of comment lines to total lines of code, as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if there are no lines of code.
  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

  /// Number of analyzers disabled for this run.
  int get disabledAnalyzersCount => [
        oneClassPerFileAnalyzerEnabled,
        hardcodedStringsAnalyzerEnabled,
        magicNumbersAnalyzerEnabled,
        sourceSortingAnalyzerEnabled,
        layersAnalyzerEnabled,
        secretsAnalyzerEnabled,
        deadCodeAnalyzerEnabled,
        duplicateCodeAnalyzerEnabled,
      ].where((enabled) => !enabled).length;

  /// Equal-share quality score across enabled analyzers from 0 to 100.
  ///
  /// Higher is better. A score of 100 means no detected compliance penalties
  /// across all enabled analyzers.
  ///
  /// Formula:
  /// - `domainAverage = sum(enabledDomainScores) / enabledDomainCount`
  /// - `baseScore = clamp(domainAverage * 100, 0, 100)`
  /// - `score = round(clamp(baseScore - suppressionPenaltyPoints, 0, 100))`
  ///
  /// Special rule:
  /// - If rounding yields `100` while any enabled domain is `< 1.0`,
  ///   result is forced to `99` so perfect score remains strict.
  int get complianceScore {
    final enabledAreas = _enabledComplianceAreas;
    final averageAreaScore = enabledAreas.isEmpty
        ? 1.0
        : enabledAreas.fold<double>(0, (sum, area) => sum + area.score) /
            enabledAreas.length;
    final baseScore = averageAreaScore * _maxPercent;
    final scoreAfterSuppression = baseScore - suppressionPenaltyPoints;
    var complianceScore =
        scoreAfterSuppression.clamp(0, _maxPercent.toDouble()).round();

    // Reserve 100% for truly clean runs with zero penalties.
    if (complianceScore == _maxPercent &&
        (enabledAreas.any((area) => area.score < 1) ||
            suppressionPenaltyPoints > 0)) {
      complianceScore = _maxPercent - 1;
    }

    return complianceScore;
  }

  /// Budget-adjusted score penalty from suppressions (`ignore`, excludes, disabled analyzers).
  ///
  /// The penalty is capped to keep suppressions impactful but not dominant.
  int get suppressionPenaltyPoints {
    final ignoreOverBudgetRatio = _overBudgetRatio(
      used: ignoreDirectivesCount.toDouble(),
      budget: _ignoreDirectiveBudget,
    );
    final customExcludedOverBudgetRatio = _overBudgetRatio(
      used: customExcludedFilesCount.toDouble(),
      budget: _customExcludedFilesBudget,
    );
    final disabledAnalyzersOverBudgetRatio = _overBudgetRatio(
      used: disabledAnalyzersCount.toDouble(),
      budget: _disabledAnalyzerBudget,
    );

    final weightedOveruse = ignoreOverBudgetRatio * _ignorePenaltyWeight +
        customExcludedOverBudgetRatio * _customExcludedPenaltyWeight +
        disabledAnalyzersOverBudgetRatio * _disabledAnalyzerPenaltyWeight;

    final penalty = weightedOveruse * _maxSuppressionPenaltyPoints;
    return penalty.clamp(0, _maxSuppressionPenaltyPoints.toDouble()).round();
  }

  /// Machine-readable key for the area with highest score impact.
  ///
  /// Returns `none` when all enabled analyzers are fully compliant.
  ///
  /// Highest impact is selected by `penaltyImpact = (1 - score)`.
  /// Tie-breaker is higher issue count.
  String get complianceFocusAreaKey => _primaryFocusArea?.key ?? 'none';

  /// Human-readable label for [complianceFocusAreaKey].
  ///
  /// Returns `None` when all enabled analyzers are fully compliant.
  String get complianceFocusAreaLabel => _primaryFocusArea?.label ?? 'None';

  /// Number of detected issues for [complianceFocusAreaKey].
  ///
  /// Returns `0` when focus area is `none`.
  int get complianceFocusAreaIssueCount => _primaryFocusArea?.issueCount ?? 0;

  /// Suggested investment area to improve score in the next iteration.
  ///
  /// Message text is deterministic and mapped by focus-area key.
  String get complianceNextInvestment {
    final focusArea = _primaryFocusArea;
    if (focusArea == null) {
      return 'Maintain this level by enforcing fcheck in CI on every pull request.';
    }

    switch (focusArea.key) {
      case 'one_class_per_file':
        return 'Split files with multiple classes into focused files.';
      case 'hardcoded_strings':
        return usesLocalization
            ? 'Move user-facing literals into localization resources (.arb).'
            : 'Adopt localization and replace user-facing literals with keys.';
      case 'magic_numbers':
        return 'Replace magic numbers with named constants near domain logic.';
      case 'source_sorting':
        return 'Run with --fix to auto-sort Flutter members, then review remaining classes.';
      case 'layers':
        return 'Remove cross-layer imports and enforce dependency direction in core modules.';
      case 'secrets':
        return 'Remove secrets from source and load them from secure config or environment.';
      case 'dead_code':
        return 'Delete unused files, classes, and functions to reduce maintenance cost.';
      case 'duplicate_code':
        return 'Extract repeated code paths into shared helpers or reusable widgets.';
      case 'suppression_hygiene':
        return 'Reduce custom excludes, restore disabled analyzers, and remove stale fcheck ignore directives.';
    }

    return 'Invest in the lowest-scoring quality area to raise overall compliance.';
  }

  List<_ComplianceAreaScore> get _enabledComplianceAreas =>
      _complianceAreas.where((area) => area.enabled).toList(growable: false);

  _ComplianceAreaScore? get _primaryFocusArea {
    final candidates = _enabledComplianceAreas
        .where((area) => area.score < 1 || area.issueCount > 0)
        .toList();
    final suppressionFocusArea = _suppressionFocusArea;
    if (suppressionFocusArea != null) {
      candidates.add(suppressionFocusArea);
    }
    if (candidates.isEmpty) {
      return null;
    }

    var best = candidates.first;
    var bestImpact = best.penaltyImpact;
    for (final candidate in candidates.skip(1)) {
      final candidateImpact = candidate.penaltyImpact;
      if (candidateImpact > bestImpact) {
        best = candidate;
        bestImpact = candidateImpact;
        continue;
      }
      if (candidateImpact == bestImpact &&
          candidate.issueCount > best.issueCount) {
        best = candidate;
      }
    }
    return best;
  }

  _ComplianceAreaScore? get _suppressionFocusArea {
    final penalty = suppressionPenaltyPoints;
    if (penalty <= 0) {
      return null;
    }
    final suppressionEntries = ignoreDirectivesCount +
        customExcludedFilesCount +
        disabledAnalyzersCount;
    return _ComplianceAreaScore(
      key: 'suppression_hygiene',
      label: 'Suppression hygiene',
      enabled: true,
      issueCount: suppressionEntries,
      score: _clampToUnitRange(1 - (penalty / _maxSuppressionPenaltyPoints)),
    );
  }

  double get _ignoreDirectiveBudget {
    final safeDartFileCount = math.max(1, totalDartFiles);
    final safeLoc = math.max(1, totalLinesOfCode);
    return math.max(
      _minIgnoreDirectiveBudget,
      safeDartFileCount * _ignoreDirectiveBudgetPerFile +
          safeLoc * _ignoreDirectiveBudgetPerLoc,
    );
  }

  double get _customExcludedFilesBudget {
    final scopeDartFiles =
        math.max(1, totalDartFiles + customExcludedFilesCount);
    return math.max(
      _minCustomExcludedFileBudget,
      scopeDartFiles * _customExcludedFileBudgetRatio,
    );
  }

  List<_ComplianceAreaScore> get _complianceAreas {
    final safeDartFileCount = math.max(1, totalDartFiles);
    final safeLoc = math.max(1, totalLinesOfCode);

    final oneClassPerFileViolations = fileMetrics
        .where((metric) => !metric.isOneClassPerFileCompliant)
        .length;

    final hardcodedBudget = math.max(
      _minHardcodedBudget,
      safeDartFileCount *
          (usesLocalization
              ? _localizedHardcodedBudgetPerFile
              : _nonLocalizedHardcodedBudgetPerFile),
    );
    final magicNumbersBudget = math.max(
      _minMagicNumberBudget,
      safeDartFileCount * _magicNumberBudgetPerFile +
          safeLoc * _magicNumberBudgetPerLoc,
    );
    final sourceSortingBudget = math.max(
      _minSourceSortBudget,
      safeDartFileCount * _sourceSortBudgetPerFile,
    );
    final layersBaseline = math.max(1, layersEdgeCount);
    final layersBudget = math.max(
      _minLayersBudget,
      layersBaseline * _layersBudgetPerEdge,
    );
    final deadCodeBudget = math.max(
      _minDeadCodeBudget,
      safeDartFileCount * _deadCodeBudgetPerFile,
    );
    final duplicateImpactLines = duplicateCodeIssues.fold<double>(
      0,
      (sum, issue) => sum + (issue.lineCount * issue.similarity),
    );
    final duplicateRatio = duplicateImpactLines / safeLoc;

    return [
      _ComplianceAreaScore(
        key: 'one_class_per_file',
        label: 'One class per file',
        enabled: oneClassPerFileAnalyzerEnabled,
        issueCount: oneClassPerFileViolations,
        score: _fractionScore(
          issues: oneClassPerFileViolations,
          total: safeDartFileCount,
        ),
      ),
      _ComplianceAreaScore(
        key: 'hardcoded_strings',
        label: 'Hardcoded strings',
        enabled: hardcodedStringsAnalyzerEnabled,
        issueCount: hardcodedStringIssues.length,
        score: _budgetScore(
          issues: hardcodedStringIssues.length,
          budget: hardcodedBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'magic_numbers',
        label: 'Magic numbers',
        enabled: magicNumbersAnalyzerEnabled,
        issueCount: magicNumberIssues.length,
        score: _budgetScore(
          issues: magicNumberIssues.length,
          budget: magicNumbersBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'source_sorting',
        label: 'Source sorting',
        enabled: sourceSortingAnalyzerEnabled,
        issueCount: sourceSortIssues.length,
        score: _budgetScore(
          issues: sourceSortIssues.length,
          budget: sourceSortingBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'layers',
        label: 'Layers architecture',
        enabled: layersAnalyzerEnabled,
        issueCount: layersIssues.length,
        score: _budgetScore(
          issues: layersIssues.length,
          budget: layersBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'secrets',
        label: 'Secrets',
        enabled: secretsAnalyzerEnabled,
        issueCount: secretIssues.length,
        score: _budgetScore(
          issues: secretIssues.length,
          budget: _secretsBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'dead_code',
        label: 'Dead code',
        enabled: deadCodeAnalyzerEnabled,
        issueCount: deadCodeIssues.length,
        score: _budgetScore(
          issues: deadCodeIssues.length,
          budget: deadCodeBudget,
        ),
      ),
      _ComplianceAreaScore(
        key: 'duplicate_code',
        label: 'Duplicate code',
        enabled: duplicateCodeAnalyzerEnabled,
        issueCount: duplicateCodeIssues.length,
        score: _clampToUnitRange(
            1 - (duplicateRatio * _duplicateRatioPenaltyMultiplier)),
      ),
    ];
  }

  /// Dead code issues classified as dead files.
  List<DeadCodeIssue> get deadFileIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadFile)
      .toList();

  /// Dead code issues classified as dead classes.
  List<DeadCodeIssue> get deadClassIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadClass)
      .toList();

  /// Dead code issues classified as dead functions.
  List<DeadCodeIssue> get deadFunctionIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.deadFunction)
      .toList();

  /// Dead code issues classified as unused variables.
  List<DeadCodeIssue> get unusedVariableIssues => deadCodeIssues
      .where((issue) => issue.type == DeadCodeIssueType.unusedVariable)
      .toList();

  /// Converts all secret issues to a JSON-compatible map.
  List<Map<String, dynamic>> get secretIssuesJson => secretIssues
      .map((issue) => {
            'filePath': issue.filePath,
            'lineNumber': issue.lineNumber,
            'secretType': issue.secretType,
            'value': issue.value,
          })
      .toList();
}

double _fractionScore({required int issues, required int total}) {
  if (total <= 0) {
    return 1;
  }
  return _clampToUnitRange(1 - (issues / total));
}

double _budgetScore({required int issues, required double budget}) {
  if (budget <= 0) {
    return 1;
  }
  return _clampToUnitRange(1 - (issues / budget));
}

double _overBudgetRatio({required double used, required double budget}) {
  if (budget <= 0) {
    return 0;
  }
  final overBudget = used - budget;
  if (overBudget <= 0) {
    return 0;
  }
  return overBudget / budget;
}

double _clampToUnitRange(double value) {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

class _ComplianceAreaScore {
  final String key;
  final String label;
  final bool enabled;
  final int issueCount;
  final double score;

  const _ComplianceAreaScore({
    required this.key,
    required this.label,
    required this.enabled,
    required this.issueCount,
    required this.score,
  });

  double get penaltyImpact => (1 - score);
}
