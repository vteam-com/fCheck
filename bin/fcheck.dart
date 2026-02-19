import 'dart:io';
import 'package:fcheck/src/graphs/export_mermaid.dart';
import 'package:fcheck/src/graphs/export_plantuml.dart';
import 'package:fcheck/src/graphs/export_svg.dart';
import 'package:fcheck/src/graphs/export_svg_folders.dart';
import 'package:fcheck/src/graphs/export_svg_code_size.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/version.dart';
import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:path/path.dart' as p;
import 'console/console_input.dart';
import 'console/console_output.dart';
import 'console/console_common.dart';
import 'package:fcheck/src/models/app_strings.dart';

/// Main entry point for the fcheck command-line tool.
///
/// Execution flow:
/// 1. Parse CLI arguments and handle early-help/version exits.
/// 2. Resolve `.fcheck` config and effective analysis directory.
/// 3. Run analysis and render JSON or console report output.
/// 4. Optionally generate graph artifacts (SVG/Mermaid/PlantUML).
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

  configureCliColorOutput(disableColors: input.noColors);

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

  if (input.showIgnoresInstructions) {
    printIgnoreSetupGuide();
    exit(0);
  }

  if (input.showScoreInstructions) {
    printScoreSystemGuide();
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
    effectiveExcludePatterns = fcheckConfig.mergeExcludePatterns(
      input.excludePatterns,
    );
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
      codeSizeThresholds: fcheckConfig.codeSizeThresholds,
    );

    // Handle excluded files listing
    if (input.listExcluded) {
      final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) =
          engine.listExcludedFiles();

      if (input.outputJson) {
        final excludedData = {
          'excludedDartFiles': excludedDartFiles.map((f) => f.path).toList(),
          'excludedNonDartFiles': excludedNonDartFiles
              .map((f) => f.path)
              .toList(),
          'excludedDirectories': excludedDirectories
              .map((d) => d.path)
              .toList(),
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
    final shouldPrintOutputFilesSection =
        input.generateSvg ||
        input.generateMermaid ||
        input.generatePlantUML ||
        input.generateFolderSvg ||
        input.generateSizeSvg;
    var deferredScorecardLines = <String>[];

    if (input.outputJson) {
      printJsonOutput(metrics.toJson());
    } else {
      final reportLines = buildReportLines(
        metrics,
        listMode: input.listMode,
        listItemLimit: input.listItemLimit,
      );
      if (shouldPrintOutputFilesSection) {
        final scorecardDividerIndex = reportLines.indexOf(
          dividerLine(AppStrings.scorecardDivider),
        );
        if (scorecardDividerIndex >= 0) {
          printReportLines(reportLines.sublist(0, scorecardDividerIndex));
          deferredScorecardLines = reportLines.sublist(scorecardDividerIndex);
        } else {
          printReportLines(reportLines);
        }
      } else {
        printReportLines(reportLines);
      }
    }

    if (shouldPrintOutputFilesSection) {
      // Generate layer analysis result for visualization
      final layersResult = LayersAnalysisResult(
        issues: metrics.layersIssues,
        layers: metrics.layersByFile,
        dependencyGraph: metrics.dependencyGraph,
      );

      if (!input.outputJson) {
        printOutputFilesHeader();
      }
      if (input.generateSvg) {
        // Generate SVG visualization
        final svgContent = exportGraphSvg(layersResult);
        final svgFile = File('${directory.path}/layers.svg');
        svgFile.writeAsStringSync(svgContent);
        if (!input.outputJson) {
          printOutputFileLine(label: AppStrings.svgLayers, path: svgFile.path);
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
            label: AppStrings.svgLayersFolder,
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
            label: AppStrings.mermaidLayers,
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
            label: AppStrings.plantUmlLayers,
            path: plantUMLFile.path,
          );
        }
      }

      if (input.generateSizeSvg) {
        final sizeTreemapContent = exportSvgCodeSize(
          metrics.codeSizeArtifacts,
          title: 'Code Size of ${metrics.projectName} ${metrics.version}',
          relativeTo: directory.path,
        );
        final sizeTreemapFile = File('${directory.path}/fcheck_code_size.svg');
        sizeTreemapFile.writeAsStringSync(sizeTreemapContent);
        if (!input.outputJson) {
          printOutputFileLine(
            label: AppStrings.svgCodeSizeTreemap,
            path: sizeTreemapFile.path,
          );
        }
      }
    }
    if (!input.outputJson && deferredScorecardLines.isNotEmpty) {
      printReportLines(deferredScorecardLines);
    }
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final elapsedSeconds = (elapsedMs / millisecondsInSecond).toStringAsFixed(
      decimalPlacesForSeconds,
    );
    if (!input.outputJson) {
      printRunCompleted(elapsedSeconds);
    }
  } catch (e, stack) {
    printAnalysisError(e, stack);
    exit(1);
  }
}
