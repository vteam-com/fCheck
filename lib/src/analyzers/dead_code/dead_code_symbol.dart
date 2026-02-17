/// Simple symbol metadata used for dead code analysis.
class DeadCodeSymbol {
  /// Symbol name as declared in source.
  final String name;

  /// 1-based line number of the declaration.
  final int lineNumber;

  /// Optional owner of the symbol (for example class name for methods).
  final String? owner;

  /// Creates symbol metadata for dead code analysis.
  const DeadCodeSymbol({
    required this.name,
    required this.lineNumber,
    this.owner,
  });
}
