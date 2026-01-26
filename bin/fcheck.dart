import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/generators/mermaid_generator.dart';
import 'package:fcheck/src/generators/svg_generator.dart';
import 'package:fcheck/src/generators/plantuml_generator.dart';
import 'package:fcheck/src/generators/folder_svg_hierarchical.dart'
    as hierarchical;

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
    ..addFlag('svgfolder',
        help: 'Generate folder-based SVG visualization of the dependency graph',
        negatable: false)
    ..addFlag('json',
        help: 'Output results in structured JSON format', negatable: false)
    ..addMultiOption('exclude',
        abbr: 'e',
        help: 'Glob patterns to exclude from analysis (e.g. "**/generated/**")',
        defaultsTo: [])
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false);

  late ArgResults argResults;
  late String path;
  late bool fix;
  late bool generateSvg;
  late bool generateMermaid;
  late bool generatePlantUML;
  late bool generateFolderSvg;

  late bool outputJson;
  late List<String> excludePatterns;

  try {
    argResults = parser.parse(arguments);
    fix = argResults['fix'] as bool;
    generateSvg = argResults['svg'] as bool;
    generateMermaid = argResults['mermaid'] as bool;
    generatePlantUML = argResults['plantuml'] as bool;
    generateFolderSvg = argResults['svgfolder'] as bool;
    outputJson = argResults['json'] as bool;
    excludePatterns = argResults['exclude'] as List<String>;

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

  if (!outputJson) {
    final action = fix ? 'Fixing' : 'Analyzing';
    print('$action project at: ${directory.absolute.path}...');
  }

  try {
    final engine =
        AnalyzerEngine(directory, fix: fix, excludePatterns: excludePatterns);
    final metrics = engine.analyze();

    if (outputJson) {
      print(const JsonEncoder.withIndent('  ').convert(metrics.toJson()));
    } else {
      metrics.printReport();
    }

    // Generate layer analysis result for visualization
    final layersResult = engine.analyzeLayers();

    if (generateSvg ||
        generateMermaid ||
        generatePlantUML ||
        generateFolderSvg) {
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

      if (generateFolderSvg) {
        // Generate folder-based SVG visualization
        // Use hierarchical layout to preserve parent-child nesting
        final folderSvgContent =
            hierarchical.generateHierarchicalDependencyGraphSvg(layersResult);
        final folderSvgFile = File('${directory.path}/folder_layers.svg');
        folderSvgFile.writeAsStringSync(folderSvgContent);
        print('Folder-based SVG layers graph saved to: ${folderSvgFile.path}');
      }
    }
  } catch (e, stack) {
    print('Error during analysis: $e');
    print(stack);
    exit(1);
  }
}
