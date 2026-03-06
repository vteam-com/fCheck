import 'dart:io';

import 'package:args/args.dart';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/analyzers/layers/layers_results.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/exports/externals/export_mermaid.dart';
import 'package:fcheck/src/exports/externals/export_plantuml.dart';
import 'package:fcheck/src/exports/svg/export_files/export_svg_files.dart';
import 'package:fcheck/src/exports/svg/export_folders/export_svg_folders.dart';
import 'package:fcheck/src/exports/svg/export_loc/export_svg_code_size.dart';
import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_inventory.dart';
import 'package:fcheck/src/models/version.dart';
import 'package:path/path.dart' as p;

import 'console/console_common.dart';
import 'console/console_input.dart';
import 'console/console_output.dart';

const int _millisecondsInSecond = 1000;
const int _decimalPlacesForSeconds = 2;

/// Runs the complete CLI flow for `fcheck`.
void runCli(List<String> arguments) {
  final parser = createConsoleArgParser();
  final input = _parseConsoleInputOrExit(arguments, parser);

  configureCliColorOutput(disableColors: input.noColors);
  _handleEarlyExit(input, parser);

  final context = _resolveCliContext(input);

  if (!input.outputJson) {
    printRunHeader(version: packageVersion, directory: context.directory);
  }

  final stopwatch = Stopwatch()..start();
  try {
    _executeCliRun(input, context);
    stopwatch.stop();
    if (!input.outputJson) {
      final elapsedSeconds =
          (stopwatch.elapsedMilliseconds / _millisecondsInSecond)
              .toStringAsFixed(_decimalPlacesForSeconds);
      printRunCompleted(elapsedSeconds);
    }
  } catch (error, stack) {
    printAnalysisError(error, stack);
    exit(1);
  }
}

/// Parses CLI arguments and exits with the invalid-arguments screen on failure.
ConsoleInput _parseConsoleInputOrExit(
  List<String> arguments,
  ArgParser parser,
) {
  try {
    return parseConsoleInput(arguments, parser);
  } catch (_) {
    printInvalidArgumentsScreen(
      invalidArgumentsLine: invalidArgumentsLine,
      usageLine: usageLine,
      parserUsage: parser.usage,
    );
    exit(1);
  }
}

/// Handles help/version/instructions flags that should terminate early.
void _handleEarlyExit(ConsoleInput input, ArgParser parser) {
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
}

/// Resolves the effective analysis directory and merged `.fcheck` settings.
_CliContext _resolveCliContext(ConsoleInput input) {
  final inputDirectory = Directory(input.path);
  if (!inputDirectory.existsSync()) {
    printMissingDirectoryError(input.path);
    exit(1);
  }

  try {
    final fcheckConfig = FcheckConfig.loadForInputDirectory(inputDirectory);
    final directory = Directory(
      p.normalize(fcheckConfig.resolveAnalysisDirectory().absolute.path),
    );
    if (!directory.existsSync()) {
      printMissingDirectoryError(directory.path);
      exit(1);
    }
    return _CliContext(
      fcheckConfig: fcheckConfig,
      directory: directory,
      effectiveExcludePatterns: fcheckConfig.mergeExcludePatterns(
        input.excludePatterns,
      ),
    );
  } on FormatException catch (error) {
    printConfigurationError(error.message.toString());
    exit(1);
  }
}

/// Executes the main non-bootstrap CLI flow after configuration is resolved.
void _executeCliRun(ConsoleInput input, _CliContext context) {
  final engine = AnalyzeFolder(
    context.directory,
    fix: input.fix,
    excludePatterns: context.effectiveExcludePatterns,
    enabledAnalyzers: context.fcheckConfig.effectiveEnabledAnalyzers,
    duplicateCodeSimilarityThreshold:
        context.fcheckConfig.duplicateCodeSimilarityThreshold,
    duplicateCodeMinTokenCount: context.fcheckConfig.duplicateCodeMinTokens,
    duplicateCodeMinNonEmptyLineCount:
        context.fcheckConfig.duplicateCodeMinNonEmptyLines,
    codeSizeThresholds: context.fcheckConfig.codeSizeThresholds,
  );

  if (_handleExcludedListing(input, engine)) {
    return;
  }
  if (_handleIgnoreListing(input, context)) {
    return;
  }

  final metrics = engine.analyze();
  if (_handleLiteralListing(input, metrics)) {
    return;
  }

  final shouldWriteArtifacts = _shouldWriteArtifacts(input);
  final deferredScorecardLines = _printAnalysisOutput(
    input: input,
    metrics: metrics,
    shouldWriteArtifacts: shouldWriteArtifacts,
  );

  if (shouldWriteArtifacts) {
    _writeOutputArtifacts(
      input: input,
      directory: context.directory,
      metrics: metrics,
    );
  }

  if (!input.outputJson && deferredScorecardLines.isNotEmpty) {
    printReportLines(deferredScorecardLines);
  }
}

