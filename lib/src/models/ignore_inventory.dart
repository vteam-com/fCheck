import 'dart:io';

import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_directive_location.dart';
import 'package:fcheck/src/models/ignore_inventory_model.dart';
import 'package:path/path.dart' as p;

export 'package:fcheck/src/models/ignore_directive_location.dart';
export 'package:fcheck/src/models/ignore_inventory_model.dart';

const int _lineCommentPrefixLength = 2;
const int _lineNumberStart = 1;
const bool _doNotFollowLinks = false;

final RegExp _lineIgnorePattern = RegExp(
  r'^\s*ignore\s*:\s*(.+)$',
  caseSensitive: false,
);
final RegExp _fcheckDirectiveTokenPattern = RegExp(
  r'\bfcheck_[a-z_]+\b',
  caseSensitive: false,
);
final RegExp _lineIgnoreForFilePattern = RegExp(
  r'^\s*ignore_for_file\s*:\s*(.+)$',
  caseSensitive: false,
);
final RegExp _hardcodedStringsIgnoreForFileTokenPattern = RegExp(
  r'\bavoid_hardcoded_strings_in_widgets\b',
  caseSensitive: false,
);

/// Collects all configured ignore sources for the current project.
IgnoreInventory collectIgnoreInventory({
  required Directory rootDirectory,
  required FcheckConfig fcheckConfig,
}) {
  final dartFiles = rootDirectory
      .listSync(recursive: true, followLinks: _doNotFollowLinks)
      .whereType<File>()
      .where((file) => p.extension(file.path) == '.dart')
      .toList(growable: false);

  final directives = <IgnoreDirectiveLocation>[];
  for (final file in dartFiles) {
    final relativePath = p.relative(file.path, from: rootDirectory.path);
    directives.addAll(
      _collectDartIgnoreDirectives(
        content: file.readAsStringSync(),
        relativePath: relativePath,
      ),
    );
  }

  final sortedDirectives = [...directives]
    ..sort((left, right) {
      final pathCompare = left.path.compareTo(right.path);
      if (pathCompare != 0) {
        return pathCompare;
      }
      final lineCompare = left.line.compareTo(right.line);
      if (lineCompare != 0) {
        return lineCompare;
      }
      return left.token.compareTo(right.token);
    });

  final disabled =
      fcheckConfig.analyzersDisabledInConfig
          .map((analyzer) => analyzer.configName)
          .toList(growable: false)
        ..sort();
  final legacy =
      fcheckConfig.analyzersIgnoredLegacy
          .map((analyzer) => analyzer.configName)
          .toList(growable: false)
        ..sort();
  final excludes = [...fcheckConfig.excludePatterns]..sort();
  final configFile = fcheckConfig.sourceFile;
  final configFilePath = configFile == null
      ? null
      : p.relative(configFile.path, from: rootDirectory.path);

  return IgnoreInventory(
    configFilePath: configFilePath,
    configExcludePatterns: excludes,
    analyzersDisabled: disabled,
    analyzersIgnoredLegacy: legacy,
    dartCommentDirectives: sortedDirectives,
  );
}

/// Collects ignore directives from Dart file content.
///
/// Parses the file content line by line to find:
/// - `// ignore: fcheck_*` directives for specific lines
/// - `// ignore_for_file: fcheck_*` directives for entire files
/// - `// ignore_for_file: avoid_hardcoded_strings_in_widgets` legacy directive
///
/// Returns a list of [IgnoreDirectiveLocation] entries for all found directives.
List<IgnoreDirectiveLocation> _collectDartIgnoreDirectives({
  required String content,
  required String relativePath,
}) {
  final directives = <IgnoreDirectiveLocation>[];
  final lines = content.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final lineNumber = index + _lineNumberStart;
    final line = lines[index];
    final commentIndex = line.indexOf('//');
    if (commentIndex < 0) {
      continue;
    }

    final commentBody = line.substring(commentIndex + _lineCommentPrefixLength);
    final rawLine = line.trim();

    final lineIgnoreMatch = _lineIgnorePattern.firstMatch(commentBody);
    if (lineIgnoreMatch != null) {
      final directivesRaw = lineIgnoreMatch.group(1) ?? '';
      for (final tokenMatch in _fcheckDirectiveTokenPattern.allMatches(
        directivesRaw,
      )) {
        final token = tokenMatch.group(0);
        if (token == null || token.isEmpty) {
          continue;
        }
        directives.add(
          IgnoreDirectiveLocation(
            path: relativePath,
            line: lineNumber,
            token: token.toLowerCase(),
            rawLine: rawLine,
          ),
        );
      }
    }

    final lineIgnoreForFileMatch = _lineIgnoreForFilePattern.firstMatch(
      commentBody,
    );
    if (lineIgnoreForFileMatch == null) {
      continue;
    }

    final ignoreForFileDirectives = lineIgnoreForFileMatch.group(1) ?? '';
    if (_hardcodedStringsIgnoreForFileTokenPattern.hasMatch(
      ignoreForFileDirectives,
    )) {
      directives.add(
        IgnoreDirectiveLocation(
          path: relativePath,
          line: lineNumber,
          token: 'avoid_hardcoded_strings_in_widgets',
          rawLine: rawLine,
        ),
      );
    }
  }

  return directives;
}
