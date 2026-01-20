import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'hardcoded_string_issue.dart';
import 'hardcoded_string_visitor.dart';
import 'utils.dart';

/// Analyzer for detecting hardcoded strings in Dart files.
///
/// This class provides methods to analyze individual files or entire directories
/// for potentially hardcoded strings that may need localization or refactoring.
/// It uses the Dart analyzer to parse source code and identify string literals.
class HardcodedStringAnalyzer {
  /// Analyzes a single Dart file for hardcoded strings.
  ///
  /// This method parses the file using the Dart analyzer and identifies
  /// string literals that may be user-facing content that should be localized.
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a list of [HardcodedStringIssue] objects representing
  /// potential hardcoded strings found in the file. Returns an empty list
  /// if no issues are found or if the file cannot be analyzed.
  List<HardcodedStringIssue> analyzeFile(File file) {
    final String filePath = file.path;

    // Skip l10n generated files
    if (filePath.contains('lib/l10n/') || filePath.contains('.g.dart')) {
      return [];
    }

    final String content = file.readAsStringSync();

    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return [];
    }

    final CompilationUnit compilationUnit = result.unit;
    final HardcodedStringVisitor visitor = HardcodedStringVisitor(
      filePath,
      content,
    );
    compilationUnit.accept(visitor);

    return visitor.foundIssues;
  }

  /// Analyzes all Dart files in a directory for hardcoded strings.
  ///
  /// This method recursively scans the directory tree starting from [directory]
  /// and analyzes all `.dart` files found, excluding example/, test/, tool/,
  /// and build directories. Generated files (l10n, .g.dart) are
  /// automatically skipped.
  ///
  /// [directory] The root directory to scan.
  ///
  /// Returns a list of all [HardcodedStringIssue] objects found across
  /// all analyzed files in the directory.
  List<HardcodedStringIssue> analyzeDirectory(Directory directory) {
    final List<HardcodedStringIssue> allIssues = [];

    final List<File> dartFiles = FileUtils.listDartFiles(directory);

    for (final File file in dartFiles) {
      allIssues.addAll(analyzeFile(file));
    }

    return allIssues;
  }
}
