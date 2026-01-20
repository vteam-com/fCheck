/// Command-line interface for the fcheck Flutter/Dart quality analyzer.
///
/// This executable provides a command-line interface to analyze Flutter and
/// Dart projects for code quality metrics. It can be run from the terminal
/// to get comprehensive reports on project structure, code metrics, and
/// compliance with coding standards.
///
/// ## Usage
///
/// ```bash
/// # Analyze current directory
/// dart run fcheck
///
/// # Analyze specific path
/// dart run fcheck --path /path/to/project
/// ```
import 'dart:io';
import 'package:args/args.dart';
import 'package:fcheck/fcheck.dart';

/// Main entry point for the fcheck command-line tool.
///
/// Parses command-line arguments, validates the target directory,
/// and runs the quality analysis on the specified Flutter/Dart project.
///
/// [arguments] Command-line arguments passed to the executable.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('path',
        abbr: 'p', help: 'Path to the Flutter/Dart project', defaultsTo: '.');

  final argResults = parser.parse(arguments);
  final path = argResults['path'] as String;

  final directory = Directory(path);
  if (!directory.existsSync()) {
    print('Error: Directory "$path" does not exist.');
    exit(1);
  }

  print('Analyzing project at: ${directory.absolute.path}...');

  try {
    final engine = AnalyzerEngine(directory);
    final metrics = engine.analyze();
    metrics.printReport();
  } catch (e, stack) {
    print('Error during analysis: $e');
    print(stack);
    exit(1);
  }
}
