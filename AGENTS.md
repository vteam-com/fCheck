# AGENT RULES

- READ ALL THE RULES
- Update the README.md and RULES if needed
- Update the sequence_diagram.svg if the system flow has changed
- After any code change, run fCheck on the fCheck repo itself and fix all warnings it reports before finishing.
- NO MAGIC NUMBERS
- ALWAYS EXTRACT NUMERIC LITERALS INTO NAMED CONSTANTS (file-level `const`), except canonical sentinel values `-1`, `0`, and `1` when they are semantically obvious
- NO DEAD CODE
- **ANALYZER NAMING AND SORTING**: All analyzer display names must start with uppercase letter, be in title case, and display in strict alphabetical order. Sort keys must match the analyzer title mapping in `console_output_report_helpers.dart` and use underscore format.
- Rules from PUB.DEV
  - Search engines display only the first part of the description. Try to keep the value of the description field in your package's pubspec.yaml file between 60 and 180 characters.
  - All public API must be documented
