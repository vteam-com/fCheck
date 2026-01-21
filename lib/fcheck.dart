// ignore: unnecessary_library_name
library fcheck;

/// A Flutter/Dart code quality analysis tool.
///
/// This library provides functionality to analyze Flutter and Dart projects
/// for code quality metrics including:
/// - File and folder counts
/// - Lines of code metrics
/// - Comment ratio analysis
/// - One class per file rule compliance
/// - Hardcoded string detection
/// - Source code member sorting validation
///
/// ## Usage
///
/// ```dart
/// import 'package:fcheck/fcheck.dart';
///
/// final engine = AnalyzerEngine(projectDirectory);
/// final metrics = engine.analyze();
/// metrics.printReport();
/// ```

export 'src/metrics/project_metrics.dart';
export 'src/analyzer_engine.dart';
export 'src/utils.dart';
export 'src/hardcoded_strings/hardcoded_string_issue.dart';
export 'src/hardcoded_strings/hardcoded_string_analyzer.dart';
export 'src/hardcoded_strings/hardcoded_string_visitor.dart';
export 'src/sort/sort.dart';
