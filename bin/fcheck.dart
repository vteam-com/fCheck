import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:fcheck/src/graphs/export_mermaid.dart';
import 'package:fcheck/src/graphs/export_plantuml.dart';
import 'package:fcheck/src/graphs/export_svg.dart';
import 'package:fcheck/src/graphs/export_svg_folders.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/metrics/output.dart';
import 'package:fcheck/src/models/version.dart';
import 'package:path/path.dart' as p;

/// Main entry point for the fcheck command-line tool.
///
/// Parses command-line arguments, validates the target directory,
/// and runs the quality analysis on the specified Flutter/Dart project.
///
/// [arguments] Command-line arguments passed to the executable.
void main(List<String> arguments) {
  const int millisecondsInSecond = 1000;
  const int decimalPlacesForSeconds = 2;

  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Path to the Flutter/Dart project',
      defaultsTo: '.',
    )
    ..addFlag(
      'fix',
      abbr: 'f',
      help:
          'Automatically fix sorting issues by writing sorted code back to files',
      negatable: false,
    )
    ..addFlag(
      'svg',
      help: 'Generate SVG visualization of the dependency graph',
      negatable: false,
    )
    ..addFlag(
      'mermaid',
      help: 'Generate Mermaid file for dependency graph visualization',
      negatable: false,
    )
    ..addFlag(
      'plantuml',
      help: 'Generate PlantUML file for dependency graph visualization',
      negatable: false,
    )
    ..addFlag(
      'svgfolder',
      help: 'Generate folder-based SVG visualization of the dependency graph',
      negatable: false,
    )
    ..addFlag(
      'json',
      help: 'Output results in structured JSON format',
      negatable: false,
    )
    ..addFlag(
      'version',
      abbr: 'v',
      help: 'Show fCheck version',
      negatable: false,
    )
    ..addMultiOption(
      'exclude',
      abbr: 'e',
      help: 'Glob patterns to exclude from analysis (e.g. "**/generated/**")',
      defaultsTo: [],
    )
    ..addFlag(
      'excluded',
      abbr: 'x',
      help:
          'List excluded files and directories (hidden folders, default exclusions, custom patterns)',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show usage information',
      negatable: false,
    );

  late ArgResults argResults;
  late String path;
  late bool fix;
  late bool generateSvg;
  late bool generateMermaid;
  late bool generatePlantUML;
  late bool generateFolderSvg;

  late bool outputJson;
  late bool listExcluded;
  late List<String> excludePatterns;

  try {
    argResults = parser.parse(arguments);
    fix = argResults['fix'] as bool;
    generateSvg = argResults['svg'] as bool;
    generateMermaid = argResults['mermaid'] as bool;
    generatePlantUML = argResults['plantuml'] as bool;
    generateFolderSvg = argResults['svgfolder'] as bool;
    outputJson = argResults['json'] as bool;
    listExcluded = argResults['excluded'] as bool;
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

    // Handle version flag
    if (argResults['version'] as bool) {
      print(packageVersion);
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
    printDivider('fCheck $packageVersion', downPointer: true);
    print('Input            : ${directory.absolute.path}');
  }

  final stopwatch = Stopwatch()..start();

  try {
    final engine = AnalyzeFolder(
      directory,
      fix: fix,
      excludePatterns: excludePatterns,
    );

    // Handle excluded files listing
    if (listExcluded) {
      final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) =
          engine.listExcludedFiles();

      if (outputJson) {
        final excludedData = {
          'excludedDartFiles': excludedDartFiles.map((f) => f.path).toList(),
          'excludedNonDartFiles':
              excludedNonDartFiles.map((f) => f.path).toList(),
          'excludedDirectories':
              excludedDirectories.map((d) => d.path).toList(),
        };
        print(const JsonEncoder.withIndent('  ').convert(excludedData));
      } else {
        print('Excluded Dart files (${excludedDartFiles.length}):');
        if (excludedDartFiles.isEmpty) {
          print('  (none)');
        } else {
          for (final file in excludedDartFiles) {
            print('  ${file.path}');
          }
        }

        print('\nExcluded non-Dart files (${excludedNonDartFiles.length}):');
        if (excludedNonDartFiles.isEmpty) {
          print('  (none)');
        } else {
          for (final file in excludedNonDartFiles) {
            print('  ${file.path}');
          }
        }

        print('\nExcluded directories (${excludedDirectories.length}):');
        if (excludedDirectories.isEmpty) {
          print('  (none)');
        } else {
          for (final dir in excludedDirectories) {
            print('  ${dir.path}');
          }
        }
      }
      return;
    }

    final metrics = engine.analyze();

    if (outputJson) {
      print(const JsonEncoder.withIndent('  ').convert(metrics.toJson()));
    } else {
      metrics.printReport(packageVersion);
    }

    // Generate layer analysis result for visualization
    final layersResult = engine.analyzeLayers();

    if (generateSvg ||
        generateMermaid ||
        generatePlantUML ||
        generateFolderSvg) {
      if (!outputJson) {
        printDivider('Output files', dot: true);
      }
      if (generateSvg) {
        // Generate SVG visualization
        final svgContent = exportGraphSvg(layersResult);
        final svgFile = File('${directory.path}/layers.svg');
        svgFile.writeAsStringSync(svgContent);
        if (!outputJson) {
          print('SVG layers         : ${svgFile.path}');
        }
      }

      if (generateFolderSvg) {
        // Generate folder-based SVG visualization
        // Use hierarchical layout to preserve parent-child nesting
        String inputFolderName = p.basename(directory.absolute.path);
        if (inputFolderName.isEmpty || inputFolderName == '.') {
          // Get the parent directory name as fallback
          inputFolderName = p.basename(directory.absolute.parent.path);
        }

        final folderSvgContent = exportGraphSvgFolders(
          layersResult,
          projectName: metrics.projectName,
          projectVersion: metrics.version,
          inputFolderName: inputFolderName,
        );
        final folderSvgFile = File('${directory.path}/layers_folders.svg');
        folderSvgFile.writeAsStringSync(folderSvgContent);
        if (!outputJson) {
          print('SVG layers (folder): ${folderSvgFile.path}');
        }
      }

      if (generateMermaid) {
        // Generate Mermaid visualization
        final mermaidContent = exportGraphMermaid(layersResult);
        final mermaidFile = File('${directory.path}/layers.mmd');
        mermaidFile.writeAsStringSync(mermaidContent);
        if (!outputJson) {
          print('Mermaid layers.    : ${mermaidFile.path}');
        }
      }

      if (generatePlantUML) {
        // Generate PlantUML visualization
        final plantUMLContent = exportGraphPlantUML(layersResult);
        final plantUMLFile = File('${directory.path}/layers.puml');
        plantUMLFile.writeAsStringSync(plantUMLContent);
        if (!outputJson) {
          print('PlantUML layers.   : ${plantUMLFile.path}');
        }
      }
    }
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final elapsedSeconds = (elapsedMs / millisecondsInSecond)
        .toStringAsFixed(decimalPlacesForSeconds);
    if (!outputJson) {
      printDivider('fCheck completed (${elapsedSeconds}s)', downPointer: false);
    }
  } catch (e, stack) {
    print('Error during analysis: $e');
    print(stack);
    exit(1);
  }
}
