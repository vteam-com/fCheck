/// Parsed and normalized issue location details.
class NormalizedIssueLocation {
  /// Normalized path with duplicated prefixes removed.
  final String path;

  /// Optional embedded line number parsed from the raw location.
  final int? embeddedLine;

  /// Creates a normalized issue location value.
  const NormalizedIssueLocation({
    required this.path,
    required this.embeddedLine,
  });
}

final RegExp _duplicatedPathPattern = RegExp(r'^(.+):\1$');
final RegExp _embeddedLinePattern = RegExp(r'^(.*):(\d+)$');
const int _pathCaptureGroupIndex = 1;
const int _lineCaptureGroupIndex = 2;
const String _lineNumberWidthAssertionMessage =
    'lineNumberWidth must be positive when provided.';

/// Normalizes a raw path/location by:
/// - trimming whitespace
/// - removing a trailing `:`
/// - extracting an embedded trailing line number (`path:12`)
/// - collapsing duplicated path prefixes (`path:path`)
NormalizedIssueLocation normalizeIssueLocation(String rawPath) {
  var normalized = rawPath.trim();
  if (normalized.endsWith(':')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }

  int? embeddedLine;
  final embeddedLineMatch = _embeddedLinePattern.firstMatch(normalized);
  if (embeddedLineMatch != null) {
    final parsedLine =
        int.tryParse(embeddedLineMatch.group(_lineCaptureGroupIndex) ?? '');
    if (parsedLine != null) {
      embeddedLine = parsedLine;
      normalized =
          embeddedLineMatch.group(_pathCaptureGroupIndex) ?? normalized;
    }
  }

  while (true) {
    final duplicatedPathMatch = _duplicatedPathPattern.firstMatch(normalized);
    if (duplicatedPathMatch == null) {
      break;
    }
    final deduplicated = duplicatedPathMatch.group(_pathCaptureGroupIndex);
    if (deduplicated == null || deduplicated == normalized) {
      break;
    }
    normalized = deduplicated;
  }

  if (normalized.endsWith(':')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }

  return NormalizedIssueLocation(path: normalized, embeddedLine: embeddedLine);
}

/// Asserts that [lineNumberWidth] is either null or positive.
void assertValidLineNumberWidth(int? lineNumberWidth) {
  assert(
    lineNumberWidth == null || lineNumberWidth > 0,
    _lineNumberWidthAssertionMessage,
  );
}

/// Returns a normalized `path:line` string for issue output.
///
/// If [lineNumber] is not positive, the embedded line from [rawPath] is used
/// when available; otherwise the original [lineNumber] is retained.
String resolveIssueLocationWithLine({
  required String rawPath,
  required int lineNumber,
}) {
  final normalizedLocation = normalizeIssueLocation(rawPath);
  final effectiveLineNumber = lineNumber > 0
      ? lineNumber
      : (normalizedLocation.embeddedLine ?? lineNumber);
  return '${normalizedLocation.path}:$effectiveLineNumber';
}

/// Returns a normalized issue location with an optional line number.
///
/// When [strictPositiveLineNumber] is true, non-positive [lineNumber] values
/// are ignored and replaced by any embedded line from [rawPath].
String resolveIssueLocation({
  required String rawPath,
  int? lineNumber,
  bool strictPositiveLineNumber = false,
}) {
  final normalizedLocation = normalizeIssueLocation(rawPath);
  final explicitLineNumber = strictPositiveLineNumber
      ? (lineNumber != null && lineNumber > 0 ? lineNumber : null)
      : lineNumber;
  final effectiveLineNumber =
      explicitLineNumber ?? normalizedLocation.embeddedLine;
  if (effectiveLineNumber == null) {
    return normalizedLocation.path;
  }
  return '${normalizedLocation.path}:$effectiveLineNumber';
}
