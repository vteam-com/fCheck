import 'fcheck_cli_runner.dart';

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
  runCli(arguments);
}
