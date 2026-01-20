/// A Flutter/Dart code quality analysis tool.
///
/// This library provides functionality to analyze Flutter and Dart projects
/// for code quality metrics including:
/// - File and folder counts
/// - Lines of code metrics
/// - Comment ratio analysis
/// - One class per file rule compliance
/// - Hardcoded string detection
///
/// ## Usage
///
/// ```dart
/// import 'package:fcheck/evaluator.dart';
///
/// final engine = AnalyzerEngine(projectDirectory);
/// final metrics = engine.analyze();
/// metrics.printReport();
/// ```
library fcheck;

export 'src/models/project_metrics.dart';
export 'src/analyzer_engine.dart';
export 'src/utils.dart';
export 'src/hardcoded_string_issue.dart';
export 'src/hardcoded_string_analyzer.dart';
export 'src/hardcoded_string_visitor.dart';
