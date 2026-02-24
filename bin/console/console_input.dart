import 'package:args/args.dart';

import 'console_common.dart';

/// Parsed CLI input for the `fcheck` command.
///
/// This object is intentionally flat so downstream execution can make
/// straightforward, deterministic decisions without re-reading raw args.
/// Path resolution precedence is:
/// 1. Explicit `--input`
/// 2. First positional argument
/// 3. Current directory (`.`)
class ConsoleInput {
  /// Parsed target path from `--input` or positional arg.
  final String path;

  /// Whether sorting should be auto-fixed.
  final bool fix;

  /// Whether SVG graph output should be generated.
  final bool generateSvg;

  /// Whether Mermaid graph output should be generated.
  final bool generateMermaid;

  /// Whether PlantUML graph output should be generated.
  final bool generatePlantUML;

  /// Whether folder-based SVG graph output should be generated.
  final bool generateFolderSvg;

  /// Whether code-size treemap SVG output should be generated.
  final bool generateSizeSvg;

  /// Optional output directory for generated artifacts.
  final String? outputDirectory;

  /// Optional override path for files SVG export.
  final String? outputSvgFilesPath;

  /// Optional override path for folders SVG export.
  final String? outputSvgFoldersPath;

  /// Optional override path for LOC treemap SVG export.
  final String? outputSvgLocPath;

  /// Optional override path for Mermaid export.
  final String? outputMermaidPath;

  /// Optional override path for PlantUML export.
  final String? outputPlantUmlPath;

  /// Whether JSON output is requested.
  final bool outputJson;

  /// How detailed the report lists should be.
  final ReportListMode listMode;

  /// Maximum entries printed per list when [listMode] is `partial`.
  final int listItemLimit;

  /// Whether excluded files/dirs listing is requested.
  final bool listExcluded;

  /// Exclusion globs passed through `--exclude`.
  final List<String> excludePatterns;

  /// Whether `--help` is set.
  final bool showHelp;

  /// Whether `--version` is set.
  final bool showVersion;

  /// Whether `--help-ignore` is set.
  final bool showIgnoresInstructions;

  /// Whether `--help-score` is set.
  final bool showScoreInstructions;

  /// Whether ANSI colors are disabled for CLI output.
  final bool noColors;

  /// Creates a parsed CLI input object.
  const ConsoleInput({
    required this.path,
    required this.fix,
    required this.generateSvg,
    required this.generateMermaid,
    required this.generatePlantUML,
    required this.generateFolderSvg,
    required this.generateSizeSvg,
    required this.outputDirectory,
    required this.outputSvgFilesPath,
    required this.outputSvgFoldersPath,
    required this.outputSvgLocPath,
    required this.outputMermaidPath,
    required this.outputPlantUmlPath,
    required this.outputJson,
    required this.listMode,
    required this.listItemLimit,
    required this.listExcluded,
    required this.excludePatterns,
    required this.showHelp,
    required this.showVersion,
    required this.showIgnoresInstructions,
    required this.showScoreInstructions,
    required this.noColors,
  });
}

