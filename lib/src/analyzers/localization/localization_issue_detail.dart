import 'package:fcheck/src/analyzers/localization/localization_utils.dart';

/// Represents one localization problem tied to a specific ARB location.
class LocalizationIssueDetail {
  /// Creates a localization issue detail.
  const LocalizationIssueDetail({
    required this.filePath,
    required this.lineNumber,
    required this.key,
    required this.problemType,
  });

  /// ARB file path that should be shown to the user.
  final String filePath;

  /// 1-based line number for the ARB entry.
  final int lineNumber;

  /// Translation key associated with the problem.
  final String key;

  /// Reason this key is considered incomplete.
  final LocalizationTranslationProblemType problemType;

  /// Converts this detail to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'lineNumber': lineNumber,
    'key': key,
    'problemType': problemType.name,
  };
}
