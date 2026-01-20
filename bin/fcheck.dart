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
        abbr: 'p', help: 'Path to the Flutter/Dart project', defaultsTo: '.')
    ..addFlag('fix',
        abbr: 'f',
        help:
            'Automatically fix sorting issues by writing sorted code back to files',
        negatable: false);

  final argResults = parser.parse(arguments);
  final path = argResults['path'] as String;
  final fix = argResults['fix'] as bool;

  final directory = Directory(path);
  if (!directory.existsSync()) {
    print('Error: Directory "$path" does not exist.');
    exit(1);
  }

  final action = fix ? 'Fixing' : 'Analyzing';
  print('$action project at: ${directory.absolute.path}...');

  try {
    final engine = AnalyzerEngine(directory, fix: fix);
    final metrics = engine.analyze();
    metrics.printReport();
  } catch (e, stack) {
    print('Error during analysis: $e');
    print(stack);
    exit(1);
  }
}
