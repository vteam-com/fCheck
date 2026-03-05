/// A single in-file ignore directive location.
class IgnoreDirectiveLocation {
  /// Relative file path from the analyzed root.
  final String path;

  /// One-based line number in the file.
  final int line;

  /// Normalized directive token (for example `fcheck_magic_numbers`).
  final String token;

  /// Original comment line text where the directive was found.
  final String rawLine;

  /// Creates a directive location entry.
  const IgnoreDirectiveLocation({
    required this.path,
    required this.line,
    required this.token,
    required this.rawLine,
  });

  /// Serializes this entry for JSON CLI output.
  Map<String, Object> toJson() => {
    'path': path,
    'line': line,
    'token': token,
    'rawLine': rawLine,
  };
}
