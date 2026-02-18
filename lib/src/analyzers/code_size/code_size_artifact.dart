/// Kinds of code entities measured by code-size analysis.
enum CodeSizeArtifactKind {
  /// Whole source file.
  file('file'),

  /// Class declaration.
  classDeclaration('class'),

  /// Top-level or local function declaration.
  function('function'),

  /// Class method or constructor declaration.
  method('method');

  const CodeSizeArtifactKind(this.label);

  /// Short machine-readable label used in output formats.
  final String label;
}

/// A measurable source artifact (file/class/function/method) with LOC details.
class CodeSizeArtifact {
  /// Artifact kind.
  final CodeSizeArtifactKind kind;

  /// Display name of the artifact.
  final String name;

  /// Source file containing this artifact.
  final String filePath;

  /// Non-empty line count for the artifact range.
  final int linesOfCode;

  /// Inclusive start line in [filePath].
  final int startLine;

  /// Inclusive end line in [filePath].
  final int endLine;

  /// Optional container (for methods declared in a class).
  final String? ownerName;

  /// Creates a code-size artifact.
  const CodeSizeArtifact({
    required this.kind,
    required this.name,
    required this.filePath,
    required this.linesOfCode,
    required this.startLine,
    required this.endLine,
    this.ownerName,
  });

  /// Stable identifier for de-duplication and map keys.
  String get stableId => '$filePath|${kind.label}|$name|$startLine|$endLine';

  /// Name prefixed with owner when present (for methods).
  String get qualifiedName =>
      ownerName == null || ownerName!.isEmpty ? name : '$ownerName.$name';

  /// Whether this artifact is a callable unit (function or method).
  bool get isCallable =>
      kind == CodeSizeArtifactKind.function ||
      kind == CodeSizeArtifactKind.method;

  /// Converts this artifact to JSON.
  Map<String, dynamic> toJson() => {
        'kind': kind.label,
        'name': name,
        'qualifiedName': qualifiedName,
        'filePath': filePath,
        'linesOfCode': linesOfCode,
        'startLine': startLine,
        'endLine': endLine,
        if (ownerName != null) 'ownerName': ownerName,
      };
}
