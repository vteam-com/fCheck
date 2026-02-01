// ignore: fcheck_secrets

// A Flutter/Dart code quality analysis tool.
//
// This library provides functionality to analyze Flutter and Dart projects
// for code quality metrics including:
// - File and folder counts
// - Lines of code metrics
// - Comment ratio analysis
// - One class per file rule compliance
// - Hardcoded string detection
// - Source code member sorting validation
//
// Usage:
// ```dart
// import 'package:fcheck/fcheck.dart';
//
// final engine = AnalyzeFolder(projectDirectory);
// final metrics = engine.analyze();
// metrics.printReport();
// ```

import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/layers/layers_results.dart';
import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:fcheck/src/secrets/secret_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'src/hardcoded_strings/hardcoded_string_analyzer.dart';
import 'src/layers/layers_analyzer.dart';
import 'src/magic_numbers/magic_number_analyzer.dart';
import 'src/sort/sort.dart';
import 'src/metrics/project_metrics.dart';
import 'src/models/file_utils.dart';
import 'src/config/config_ignore_directives.dart';

/// The main engine for analyzing Flutter/Dart project quality.
///
/// This class provides comprehensive analysis of Dart projects, examining
/// code metrics, comment ratios, and compliance with coding standards.
/// It uses the Dart analyzer to parse source code and extract meaningful
/// quality metrics.
class AnalyzeFolder {
  /// The root directory of the project to analyze.
  final Directory projectDir;

  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// List of glob patterns to exclude from analysis.
  final List<String> excludePatterns;

  /// Creates a new analyzer engine for the specified project directory.
  ///
  /// [projectDir] should point to the root of a Flutter/Dart project.
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  /// [excludePatterns] optional list of glob patterns to exclude files/folders.
  /// [ignoreConfig] optional configuration for global ignores.
  AnalyzeFolder(
    this.projectDir, {
    this.fix = false,
    this.excludePatterns = const [],
    this.ignoreConfig = const {},
  });

  /// Global ignore configuration from .fcheck file and constructor.
  final Map<String, bool> ignoreConfig;

