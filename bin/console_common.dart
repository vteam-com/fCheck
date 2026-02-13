import 'package:fcheck/src/models/app_strings.dart';

/// Usage banner shown in `--help` and argument errors.
const String usageLine = AppStrings.usageLine;

/// Short description shown in `--help`.
const String descriptionLine = AppStrings.descriptionLine;

/// Error message shown when arguments fail parsing.
const String invalidArgumentsLine = AppStrings.invalidArgumentsLine;

/// Controls how detailed issue lists are printed in console reports.
enum ReportListMode {
  /// Do not print the Lists section (summary only).
  none(
    cliName: 'none',
    help: AppStrings.summaryOnly,
  ),

  /// Print a partial list (default).
  partial(
    cliName: 'partial',
    help: '10 ${AppStrings.itemsPerList} (${AppStrings.disabled} by default)',
  ),

  /// Print the full list.
  full(
    cliName: 'full',
    help: AppStrings.showAllEntries,
  ),

  /// Print unique file names only.
  filenames(
    cliName: 'filenames',
    help: AppStrings.uniqueFileNamesOnly,
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
