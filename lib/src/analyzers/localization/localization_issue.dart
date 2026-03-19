import 'package:fcheck/src/analyzers/localization/localization_issue_detail.dart';
import 'package:fcheck/src/analyzers/localization/localization_utils.dart';

/// Represents a localization coverage issue.
///
/// This class encapsulates information about missing translations or
/// localization inconsistencies found during analysis.
class LocalizationIssue {
  /// Constant for 100% coverage percentage.
  static const double _fullCoveragePercentage = 100.0;
  static const int _maxProblemSummaryItems = 3;

  /// The language code that has missing translations (e.g., 'es', 'fr').
  final String languageCode;

  /// The language name (e.g., 'Spanish', 'French').
  final String languageName;

  /// The number of missing translations for this language.
  final int missingCount;

  /// The total number of strings in the base language (typically English).
  final int totalCount;

  /// Counts of problem types that affected this locale.
  final Map<LocalizationTranslationProblemType, int> problemCounts;

  /// Detailed locations for each incomplete translation.
  final List<LocalizationIssueDetail> details;

  /// The percentage of translations present (0.0 to 100.0).
  final double coveragePercentage;

  /// Creates a new localization issue.
  ///
  /// [languageCode] should be the ISO language code.
  /// [languageName] should be the display name of the language.
  /// [missingCount] should be the count of missing translations.
  /// [totalCount] should be the total strings in the base language.
  /// [problemCounts] should map incomplete translation reasons to counts.
  /// [details] should list individual file/line findings for this locale.
  LocalizationIssue({
    required this.languageCode,
    required this.languageName,
    required this.missingCount,
    required this.totalCount,
    this.problemCounts = const {},
    this.details = const [],
  }) : coveragePercentage = totalCount > 0
           ? double.parse(
               (((totalCount - missingCount.clamp(0, totalCount)) /
                           totalCount) *
                       _fullCoveragePercentage)
                   .toStringAsFixed(1),
             )
           : _fullCoveragePercentage;

  /// Returns a string representation of this localization issue.
  ///
  /// The format shows language, coverage percentage, and missing count.
  @override
  String toString() => format();

  /// Returns a formatted issue line for CLI output.
  String format() {
    final coverageStr = coveragePercentage.toStringAsFixed(1);
    final problemSummary = problemSummaryText();
    return '$languageName ($languageCode): $coverageStr% coverage ($problemSummary)';
  }

  /// Returns a human-readable summary of the problem counts.
  String problemSummaryText() {
    if (problemCounts.isEmpty) {
      return missingCount <= 0 ? 'complete' : '$missingCount missing';
    }

    final orderedEntries = problemCounts.entries.toList()
      ..sort((left, right) => left.key.index.compareTo(right.key.index));
    final visibleEntries = orderedEntries.take(_maxProblemSummaryItems);
    final totalProblemCount = orderedEntries.fold<int>(
      0,
      (total, entry) => total + entry.value,
    );
    final summaryParts = <String>[
      '$totalProblemCount issue${totalProblemCount == 1 ? '' : 's'}',
      for (final entry in visibleEntries)
        '${entry.value} ${localizationProblemLabel(entry.key)}',
    ];
    if (orderedEntries.length > _maxProblemSummaryItems) {
      summaryParts.add(
        'and ${orderedEntries.length - _maxProblemSummaryItems} more',
      );
    }
    return summaryParts.join(': ');
  }

  /// Converts this issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'languageName': languageName,
    'missingCount': missingCount,
    'totalCount': totalCount,
    'problemCounts': {
      for (final entry in problemCounts.entries) entry.key.name: entry.value,
    },
    'details': details.map((detail) => detail.toJson()).toList(),
    'coveragePercentage': coveragePercentage,
  };
}