/// Prints or serializes excluded items and reports whether the request was handled.
bool _handleExcludedListing(ConsoleInput input, AnalyzeFolder engine) {
  if (!input.listExcluded) {
    return false;
  }

  final (excludedDartFiles, excludedNonDartFiles, excludedDirectories) = engine
      .listExcludedFiles();
  if (input.outputJson) {
    printJsonOutput({
      'excludedDartFiles': excludedDartFiles.map((file) => file.path).toList(),
      'excludedNonDartFiles': excludedNonDartFiles
          .map((file) => file.path)
          .toList(),
      'excludedDirectories': excludedDirectories
          .map((directory) => directory.path)
          .toList(),
    });
  } else {
    printExcludedItems(
      excludedDartFiles: excludedDartFiles,
      excludedNonDartFiles: excludedNonDartFiles,
      excludedDirectories: excludedDirectories,
    );
  }
  return true;
}

/// Prints or serializes ignore inventory and reports whether the request was handled.
bool _handleIgnoreListing(ConsoleInput input, _CliContext context) {
  if (!input.listIgnores) {
    return false;
  }

  final ignoreInventory = collectIgnoreInventory(
    rootDirectory: context.directory,
    fcheckConfig: context.fcheckConfig,
  );
  if (input.outputJson) {
    printJsonOutput(ignoreInventory.toJson());
  } else {
    printIgnoreInventory(ignoreInventory);
  }
  return true;
}

/// Prints or serializes literal inventories and reports whether the request was handled.
bool _handleLiteralListing(ConsoleInput input, ProjectMetrics metrics) {
  if (!input.listLiterals) {
    return false;
  }

  if (input.outputJson) {
    printJsonOutput(_buildLiteralJson(metrics));
  } else {
    printLiteralsSummary(
      totalStringLiteralCount: metrics.totalStringLiteralCount,
      duplicatedStringLiteralCount: metrics.duplicatedStringLiteralCount,
      hardcodedStringCount: metrics.hardcodedStringIssues.length,
      totalNumberLiteralCount: metrics.totalNumberLiteralCount,
      duplicatedNumberLiteralCount: metrics.duplicatedNumberLiteralCount,
      hardcodedNumberCount: metrics.magicNumberIssues.length,
      stringLiteralFrequencies: metrics.stringLiteralFrequencies,
      numberLiteralFrequencies: metrics.numberLiteralFrequencies,
      hardcodedStringEntries: metrics.hardcodedStringIssues
          .map(
            (issue) => <String, Object?>{
              'filePath': issue.filePath,
              'lineNumber': issue.lineNumber,
              'value': issue.value,
            },
          )
          .toList(growable: false),
      listMode: ReportListMode.full,
      listItemLimit: input.listItemLimit,
    );
  }
  return true;
}

/// Builds the JSON payload used by `--literals --json`.
Map<String, dynamic> _buildLiteralJson(ProjectMetrics metrics) {
  return {
    'strings': {
      'total': metrics.totalStringLiteralCount,
      'duplicated': metrics.duplicatedStringLiteralCount,
      'duplicateRatio': metrics.stringLiteralDuplicateRatio,
      'hardcoded': metrics.hardcodedStringIssues.length,
      'entries': _buildLiteralEntries(metrics.stringLiteralFrequencies),
    },
    'numbers': {
      'total': metrics.totalNumberLiteralCount,
      'duplicated': metrics.duplicatedNumberLiteralCount,
      'duplicateRatio': metrics.numberLiteralDuplicateRatio,
      'hardcoded': metrics.magicNumberIssues.length,
      'entries': _buildLiteralEntries(metrics.numberLiteralFrequencies),
    },
  };
}

/// Sorts literal frequency entries by descending count and then lexicographically.
List<Map<String, dynamic>> _buildLiteralEntries(Map<String, int> frequencies) {
  final entries = frequencies.entries.toList()
    ..sort((left, right) {
      final countCompare = right.value.compareTo(left.value);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.key.compareTo(right.key);
    });
  return entries
      .map((entry) => {'value': entry.key, 'count': entry.value})
      .toList(growable: false);
}

bool _shouldWriteArtifacts(ConsoleInput input) {
  return input.generateSvg ||
      input.generateMermaid ||
      input.generatePlantUML ||
      input.generateFolderSvg ||
      input.generateSizeSvg;
}

/// Prints analysis output and defers the scorecard when artifact paths will follow.
List<String> _printAnalysisOutput({
  required ConsoleInput input,
  required ProjectMetrics metrics,
  required bool shouldWriteArtifacts,
}) {
  if (input.outputJson) {
    printJsonOutput(metrics.toJson());
    return const <String>[];
  }

  final reportLines = buildReportLines(
    metrics,
    listMode: input.listMode,
    listItemLimit: input.listItemLimit,
  );
  if (!shouldWriteArtifacts) {
    printReportLines(reportLines);
    return const <String>[];
  }

  final scorecardDividerIndex = reportLines.indexOf(
    dividerLine(AppStrings.scorecardDivider),
  );
  if (scorecardDividerIndex < 0) {
    printReportLines(reportLines);
    return const <String>[];
  }

  printReportLines(reportLines.sublist(0, scorecardDividerIndex));
  return reportLines.sublist(scorecardDividerIndex);
}

