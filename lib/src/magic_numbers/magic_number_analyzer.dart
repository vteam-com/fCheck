import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import 'magic_number_issue.dart';
import 'magic_number_visitor.dart';
import '../models/file_utils.dart';

/// Analyzer that detects magic number literals in Dart source files.
class MagicNumberAnalyzer {
  /// Creates a new [MagicNumberAnalyzer].
  MagicNumberAnalyzer();

  /// Analyzes a single Dart file for magic number issues.
  List<MagicNumberIssue> analyzeFile(File file) {
    final filePath = file.path;

    final content = file.readAsStringSync();
    if (_shouldSkipFile(filePath) || _hasIgnoreMagicNumbersDirective(content)) {
      return [];
    }
    final result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    if (result.errors.isNotEmpty) {
      return [];
    }

    final visitor = MagicNumberVisitor(filePath, content);
    result.unit.accept(visitor);

    return visitor.foundIssues;
  }

  /// Analyzes every Dart file in [directory], respecting exclude patterns.
  List<MagicNumberIssue> analyzeDirectory(
    Directory directory, {
    List<String> excludePatterns = const [],
  }) {
    final issues = <MagicNumberIssue>[];

    final dartFiles = FileUtils.listDartFiles(
      directory,
      excludePatterns: excludePatterns,
    );

    for (final file in dartFiles) {
      issues.addAll(analyzeFile(file));
    }

    return issues;
  }

  bool _shouldSkipFile(String path) {
    return path.contains('lib/l10n/') || path.contains('.g.dart');
  }

  /// Checks for a top-of-file directive to ignore magic numbers analysis.
  ///
  /// The directive must appear in the leading comment block(s) at the top of
  /// the file (before any code). Example:
  /// ```dart
  /// // fcheck - ignore magic numbers
  /// ```
  bool _hasIgnoreMagicNumbersDirective(String content) {
    final directive = RegExp(
      r'fcheck:\s*ignore[-_ ]*magic[-_ ]*numbers|fcheck\s*-\s*ignore\s*magic\s*numbers',
      caseSensitive: false,
    );

    final lines = content.split('\n');
    final buffer = StringBuffer();
    bool inBlockComment = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();

      if (inBlockComment) {
        buffer.writeln(trimmed);
        final endIndex = trimmed.indexOf('*/');
        if (endIndex != -1) {
          inBlockComment = false;
          final after = trimmed.substring(endIndex + 2).trim();
          if (after.isNotEmpty) {
            break;
          }
        }
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith('//')) {
        buffer.writeln(trimmed);
        continue;
      }

      if (trimmed.startsWith('/*')) {
        buffer.writeln(trimmed);
        if (!trimmed.contains('*/')) {
          inBlockComment = true;
        } else {
          final after = trimmed.split('*/').last.trim();
          if (after.isNotEmpty) {
            break;
          }
        }
        continue;
      }

      break;
    }

    return directive.hasMatch(buffer.toString());
  }
}
