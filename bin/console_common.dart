/// Usage banner shown in `--help` and argument errors.
const String usageLine = 'Usage: dart run fcheck [options] [<folder>]';

/// Short description shown in `--help`.
const String descriptionLine =
    'Analyze Flutter/Dart code quality and provide metrics.';

/// Error message shown when arguments fail parsing.
const String invalidArgumentsLine = 'Error: Invalid arguments provided.';

/// Controls how detailed issue lists are printed in console reports.
enum ReportListMode {
  /// Do not print the Lists section (summary only).
  none(
    cliName: 'none',
    help: 'Summary only (no Lists section)',
  ),

  /// Print a partial list (default).
  partial(
    cliName: 'partial',
    help: 'Top 10 items per list (default)',
  ),

  /// Print the full list.
  full(
    cliName: 'full',
    help: 'Show all list entries',
  ),

  /// Print unique file names only.
  filenames(
    cliName: 'filenames',
    help: 'Show unique file names only',
  );

  const ReportListMode({
    required this.cliName,
    required this.help,
  });

  /// The CLI argument value used for this mode.
  final String cliName;

  /// Human-readable help text for this mode.
  final String help;

  /// Allowed values for the `--list` CLI option.
  static List<String> get cliNames =>
      values.map((mode) => mode.cliName).toList(growable: false);

  /// Help text keyed by `--list` value.
  static Map<String, String> get cliHelp => <String, String>{
        for (final mode in values) mode.cliName: mode.help,
      };

  /// Finds the mode for a CLI argument value.
  static ReportListMode? fromCliName(String name) {
    for (final value in values) {
      if (value.cliName == name) {
        return value;
      }
    }
    return null;
  }
}
