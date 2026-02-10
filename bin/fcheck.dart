import 'dart:io';
import 'package:fcheck/src/graphs/export_mermaid.dart';
import 'package:fcheck/src/graphs/export_plantuml.dart';
import 'package:fcheck/src/graphs/export_svg.dart';
import 'package:fcheck/src/graphs/export_svg_folders.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/version.dart';
import 'package:path/path.dart' as p;
import 'console_input.dart';
import 'console_output.dart';
import 'console_common.dart';

/// Main entry point for the fcheck command-line tool.
///
/// Parses command-line arguments, validates the target directory,
/// and runs the quality analysis on the specified Flutter/Dart project.
///
/// [arguments] Command-line arguments passed to the executable.
void main(List<String> arguments) {
  const int millisecondsInSecond = 1000;
  const int decimalPlacesForSeconds = 2;

  final parser = createConsoleArgParser();
  late ConsoleInput input;

  try {
    input = parseConsoleInput(arguments, parser);
  } catch (_) {
    printInvalidArgumentsScreen(
      invalidArgumentsLine: invalidArgumentsLine,
      usageLine: usageLine,
      parserUsage: parser.usage,
    );
    exit(1);
  }

  if (input.showHelp) {
    printHelpScreen(
      usageLine: usageLine,
      descriptionLine: descriptionLine,
      parserUsage: parser.usage,
    );
    exit(0);
  }

  if (input.showVersion) {
    printVersionLine(packageVersion);
    exit(0);
  }

  final inputDirectory = Directory(input.path);
  if (!inputDirectory.existsSync()) {
    printMissingDirectoryError(input.path);
    exit(1);
  }

  late final FcheckConfig fcheckConfig;
  late final Directory directory;
  late final List<String> effectiveExcludePatterns;
  try {
    fcheckConfig = FcheckConfig.loadForInputDirectory(inputDirectory);
    directory = Directory(
      p.normalize(fcheckConfig.resolveAnalysisDirectory().absolute.path),
    );
    if (!directory.existsSync()) {
      printMissingDirectoryError(directory.path);
      exit(1);
    }
    effectiveExcludePatterns =
        fcheckConfig.mergeExcludePatterns(input.excludePatterns);
  } on FormatException catch (error) {
    printConfigurationError(error.message.toString());
    exit(1);
  }

  if (!input.outputJson) {
    printRunHeader(version: packageVersion, directory: directory);
  }

  final stopwatch = Stopwatch()..start();

  try {
    final engine = AnalyzeFolder(
      directory,
      fix: input.fix,
      excludePatterns: effectiveExcludePatterns,
      enabledAnalyzers: fcheckConfig.effectiveEnabledAnalyzers,
      duplicateCodeSimilarityThreshold:
          fcheckConfig.duplicateCodeSimilarityThreshold,
      duplicateCodeMinTokenCount: fcheckConfig.duplicateCodeMinTokens,
      duplicateCodeMinNonEmptyLineCount:
          fcheckConfig.duplicateCodeMinNonEmptyLines,
    );

    // Handle excluded files listing
    if (input.listExcluded) {
      final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) =
          engine.listExcludedFiles();

      if (input.outputJson) {
        final excludedData = {
          'excludedDartFiles': excludedDartFiles.map((f) => f.path).toList(),
          'excludedNonDartFiles':
              excludedNonDartFiles.map((f) => f.path).toList(),
          'excludedDirectories':
              excludedDirectories.map((d) => d.path).toList(),
        };
        printJsonOutput(excludedData);
      } else {
        printExcludedItems(
          excludedDartFiles: excludedDartFiles,
          excludedNonDartFiles: excludedNonDartFiles,
          excludedDirectories: excludedDirectories,
        );
      }
      return;
    }

    final metrics = engine.analyze();

    if (input.outputJson) {
      printJsonOutput(metrics.toJson());
    } else {
      printReportLines(buildReportLines(metrics, listMode: input.listMode));
    }

    // Generate layer analysis result for visualization
    final layersResult = engine.analyzeLayers();

    if (input.generateSvg ||
        input.generateMermaid ||
        input.generatePlantUML ||
        input.generateFolderSvg) {
      if (!input.outputJson) {
        printOutputFilesHeader();
      }
      if (input.generateSvg) {
        // Generate SVG visualization
        final svgContent = exportGraphSvg(layersResult);
        final svgFile = File('${directory.path}/layers.svg');
        svgFile.writeAsStringSync(svgContent);
        if (!input.outputJson) {
          printOutputFileLine(
            label: 'SVG layers         ',
            path: svgFile.path,
          );
        }
      }

      if (input.generateFolderSvg) {
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
        if (!input.outputJson) {
          printOutputFileLine(
            label: 'SVG layers (folder)',
            path: folderSvgFile.path,
          );
        }
      }

      if (input.generateMermaid) {
        // Generate Mermaid visualization
        final mermaidContent = exportGraphMermaid(layersResult);
        final mermaidFile = File('${directory.path}/layers.mmd');
        mermaidFile.writeAsStringSync(mermaidContent);
        if (!input.outputJson) {
          printOutputFileLine(
            label: 'Mermaid layers.    ',
            path: mermaidFile.path,
          );
        }
      }

      if (input.generatePlantUML) {
        // Generate PlantUML visualization
        final plantUMLContent = exportGraphPlantUML(layersResult);
        final plantUMLFile = File('${directory.path}/layers.puml');
        plantUMLFile.writeAsStringSync(plantUMLContent);
        if (!input.outputJson) {
          printOutputFileLine(
            label: 'PlantUML layers.   ',
            path: plantUMLFile.path,
          );
        }
      }
    }
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final elapsedSeconds = (elapsedMs / millisecondsInSecond)
        .toStringAsFixed(decimalPlacesForSeconds);
    if (!input.outputJson) {
      printRunCompleted(elapsedSeconds);
    }
  } catch (e, stack) {
    printAnalysisError(e, stack);
    exit(1);
  }
}
