import 'package:fcheck/src/models/app_strings.dart';

/// Usage banner shown in `--help` and argument errors.
const String usageLine = AppStrings.usageLine;

/// Short description shown in `--help`.
const String descriptionLine = AppStrings.descriptionLine;

/// Error message shown when arguments fail parsing.
const String invalidArgumentsLine = AppStrings.invalidArgumentsLine;
const int defaultListItemLimit = 10;

/// Controls how detailed issue lists are printed in console reports.
enum ReportListMode {
  /// Do not print the Lists section (summary only).
  none(cliName: 'none', help: AppStrings.summaryOnly),

  /// Print a partial list (default).
  partial(
    cliName: 'partial',
    help:
        '$defaultListItemLimit ${AppStrings.itemsPerList} (${AppStrings.disabled} by default)',
  ),

  /// Print the full list.
  full(cliName: 'full', help: AppStrings.showAllEntries),

  /// Print unique file names only.
  filenames(cliName: 'filenames', help: AppStrings.uniqueFileNamesOnly);

  const ReportListMode({required this.cliName, required this.help});

  /// The CLI argument value used for this mode.
  final String cliName;

  /// Human-readable help text for this mode.
  final String help;

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
