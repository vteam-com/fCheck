import 'dart:io';
import 'package:args/args.dart';
import 'package:fcheck/evaluator.dart';

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
