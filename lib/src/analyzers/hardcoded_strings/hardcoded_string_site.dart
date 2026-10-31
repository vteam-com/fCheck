import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_role.dart';

/// Where a hardcoded string sits in its source file, and what a tool needs
/// to replace it with a localized lookup.
///
/// Offsets are 0-based character offsets into the file content.
class HardcodedStringSite {
  /// Creates the site of a string expression spanning [offset] to
  /// [offset] + [length].
  const HardcodedStringSite({
    required this.offset,
    required this.length,
    required this.textParts,
    required this.interpolations,
    required this.isWidgetOutput,
    this.buildContextName,
    this.calleeName,
    this.argumentName,
    this.constKeywordOffsets = const [],
    this.role = HardcodedStringRole.unknown,
    this.roleEvidence = '',
  });

  /// Name of the named argument the string is passed as, such as `label`
  /// or `value`; null for a positional argument or no argument.
  final String? argumentName;

  /// Name of the constructor or method whose argument the string is, such
  /// as `Text` or `contains`, looking through parentheses, `?:` branches
  /// and `??`; null when the string is not an argument.
  final String? calleeName;

  /// Name of a `BuildContext` usable where the string is, such as
  /// `context`; null when none is in scope, like in models, static members,
  /// constructors, `initState` or constant positions.
  final String? buildContextName;

  /// Offsets of the `const` keywords of enclosing expressions, innermost
  /// first; they must go before the string can become a runtime lookup.
  final List<int> constKeywordOffsets;

  /// Source of each interpolated expression, in order; `${a.b}` gives
  /// `a.b`.
  final List<String> interpolations;

  /// Whether the string is passed directly to a widget.
  final bool isWidgetOutput;

  /// What the string is for, judged from how the code uses it.
  final HardcodedStringRole role;

  /// The use that decided [role], following the string through parameters,
  /// variables and returned values, such as
  /// `photoType → l10n.onlyDeleteOwnPhotos(…)`; empty when nothing did.
  final String roleEvidence;

  /// Length of the whole string expression, adjacent strings included.
  final int length;

  /// Offset of the whole string expression, adjacent strings included.
  final int offset;

  /// The string's text split around [interpolations], escapes resolved;
  /// always one more part than [interpolations].
  final List<String> textParts;
}
