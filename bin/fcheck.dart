import 'dart:io';
import 'package:args/args.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/generators/svg_generator.dart';
import 'package:fcheck/src/generators/mermaid_generator.dart';
import 'package:fcheck/src/generators/plantuml_generator.dart';

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
    ..addFlag('svg',
        help: 'Generate SVG visualization of the dependency graph',
        negatable: false)
    ..addFlag('mermaid',
        help: 'Generate Mermaid file for dependency graph visualization',
        negatable: false)
    ..addFlag('plantuml',
        help: 'Generate PlantUML file for dependency graph visualization',
        negatable: false)
    ..addFlag('dep',
        help: 'Output dependency graph for debugging', negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false);

  late ArgResults argResults;
  late String path;
  late bool fix;
  late bool generateSvg;
  late bool generateMermaid;
  late bool generatePlantUML;
  late bool debugDependencies;

  try {
    argResults = parser.parse(arguments);
    fix = argResults['fix'] as bool;
    generateSvg = argResults['svg'] as bool;
    generateMermaid = argResults['mermaid'] as bool;
    generatePlantUML = argResults['plantuml'] as bool;
    debugDependencies = argResults['dep'] as bool;

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

    // Generate layer analysis result for visualization or debugging
    final layersResult = engine.analyzeLayers();

    if (debugDependencies) {
      print('\n--- Dependency Graph Debug ---');
      layersResult.dependencyGraph.forEach((file, deps) {
        final fileName = file.split('/').last;
        final depNames = deps.map((dep) => dep.split('/').last).toList();
        print('$fileName -> $depNames');
      });
      print('------------------------------\n');
    }

    if (generateSvg || generateMermaid || generatePlantUML) {
      if (generateSvg) {
        // Generate SVG visualization
        final svgContent = generateDependencyGraphSvg(layersResult);
        final svgFile = File('${directory.path}/layers.svg');
        svgFile.writeAsStringSync(svgContent);
        print('SVG layers graph saved to: ${svgFile.path}');
      }

      if (generateMermaid) {
        // Generate Mermaid visualization
        final mermaidContent = generateDependencyGraphMermaid(layersResult);
        final mermaidFile = File('${directory.path}/layers.mmd');
        mermaidFile.writeAsStringSync(mermaidContent);
        print('Mermaid layers graph saved to: ${mermaidFile.path}');
      }

      if (generatePlantUML) {
        // Generate PlantUML visualization
        final plantUMLContent = generateDependencyGraphPlantUML(layersResult);
        final plantUMLFile = File('${directory.path}/layers.puml');
        plantUMLFile.writeAsStringSync(plantUMLContent);
        print('PlantUML layers graph saved to: ${plantUMLFile.path}');
      }
    }
  } catch (e, stack) {
    print('Error during analysis: $e');
    print(stack);
    exit(1);
  }
}
