# AGENT RULES

- READ ALL THE RULES
- Update the README.md and RULES if needed
- Update the sequence_diagram.svg if the system flow has changed
- After any code change, run fCheck on the fCheck repo itself and fix all warnings it reports before finishing.
- NO MAGIC NUMBERS
- ALWAYS EXTRACT NUMERIC LITERALS INTO NAMED CONSTANTS (file-level `const`), except canonical sentinel values `-1`, `0`, and `1` when they are semantically obvious
- NO DEAD CODE
- **CENTRALIZE USER-FACING STRINGS**: Do not add new inline user-facing CLI/help/report strings when an aggregation file already exists. Reuse or extend `lib/src/models/app_strings.dart` instead of introducing raw `print('...')` text in console/report code.
- **ANALYZER NAMING AND SORTING**: All analyzer display names must start with uppercase letter, be in title case, and sort keys must match the analyzer title mapping in `console_output_report_helpers.dart` and use underscore format.
- **ANALYZER BLOCK ORDER**: Analyzer report blocks must be ordered exactly as implemented and documented: clean analyzers (`[✓]`) first, disabled analyzers (`[-]`) second, warning/failing analyzers (`[!]`, `[x]`) last. Do not describe or document a different order from the actual sort logic.
- **DOCS MUST MATCH CODE**: When changing user-facing behavior, examples, README/RULES text, or release notes, verify the documented contract against the real implementation and tests before finishing.
- Rules from PUB.DEV
  - Search engines display only the first part of the description. Try to keep the value of the description field in your package's pubspec.yaml file between 60 and 180 characters.
  - All public API must be documented
