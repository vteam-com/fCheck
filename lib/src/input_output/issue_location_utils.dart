import 'dart:io';

import 'package:path/path.dart' as p;

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

bool _disableAnsiColorsFromCli = false;

/// Configures ANSI color usage from CLI flags.
void configureCliColorOutput({required bool disableColors}) {
  _disableAnsiColorsFromCli = disableColors;
}

/// Returns whether ANSI colors should be used for console output.
bool get supportsCliAnsiColors {
  if (_disableAnsiColorsFromCli) {
    return false;
  }
  if (_isNoColorEnvironmentEnabled(Platform.environment)) {
    return false;
  }
  return stdout.hasTerminal && stdout.supportsAnsiEscapes;
}

bool get _supportsAnsiEscapes => supportsCliAnsiColors;

/// Returns whether current environment variables request disabling colors.
bool isNoColorEnvironmentEnabled(Map<String, String> env) {
  if (env.containsKey('NO_COLOR')) {
    return true;
  }
  return _isTruthyNoColorsValue(env['NO_COLORS']) ||
      _isTruthyNoColorsValue(env['no-colors']) ||
      _isTruthyNoColorsValue(env['NO-COLORS']) ||
      _isTruthyNoColorsValue(env['no_colors']);
}

bool _isNoColorEnvironmentEnabled(Map<String, String> env) =>
    isNoColorEnvironmentEnabled(env);

/// Interprets NO_COLORS-style flag values as boolean-like "true".
///
/// Empty values are treated as enabled, while common false-like tokens
/// (`0`, `false`, `off`, `no`) are treated as disabled.
bool _isTruthyNoColorsValue(String? value) {
  if (value == null) {
    return false;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return normalized != '0' &&
      normalized != 'false' &&
      normalized != 'off' &&
      normalized != 'no';
}

String _colorizeBlueDark(String text) =>
    _supportsAnsiEscapes ? '\x1B[38;5;24m$text\x1B[0m' : text;

String _colorizeBlueBright(String text) =>
    _supportsAnsiEscapes ? '\x1B[38;5;45m$text\x1B[0m' : text;

String _colorizeOrange(String text) =>
    _supportsAnsiEscapes ? '\x1B[38;5;208m$text\x1B[0m' : text;

/// Colors the directory prefix dark blue and the filename token bright blue.
///
/// Examples:
/// - `lib/src/file.dart:12` ->
///   `<dark-blue>lib/src/</dark-blue><bright-blue>file.dart</bright-blue>:12`
/// - `/tmp/output.svg` ->
///   `<dark-blue>/tmp/</dark-blue><bright-blue>output.svg</bright-blue>`
String colorizePathFilename(String location) {
  if (!_supportsAnsiEscapes || location.isEmpty) {
    return location;
  }

  final lastSlash = location.lastIndexOf('/');
  final lastBackslash = location.lastIndexOf(r'\');
  final separatorIndex = lastSlash > lastBackslash ? lastSlash : lastBackslash;
  final filenameStart = separatorIndex + 1;
  if (filenameStart >= location.length) {
    return location;
  }

  final suffixStart = location.indexOf(':', filenameStart);
  final filenameEnd = suffixStart == -1 ? location.length : suffixStart;
  if (filenameEnd <= filenameStart) {
    return location;
  }

  final prefix = location.substring(0, filenameStart);
  final filename = location.substring(filenameStart, filenameEnd);
  final suffix = location.substring(filenameEnd);
  return '${_colorizeBlueDark(prefix)}${_colorizeBlueBright(filename)}$suffix';
}

/// Colors the offending artifact text (symbol/value) in orange.
String colorizeIssueArtifact(String text) {
  if (!_supportsAnsiEscapes || text.isEmpty) {
    return text;
  }
  return _colorizeOrange(text);
}

/// Converts absolute paths under the current working directory to relative.
String _relativizeToCurrentDirectory(String rawPath) {
  final normalizedPath = p.normalize(rawPath);
  if (!p.isAbsolute(normalizedPath)) {
    return normalizedPath;
  }

  final currentDirectory = p.normalize(Directory.current.absolute.path);
  if (normalizedPath == currentDirectory) {
    return '.';
  }
  if (p.isWithin(currentDirectory, normalizedPath)) {
    return p.relative(normalizedPath, from: currentDirectory);
  }

  return normalizedPath;
}

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

  normalized = _relativizeToCurrentDirectory(normalized);

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
  return colorizePathFilename(
    '${normalizedLocation.path}:$effectiveLineNumber',
  );
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
    return colorizePathFilename(normalizedLocation.path);
  }
  return colorizePathFilename(
    '${normalizedLocation.path}:$effectiveLineNumber',
  );
}