  /// Analyzes the layers architecture and returns the result.
  ///
  /// This method performs dependency analysis and layer assignment
  /// for the project.
  ///
  /// Returns a [LayersAnalysisResult] containing issues and layer assignments.
  LayersAnalysisResult analyzeLayers() {
    final layersAnalyzer = LayersAnalyzer(projectDir);
    return layersAnalyzer.analyzeDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );
  }

  /// Analyzes the entire project and returns comprehensive quality metrics.
  ///
  /// This method:
  /// - Finds all Dart files in the project
  /// - Analyzes each file individually
  /// - Aggregates metrics across all files
  /// - Returns a [ProjectMetrics] object with the complete analysis
  ///
  /// Returns a [ProjectMetrics] instance containing aggregated quality metrics
  /// for the entire project.
  ProjectMetrics analyze() {
    // Calculate excluded files count by comparing total vs filtered
    final allDartFiles = FileUtils.listDartFiles(projectDir);
    final dartFiles = FileUtils.listDartFiles(
      projectDir,
      excludePatterns: excludePatterns,
    );
    final excludedCount = allDartFiles.length - dartFiles.length;
    final projectVersion = _readProjectVersion(projectDir);
    final projectName = _readProjectName(projectDir);

    final fileMetricsList = <FileMetrics>[];

    int totalLoc = 0;
    int totalComments = 0;

    for (var file in dartFiles) {
      final metrics = analyzeFile(file);
      fileMetricsList.add(metrics);
      totalLoc += metrics.linesOfCode;
      totalComments += metrics.commentLines;
    }

    // Analyze for hardcoded strings
    final hardcodedStringAnalyzer = HardcodedStringAnalyzer();
    final hardcodedStringIssues = hardcodedStringAnalyzer.analyzeDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );

    // Analyze for magic numbers
    final magicNumberAnalyzer = MagicNumberAnalyzer();
    final magicNumberIssues = magicNumberAnalyzer.analyzeDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );

    // Analyze for source sorting issues
    final sourceSortAnalyzer = SourceSortAnalyzer();
    final sourceSortIssues = sourceSortAnalyzer.analyzeDirectory(
      projectDir,
      fix: fix,
      excludePatterns: excludePatterns,
    );

    // Analyze for layers architecture violations
    final layersAnalyzer = LayersAnalyzer(projectDir);
    final layersResult = layersAnalyzer.analyzeDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );

    // Analyze for secrets
    // ignore: fcheck_secrets
    final secretAnalyzer = SecretAnalyzer();
    final secretIssues = secretAnalyzer.analyzeDirectory(
      projectDir,
      excludePatterns: excludePatterns,
    );

    final usesLocalization = detectLocalization(dartFiles);

    return ProjectMetrics(
      totalFolders: FileUtils.countFolders(projectDir),
      totalFiles: FileUtils.countAllFiles(projectDir),
      totalDartFiles: dartFiles.length,
      totalLinesOfCode: totalLoc,
      totalCommentLines: totalComments,
      fileMetrics: fileMetricsList,
      hardcodedStringIssues: hardcodedStringIssues,
      magicNumberIssues: magicNumberIssues,
      sourceSortIssues: sourceSortIssues,
      layersIssues: layersResult.issues,
      layersEdgeCount: layersResult.edgeCount,
      layersCount: layersResult.layerCount,
      dependencyGraph: layersResult.dependencyGraph,
      projectName: projectName,
      version: projectVersion,
      usesLocalization: usesLocalization,
      excludedFilesCount: excludedCount,
      secretIssues: secretIssues,
    );
  }

  /// Analyzes a single Dart file and returns its metrics.
  ///
  /// This method parses a single Dart file using the Dart analyzer and
  /// extracts quality metrics including:
  /// - Lines of code
  /// - Comment lines
  /// - Class count
  /// - StatefulWidget detection
  /// - One class per file compliance
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a [FileMetrics] object containing quality metrics for the file.
  FileMetrics analyzeFile(File file) {
    final content = file.readAsStringSync();
    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    final hasIgnoreDirective = hasIgnoreOneClassPerFileDirective(content);

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return FileMetrics(
        path: file.path,
        linesOfCode: 0,
        commentLines: 0,
        classCount: 0,
        isStatefulWidget: false,
        ignoreOneClassPerFile: hasIgnoreDirective,
      );
    }

    final CompilationUnit unit = result.unit;
    final List<String> lines = content.split('\n');
    final int commentLines = countCommentLines(unit, lines);
    final _QualityVisitor visitor = _QualityVisitor();
    unit.accept(visitor);

    return FileMetrics(
      path: file.path,
      linesOfCode: lines.length,
      commentLines: commentLines,
      classCount: visitor.classCount,
      isStatefulWidget: visitor.hasStatefulWidget,
      ignoreOneClassPerFile: hasIgnoreDirective,
    );
  }

  /// Reads the project name from pubspec.yaml.
  ///
  /// This method looks for the 'name' field in the pubspec.yaml file
  /// and returns it. Searches up the directory tree from the given directory.
  /// Returns 'unknown' if the file cannot be read or the name field is missing.
  ///
  /// [projectDir] The directory to start searching from.
  ///
  /// Returns the project name as defined in pubspec.yaml or 'unknown'.
  String _readProjectName(Directory projectDir) {
    Directory? currentDir = projectDir;

    // Search up the directory tree for pubspec.yaml
    while (currentDir != null) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        try {
          final yaml = loadYaml(pubspecFile.readAsStringSync());
          return yaml['name'] ?? 'unknown';
        } catch (e) {
          return 'unknown';
        }
      }

      // Move up to parent directory
      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        // We've reached the root directory
        break;
      }
      currentDir = parent;
    }

    return 'unknown';
  }

  /// Reads the project version from pubspec.yaml.
  ///
  /// This method looks for the 'version' field in the pubspec.yaml file
  /// and returns it. Searches up the directory tree from the given directory.
  /// Returns 'unknown' if the file cannot be read or the version field is missing.
  ///
  /// [projectDir] The directory to start searching from.
  ///
  /// Returns the project version as defined in pubspec.yaml or 'unknown'.
  String _readProjectVersion(Directory projectDir) {
    Directory? currentDir = projectDir;

    // Search up the directory tree for pubspec.yaml
    while (currentDir != null) {
      final pubspecFile = File(p.join(currentDir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        try {
          final yaml = loadYaml(pubspecFile.readAsStringSync());
          return yaml['version'] ?? 'unknown';
        } catch (e) {
          return 'unknown';
        }
      }

      // Move up to parent directory
      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        // We've reached the root directory
        break;
      }
      currentDir = parent;
    }

    return 'unknown';
  }

  /// Counts the number of comment lines in a Dart file.
  ///
  /// This method counts lines that contain Dart comment markers:
  /// - `//` (single-line or documentation comments)
  /// - `/*` (start of block comment)
  /// - `*/` (end of block comment)
  ///
  /// It counts a line as a comment line if it starts with a marker or
  /// contains a marker (even if preceded by code).
  ///
  /// [unit] The parsed compilation unit (currently unused in this implementation).
  /// [lines] The raw lines of the file.
  ///
  /// Returns the number of lines that contain comments.
  int countCommentLines(CompilationUnit unit, List<String> lines) {
    // This is a simplified comment counter.
    // The analyzer's beginToken/endToken are useful for more complex scenarios.
    // We'll count lines that contain comments.
    int count = 0;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('/*') ||
          trimmed.endsWith('*/')) {
        count++;
      } else if (trimmed.contains('//') || trimmed.contains('/*')) {
        // Part of the line is a comment
        count++;
      }
    }
    return count;
  }

  /// Checks for a top-of-file directive to ignore the "one class per file" rule.
  ///
  /// The directive must appear in the leading comment block(s) at the top of
  /// the file (before any code). Example:
  /// ```dart
  /// // ignore: fcheck_one_class_per_file
  /// ```
  bool hasIgnoreOneClassPerFileDirective(String content) {
    return ConfigIgnoreDirectives.hasIgnoreDirective(
        content, 'one_class_per_file');
  }

  /// Heuristically detects whether the project uses Flutter localization.
  ///
  /// Signals localization when:
  /// - `l10n.yaml` exists, or
  /// - `.arb` files are present (commonly under lib/l10n), or
  /// - Source files reference `AppLocalizations` / `flutter_gen/gen_l10n`.
  bool detectLocalization(List<File> dartFiles) {
    final l10nConfig = File(p.join(projectDir.path, 'l10n.yaml'));
    if (l10nConfig.existsSync()) {
      // print('Localization detected: found l10n.yaml at ${l10nConfig.path}');
      return true;
    }

    final l10nDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    if (l10nDir.existsSync()) {
      final hasArb = l10nDir
          .listSync(recursive: true)
          .whereType<File>()
          .any((f) => f.path.endsWith('.arb'));
      if (hasArb) {
        // print('Localization detected: found .arb files under ${l10nDir.path}');
        return true;
      }
    }

    final arbAnywhere = projectDir
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('.arb'));
    if (arbAnywhere) {
      // print('Localization detected: found .arb files elsewhere in project');
      return true;
    }

    final appLocImport = RegExp(
      r'''^\s*import\s+["']package:flutter_gen/gen_l10n/app_localizations\.dart["'];''',
      multiLine: true,
    );

    for (final file in dartFiles) {
      try {
        final content = file.readAsStringSync();
        if (appLocImport.hasMatch(content)) {
          // print('Localization detected: found app_localizations import in ${file.path}');
          return true;
        }
      } catch (_) {
        // Ignore unreadable files
      }
    }
    return false;
  }
}

