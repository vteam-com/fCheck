import 'package:fcheck/src/input_output/issue_location_utils.dart';

/// Represents a secret issue found in the code.
///
/// This class contains information about a potential secret or sensitive
/// information that was detected during analysis.
class SecretIssue {
  /// The file path where the secret was found.
  final String? filePath;

  /// The line number where the secret was found.
  final int? lineNumber;

  /// The type of secret that was detected.
  final String? secretType;

  /// The actual secret value that was found.
  final String? value;

  /// Creates a new SecretIssue instance.
  SecretIssue({
    this.filePath,
    this.lineNumber,
    this.secretType,
    this.value,
  });

  /// Converts this secret issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'lineNumber': lineNumber,
        'secretType': secretType,
        'value': value,
      };

  @override
  String toString() => format();

  /// Returns a formatted issue line for CLI output.
  String format({int? lineNumberWidth}) {
    assertValidLineNumberWidth(lineNumberWidth);
    final location = _formatLocation();
    return 'Secret issue at $location: ${colorizeIssueArtifact('$secretType')}';
  }

  /// Internal helper used by fcheck analysis and reporting.
  String _formatLocation() {
    if (filePath == null) {
      return 'unknown location';
    }
    return resolveIssueLocation(rawPath: filePath!, lineNumber: lineNumber);
  }
}
