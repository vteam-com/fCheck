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
    ..addOption('input',
        abbr: 'i', help: 'Path to the Flutter/Dart project', defaultsTo: '.')
    ..addFlag('fix',
        abbr: 'f',
        help:
            'Automatically fix sorting issues by writing sorted code back to files',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false);

  late ArgResults argResults;
  late String path;
  late bool fix;

  try {
    argResults = parser.parse(arguments);
    fix = argResults['fix'] as bool;

    // Handle help flag
    if (argResults['help'] as bool) {
      print('Usage: dart run fcheck [options] [<folder>]');
      print('');
      print('Analyze Flutter/Dart code quality and provide metrics.');
      print('');
      print(parser.usage);
      exit(0);
    }

    // Determine path: explicit option wins over positional argument
    final explicitPath = argResults['input'] as String;
    if (explicitPath != '.') {
      // Named option was provided (not default)
      path = explicitPath;
    } else if (argResults.rest.isNotEmpty) {
      // Positional argument provided
      path = argResults.rest.first;
    } else {
      // Use default (current directory)
      path = '.';
    }
  } catch (e) {
    print('Error: Invalid arguments provided.');
    print('Usage: dart run fcheck [options] [<folder>]');
    print('');
    print(parser.usage);
    exit(1);
  }

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