/// A visitor that traverses the AST to collect quality metrics.
///
/// This internal visitor class extends the analyzer's AST visitor to
/// count class declarations and detect StatefulWidget usage in Dart files.
/// It accumulates metrics during the AST traversal process.
///
/// Only public classes (not starting with `_`) are counted for the
/// "one class per file" rule checks.
class _QualityVisitor extends RecursiveAstVisitor<void> {
  /// The total number of public class declarations found in the visited file.
  int classCount = 0;

  /// Whether any of the classes in the file extend StatefulWidget.
  ///
  /// This affects the "one class per file" rule compliance, as StatefulWidget
  /// files are allowed to have up to 2 classes (widget + state).
  bool hasStatefulWidget = false;

  /// Visits a class declaration node in the AST.
  ///
  /// This method is called for each class declaration encountered during
  /// AST traversal. It increments the class count (if the class is public)
  /// and checks if the class extends StatefulWidget.
  ///
  /// [node] The class declaration node being visited.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.toString();

    // Only count public classes for the "one class per file" rule
    // Private classes (starting with _) are implementation details
    if (!className.startsWith('_')) {
      classCount++;
    }

    final superclass = node.extendsClause?.superclass.toString();
    if (superclass == 'StatefulWidget') {
      hasStatefulWidget = true;
    }

    super.visitClassDeclaration(node);
  }
}
