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
  String toString() {
    final location = filePath != null && lineNumber != null
        ? '$filePath:$lineNumber'
        : filePath ?? 'unknown location';
    return 'Secret issue at $location: $secretType';
  }
}