/// Builds the canonical argument parser for the `fcheck` command.
///
/// The parser definition is the single source of truth for CLI options shown
/// in `--help` and used by [parseConsoleInput].
ArgParser createConsoleArgParser() => ArgParser()
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
    help:
        'Shortcut to generate all SVG outputs (files, folders, and LOC treemap)',
    negatable: false,
  )
  ..addFlag(
    'svgfiles',
    help: 'Generate files SVG visualization of the dependency graph',
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
    'svgloc',
    help: 'Generate treemap SVG visualization of code size',
    negatable: false,
  )
  ..addOption(
    'out',
    help:
        'Output directory for generated files. Default is the analyzed directory.',
  )
  ..addOption(
    'out-svg-files',
    help: 'Custom output file path for files SVG export.',
  )
  ..addOption(
    'out-svg-folders',
    help: 'Custom output file path for folders SVG export.',
  )
  ..addOption(
    'out-svg-loc',
    help: 'Custom output file path for LOC treemap SVG export.',
  )
  ..addOption(
    'out-mermaid',
    help: 'Custom output file path for Mermaid export.',
  )
  ..addOption(
    'out-plantuml',
    help: 'Custom output file path for PlantUML export.',
  )
  ..addFlag(
    'json',
    help: 'Output results in structured JSON format',
    negatable: false,
  )
  ..addOption(
    'list',
    abbr: 'l',
    help:
        'Control list output: none | partial | full | filenames | <number> (max items per list, e.g. 3 or 999)',
    defaultsTo: ReportListMode.partial.cliName,
  )
  ..addFlag('version', abbr: 'v', help: 'Show fCheck version', negatable: false)
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
    'no-colors',
    help: 'Disable ANSI colors in CLI output',
    negatable: false,
  )
  ..addFlag('help', abbr: 'h', help: 'Show usage information', negatable: false)
  ..addFlag(
    'help-ignore',
    help: 'Show ignore setup for each analyzer and .fcheck options',
    negatable: false,
  )
  ..addFlag(
    'help-score',
    help: 'Show scoring model used for compliance score (0-100)',
    negatable: false,
  );

/// Parses command-line input into a [ConsoleInput] value.
///
/// Throws [FormatException] when arguments are invalid.
///
/// If both `--input` and a positional path are provided, `--input` wins.
ConsoleInput parseConsoleInput(List<String> arguments, ArgParser parser) {
  final argResults = parser.parse(arguments);

  final explicitPath = argResults['input'] as String;
  final listOption = _parseListOption(argResults['list'] as String);
  final svgShortcut = argResults['svg'] as bool;
  final path = explicitPath != '.'
      ? explicitPath
      : argResults.rest.isNotEmpty
      ? argResults.rest.first
      : '.';

  return ConsoleInput(
    path: path,
    fix: argResults['fix'] as bool,
    generateMermaid: argResults['mermaid'] as bool,
    generatePlantUML: argResults['plantuml'] as bool,
    generateSvg: (argResults['svgfiles'] as bool) || svgShortcut,
    generateFolderSvg: (argResults['svgfolder'] as bool) || svgShortcut,
    generateSizeSvg: (argResults['svgloc'] as bool) || svgShortcut,
    outputDirectory: _optionalTrimmed(argResults['out'] as String?),
    outputSvgFilesPath: _optionalTrimmed(
      argResults['out-svg-files'] as String?,
    ),
    outputSvgFoldersPath: _optionalTrimmed(
      argResults['out-svg-folders'] as String?,
    ),
    outputSvgLocPath: _optionalTrimmed(argResults['out-svg-loc'] as String?),
    outputMermaidPath: _optionalTrimmed(argResults['out-mermaid'] as String?),
    outputPlantUmlPath: _optionalTrimmed(argResults['out-plantuml'] as String?),
    outputJson: argResults['json'] as bool,
    listMode: listOption.mode,
    listItemLimit: listOption.limit,
    listExcluded: argResults['excluded'] as bool,
    excludePatterns: argResults['exclude'] as List<String>,
    showHelp: argResults['help'] as bool,
    showVersion: argResults['version'] as bool,
    showIgnoresInstructions: argResults['help-ignore'] as bool,
    showScoreInstructions: argResults['help-score'] as bool,
    noColors: argResults['no-colors'] as bool,
  );
}

/// Extract the number of lines expected in the list output
_ListOption _parseListOption(String rawValue) {
  final normalized = rawValue.trim().toLowerCase();
  final namedMode = ReportListMode.fromCliName(normalized);
  if (namedMode != null) {
    return _ListOption(mode: namedMode, limit: defaultListItemLimit);
  }

  final parsedLimit = int.tryParse(normalized);
  if (parsedLimit != null && parsedLimit > 0) {
    return _ListOption(mode: ReportListMode.partial, limit: parsedLimit);
  }

  throw const FormatException(
    'Invalid --list value. Use none, partial, full, filenames, or a positive integer.',
  );
}

class _ListOption {
  final ReportListMode mode;
  final int limit;

  const _ListOption({required this.mode, required this.limit});
}

/// Remove blank space, in a null safe way
String? _optionalTrimmed(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
