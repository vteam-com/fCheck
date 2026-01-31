import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import 'magic_number_issue.dart';
import 'magic_number_visitor.dart';
import '../models/file_utils.dart';
import '../config/config_ignore_directives.dart';

/// Analyzer that detects magic number literals in Dart source files.
class MagicNumberAnalyzer {
  /// Creates a new [MagicNumberAnalyzer].
  MagicNumberAnalyzer();

  /// Analyzes a single Dart file for magic number issues.
  List<MagicNumberIssue> analyzeFile(File file) {
    final filePath = file.path;

    final content = file.readAsStringSync();
    if (_shouldSkipFile(filePath) ||
        ConfigIgnoreDirectives.hasIgnoreDirective(content, 'magic_numbers')) {
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
}
