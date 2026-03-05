# AGENT RULES

- READ ALL THE RULES
- Update the README.md and RULES if needed
- Update the sequence_diagram.svg if the system flow has changed
- NO MAGIC NUMBERS
- ALWAYS EXTRACT NUMERIC LITERALS INTO NAMED CONSTANTS (file-level `const`), except canonical sentinel values `-1`, `0`, and `1` when they are semantically obvious
- NO DEAD CODE
- Rules from PUB.DEV
  - Search engines display only the first part of the description. Try to keep the value of the description field in your package's pubspec.yaml file between 60 and 180 characters.
  - All public API must be documented