/// Writes requested graph and code-size artifacts to disk and reports their paths.
void _writeOutputArtifacts({
  required ConsoleInput input,
  required Directory directory,
  required ProjectMetrics metrics,
}) {
  final layersResult = LayersAnalysisResult(
    issues: metrics.layersIssues,
    layers: metrics.layersByFile,
    dependencyGraph: metrics.dependencyGraph,
  );
  final outputResolver = _OutputFileResolver(
    input: input,
    analysisDirectory: directory,
  );

  if (!input.outputJson) {
    printOutputFilesHeader();
  }

  if (input.generateSvg) {
    final svgFile = outputResolver.prepareOutputFile(
      defaultFileName: 'fcheck_files.svg',
      overridePath: input.outputSvgFilesPath,
    );
    svgFile.writeAsStringSync(
      exportGraphSvgFiles(layersResult, projectMetrics: metrics),
    );
    if (!input.outputJson) {
      printOutputFileLine(label: AppStrings.svgLayers, path: svgFile.path);
    }
  }

  if (input.generateFolderSvg) {
    final folderSvgFile = outputResolver.prepareOutputFile(
      defaultFileName: 'fcheck_folders.svg',
      overridePath: input.outputSvgFoldersPath,
    );
    folderSvgFile.writeAsStringSync(
      exportGraphSvgFolders(
        layersResult,
        projectName: metrics.projectName,
        projectVersion: metrics.version,
        inputFolderName: _inputFolderName(directory),
        projectMetrics: metrics,
      ),
    );
    if (!input.outputJson) {
      printOutputFileLine(
        label: AppStrings.svgLayersFolder,
        path: folderSvgFile.path,
      );
    }
  }

  if (input.generateMermaid) {
    final mermaidFile = outputResolver.prepareOutputFile(
      defaultFileName: 'fcheck.mmd',
      overridePath: input.outputMermaidPath,
    );
    mermaidFile.writeAsStringSync(exportGraphMermaid(layersResult));
    if (!input.outputJson) {
      printOutputFileLine(
        label: AppStrings.mermaidLayers,
        path: mermaidFile.path,
      );
    }
  }

  if (input.generatePlantUML) {
    final plantUmlFile = outputResolver.prepareOutputFile(
      defaultFileName: 'fcheck.puml',
      overridePath: input.outputPlantUmlPath,
    );
    plantUmlFile.writeAsStringSync(exportGraphPlantUML(layersResult));
    if (!input.outputJson) {
      printOutputFileLine(
        label: AppStrings.plantUmlLayers,
        path: plantUmlFile.path,
      );
    }
  }

  if (input.generateSizeSvg) {
    final sizeTreemapFile = outputResolver.prepareOutputFile(
      defaultFileName: 'fcheck_loc.svg',
      overridePath: input.outputSvgLocPath,
    );
    sizeTreemapFile.writeAsStringSync(
      exportSvgCodeSize(
        metrics.codeSizeArtifacts,
        title: '${metrics.projectName} ${metrics.version}',
        relativeTo: directory.path,
        projectMetrics: metrics,
      ),
    );
    if (!input.outputJson) {
      printOutputFileLine(
        label: AppStrings.svgCodeSizeTreemap,
        path: sizeTreemapFile.path,
      );
    }
  }
}

String _inputFolderName(Directory directory) {
  final folderName = p.basename(directory.absolute.path);
  if (folderName.isEmpty || folderName == '.') {
    return p.basename(directory.absolute.parent.path);
  }
  return folderName;
}

class _CliContext {
  final FcheckConfig fcheckConfig;
  final Directory directory;
  final List<String> effectiveExcludePatterns;

  const _CliContext({
    required this.fcheckConfig,
    required this.directory,
    required this.effectiveExcludePatterns,
  });
}

class _OutputFileResolver {
  final ConsoleInput input;
  final Directory analysisDirectory;

  const _OutputFileResolver({
    required this.input,
    required this.analysisDirectory,
  });

  /// Resolves and prepares an output file path under the analysis directory.
  File prepareOutputFile({
    required String defaultFileName,
    String? overridePath,
  }) {
    final outputFile = File(
      _resolveOutputPath(
        defaultFileName: defaultFileName,
        overridePath: overridePath,
      ),
    );
    outputFile.parent.createSync(recursive: true);
    return outputFile;
  }

  /// Resolves an override or output-directory relative path into a final file path.
  String _resolveOutputPath({
    required String defaultFileName,
    String? overridePath,
  }) {
    if (overridePath != null) {
      return p.normalize(
        p.isAbsolute(overridePath)
            ? overridePath
            : p.join(analysisDirectory.path, overridePath),
      );
    }

    final outputBaseDir = input.outputDirectory == null
        ? analysisDirectory.path
        : p.normalize(
            p.isAbsolute(input.outputDirectory!)
                ? input.outputDirectory!
                : p.join(analysisDirectory.path, input.outputDirectory!),
          );
    return p.join(outputBaseDir, defaultFileName);
  }
}
