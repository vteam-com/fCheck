import 'package:fcheck/src/models/ignore_directive_location.dart';

/// Structured inventory of ignore/suppression configuration sources.
class IgnoreInventory {
  /// Path to `.fcheck` if present.
  final String? configFilePath;

  /// Patterns configured under `.fcheck` `input.exclude`.
  final List<String> configExcludePatterns;

  /// Analyzer names configured under `.fcheck` `analyzers.disabled`.
  final List<String> analyzersDisabled;

  /// Analyzer names configured under legacy `.fcheck` `ignores.*: true`.
  final List<String> analyzersIgnoredLegacy;

  /// In-code comment directives found in Dart files.
  final List<IgnoreDirectiveLocation> dartCommentDirectives;

  /// Creates an ignore inventory snapshot.
  const IgnoreInventory({
    required this.configFilePath,
    required this.configExcludePatterns,
    required this.analyzersDisabled,
    required this.analyzersIgnoredLegacy,
    required this.dartCommentDirectives,
  });

  /// Returns Dart comment directives grouped by token type.
  Map<String, List<IgnoreDirectiveLocation>> get dartCommentDirectivesByType {
    final grouped = <String, List<IgnoreDirectiveLocation>>{};
    for (final directive in dartCommentDirectives) {
      grouped.putIfAbsent(directive.token, () => <IgnoreDirectiveLocation>[]);
      grouped[directive.token]!.add(directive);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<IgnoreDirectiveLocation>>{};
    for (final key in sortedKeys) {
      final items = [...grouped[key]!]
        ..sort((left, right) {
          final pathCompare = left.path.compareTo(right.path);
          if (pathCompare != 0) {
            return pathCompare;
          }
          return left.line.compareTo(right.line);
        });
      sortedGrouped[key] = List<IgnoreDirectiveLocation>.unmodifiable(items);
    }
    return Map<String, List<IgnoreDirectiveLocation>>.unmodifiable(
      sortedGrouped,
    );
  }

  /// Serializes inventory for JSON CLI output.
  Map<String, Object?> toJson() => {
    'configFilePath': configFilePath,
    'config': {
      'excludePatterns': configExcludePatterns,
      'analyzersDisabled': analyzersDisabled,
    },
    'dartCommentDirectives': dartCommentDirectives
        .map((directive) => directive.toJson())
        .toList(growable: false),
    'groupedByType': {
      'excludePatterns': configExcludePatterns,
      'analyzersDisabled': analyzersDisabled,
      'dartCommentDirectives': dartCommentDirectivesByType.map(
        (token, entries) => MapEntry(
          token,
          entries
              .map((directive) => directive.toJson())
              .toList(growable: false),
        ),
      ),
    },
    'totals': {
      'configExcludePatterns': configExcludePatterns.length,
      'analyzersDisabled': analyzersDisabled.length,
      'dartCommentDirectives': dartCommentDirectives.length,
    },
  };
}
