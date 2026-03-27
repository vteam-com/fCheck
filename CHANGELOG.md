# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.2] – 2026-03-27

### Changed

- Improve dead localized key member access pattern to support null assertions and null-safe access
- Improved SVG file-dependency edge routing for cleaner cross-column paths and more readable diagrams.

## [1.1.1] – 2026-03-22

### Fixed

- Improved localization key-usage detection to reduce false positives.
- Localization member access pattern now supports null assertions (`!`) and null-safe access (`?`).
- `--fix` mode now sorts ARB file content by keys for consistent formatting.

### Improved

- SVG file-dependency graph edge routing: elbow paths, lane staggering, and depth-sorted rendering for cleaner diagrams.

### Added

- Additional test coverage for localization analyzer (92% coverage).

## [1.1.0] – 2026-03-19

### Added

- Flutter localization coverage analysis based on ARB files under `lib/l10n/` or project-local ARB fallbacks.
- Detection for missing translations, duplicate top-level ARB keys, placeholder mismatches, empty translations, untranslated copies, and unused English base-locale keys.
- Dedicated localization console reporting with language coverage details and guidance for reviewed or intentionally untranslated entries.

## [1.0.9] – 2026-03-14

### Changed

- Broaden hardcoded-string detection:
  - Switch from a narrow, widget-text heuristic to a default opt-out model.
  - Surface many more inline string literals across app code, including those routed through helpers and wrappers.
  - Keep auto-skipping technical/diagnostic strings such as log/debug output, exception messages, `toString()` content, lookup keys, paths, URLs, query strings, and typed reusable `String` declarations.
  - Best practice: extract constants, localize user-facing copy, and treat the analyzer output as a clean-code quality pass.

### Added

- Orange right side edges when importing files in upper layers

## [1.0.8] 2026-03-06

### Added

- Dashboard now reports test inventory metrics including touched app source targets, test cases.

### Changed

- Reworked dashboard presentation to include platform support and test-metrics sections with clearer report grouping.
- Expanded literals reporting and console formatting for `--literals`, including full listing support and improved colorized output readability.
- Refined project metrics and pubspec parsing to improve release-facing report accuracy.

## [1.0.7] 2026-03-05

### Changed

- Updated `pubspec.yaml` description to a search-friendly length.
- Simplified ignore-inventory console formatting by replacing embedded newline literals with explicit blank-line prints.
  - removed text block `Type: Analyzer skips (legacy ignores.*: true)`
  - removed `legacyIgnores` from ignore-inventory JSON payload sections (`config`, `groupedByType`, `totals`)
- Fixed `--ignores` file discovery to respect default analysis exclusions (for example `.dart_tool/`) and configured `.fcheck` excludes.
- Auto-excluded generated localization root file `app_localizations.dart` from documentation and code-size analyzers.
- Simplified suppressions console output for ignore directives:
  - compact one-line output for ignore-only suppressions  
  - added inline guidance: `use arg --ignores for details`
- Suppressed passive hardcoded-strings summary when localization is `OFF` and detected count is `0` (omit `0 hardcoded strings detected ...` line).

## [1.0.6] 2026-03-05

### Changed

- Updated README.md description to highlight 0-100% compliance scoring system and improve marketing appeal for Pub.dev
- Enhanced main description to emphasize scoring system and CI/CD pipeline value for Flutter engineers

### Added

- **Ignore Inventory Analysis**: New `--ignores` CLI flag to inspect and analyze all ignore/suppression mechanisms in the project
- **Comprehensive Suppression Reporting**: Groups results by suppression type (`exclude`, analyzer skips, and Dart comment directive type) for better cleanup prioritization
- **JSON Support for Ignore Analysis**: Full JSON output support for ignore inventory with `--ignores --json`

## [1.0.5] 2026-03-02

### Added

- Dashboard now reports test coverage discovery metrics (test directories/files/Dart files/cases).
- Dashboard now reports detected platform support (`Android`, `iOS`, `macOS`, `Windows`, `Linux`, `Web`).

### Changed

- Reorganized dashboard layout to improve metrics readability.
- Improved dead-code detection to better handle interpolation usage and reduce false positives for exported library APIs.

## [1.0.4] 2026-03-01

### Added

- Dashboard now reports the total number of widgets (Stateless | Stateful)

### Changed

- Upgraded analyzer dependency to `analyzer: ^11.0.0`.
- Improved parsing for `// ignore: ... fcheck_* ...` directives.
- Increased overall automated test coverage.

## [1.0.3] 2026-02-27

### Added

- `--literals` CLI mode to print a focused literals inventory (console and JSON).

### Changed

- Literals console section was redesigned for readability:
  - Shows aligned summary rows for strings and numbers.
  - Uses "Unique strings found" and "Unique numbers found" headings for inventory lists.
  - Lists hardcoded strings first, including `file:line` locations.
- String literal inventory now ignores directive URIs (`import`, `export`, `part`, `library`).
- Duplicate-number ratio now excludes allowed values `-1`, `0`, and `1`.
- Number literal list ordering is now deterministic and numeric-aware for equal-frequency entries.

### Fixed

- Discovers more cases of Magic Numbers

## [1.0.2] 2026-02-26

### Changed

- Dead code analyzer now treats Flutter `@Preview` functions/methods (including prefixed annotations like `@ui.Preview`) as externally used, so they are not reported as dead functions.

## [1.0.1] 2026-02-25

### Changed

- Exclude app_localization*.dart from large code file analyzer.
- Softer Orange and Red overlay in the SVG diagrams.
- update package "analyzer 10.2.0"

## [1.0.0] 2026-02-24

### Changed

- 💥 **BREAKING CLI Arguments**: Replaced legacy graph/export flags with normalized names:
  - `--svgfiles` -> `--svg-files`
  - `--svgfolder` -> `--svg-folders`
  - `--svgloc` -> `--svg-loc`
  - `--out` -> `--output`
  - `--out-svg-files` -> `--output-svg-files`
  - `--out-svg-folders` -> `--output-svg-folders`
  - `--out-svg-loc` -> `--output-svg-loc`
  - `--out-mermaid` -> `--output-mermaid`
  - `--out-plantuml` -> `--output-plantuml`
- 📄 **Output Filenames**: Default generated artifact names are unchanged in `1.0.0`:
  - `fcheck_files.svg`
  - `fcheck_folders.svg`
  - `fcheck_loc.svg`
  - `fcheck.mmd`
  - `fcheck.puml`
- 📝 **Docs/Tests Alignment**: Updated README, RULES docs, and CLI parsing tests for the v1.0.0 contract.

## [0.9.17] 2026-02-23

### Changed

- 📥 **Source Sorting Auto-fix**: Improved import directive normalization during `--fix` by rewriting relative imports under `lib/` to `package:<current-package>/...` before sorting, while preserving directive suffixes.
- 🧭 **Layers Console Reporting**: Refined layers output so cycle issues remain failures while non-cycle folder-layer upward dependencies are reported as warnings with clearer, colorized path details.

## [0.9.16] 2026-02-21

### Added

- 🔧 **Source Sorting Auto-fix**: `--fix` now also reorders import directives using analyzer-style grouping and alphabetical ordering.

### Changed

- 🚫 **Generated Dart Handling**: `*.g.dart` files are now automatically excluded from non-actionable analyzer findings while still contributing where required for project-wide analysis.
- 📁 **Default Exclusions**: Added `integration_test` to default excluded directories for file discovery and metrics scanning.

## [0.9.15] 2026-02-19

### Added

- 📏 **Code Size Analyzer**: New analyzer for LOC threshold violations across files, classes, functions, and methods.
- ⚙️ **Configurable Code Size Thresholds**: Added `.fcheck` options under `analyzers.options.code_size`:
  - `max_file_loc` (default: `900`)
  - `max_class_loc` (default: `800`)
  - `max_function_loc` (default: `700`)
  - `max_method_loc` (default: `500`)
- 🖼️ **Code Size SVG Export**: Added `--svgsize` CLI flag to generate `fcheck_code_size.svg` treemap output.

### Changed

- 📈 **Compliance Scoring**: Code size now contributes to analyzer scoring and focus area suggestions.

## [0.9.14] 2026-02-18

### Added

- 📊 Dashboard now reports
  - class, method, and function counts.
  - pubspec dependency counts.

### Changed

- 🖥️ Improved CLI output readability with better path and filename coloring.
- 🔢 `--list` now accepts values from 0 to 999.

### Fixed

- 🐛 Corrected line reporting in "one class per file" output.
- 🧹 Resolved all fcheck warnings reported by fcheck on this codebase.

## [0.9.13] 2026-02-17

### Added

- 🧹 **Dead Code Method Detection**: Extended dead code analysis to detect unused methods in classes, mixins, enums, and extensions - not just top-level functions.
- 📝 **Documentation**: Updated README.md and RULES_DEAD_CODE.md to reflect the new method detection capability.

### Changed

- 🖼️ **SVG Folder Improvements**: Enhanced folder dependency visualization with snug gutters and improved edge positioning for cleaner graphs.

## [0.9.12] 2026-02-16

### Fixed

- 🐛 **Layers Analyzer False Positives**: Fixed incorrect folder layer violation detection that was flagging valid parent-child folder dependencies as violations.
  - Changed folder layer computation from MIN to MAX to represent the deepest position of any file in a folder
  - Added logic to allow parent folders to depend on their child subfolders without triggering violations
  - Removed false cross-layer dependency violations that were causing incorrect warnings

### Changed

- 📝 **Documentation**: Updated `RULES_LAYERS.md` to document the new folder layer assignment behavior and violation detection rules
- 🔄 **Terminology**: Changed "higher/lower layers" to "above/below" for clearer understanding of layer hierarchy

## [0.9.11] 2026-02-16

### Added

- 📊 **Enhanced Metrics Analyzer**: New `MetricsAnalyzer` class with scoring logic, focus area detection, and compliance score calculation.
- 📝 **App Strings Analysis**: New `AppStrings` class to extract and analyze application string constants for better code understanding.
- 🧪 **Improved Test Performance**: Optimized test execution with faster test setup and teardown.

### Changed

- 🖥️ **Console Layer Violations**: Improved console reporting for layer folder violations with detailed violation information.
- 🔧 **Hardcoded Strings Logic**: Improved hardcoded string detection to also work for Dart CLI applications (not just Flutter).
- 🛠️ **Publish Script**: Updated `tool/publish.sh` to use Flutter test instead of Dart test for better compatibility.
- ✅ **Code Coverage**: Increased test coverage to 87%.

## [0.9.10] 2026-02-12

### Added

- 📚 Added a documentation analyzer to detect missing docs for public APIs and complex private functions.

### Changed

- 🎨 Updated dashboard ordering and styling, including swapped duplicate-code/dependencies columns and red rendering for comment ratios below 10%.

## [0.9.9] 2026-02-12

### Added

- 🎯 Added a deterministic compliance scorecard with overall score, focus area, and suggested next investment area.
- 📊 Included compliance score details in JSON output (`summary.complianceScore` and `compliance` block).
- 🆘 Added `--help-score` CLI flag to show compliance scoring guidance.

### Changed

- 🖥️ Refined CLI console output layout to include a scorecard section and a denser dashboard summary.
- ✅ Expanded scoring-focused CLI and metrics test coverage.

### Fixed

- 📝 Corrected the dashboard typos.

## [0.9.8] 2026-02-10

### Added

- 🆘 Added `--help-ignore` CLI flag to show per-analyzer ignore directives and `.fcheck` ignore setup guidance.

### Changed

- ♻️ Reused layers analysis results from the main analysis pass when generating graph outputs, instead of running a second layers-analysis traversal.

### Fixed

- ⚡ Removed redundant CLI layers-analysis work during regular runs, reducing unnecessary overhead while preserving output behavior.

## [0.9.7] 2026-02-10

### Added

- 🧩 Shared dependency URI utilities for consistent project import/export resolution across analyzers.

### Changed

- 🖥️ Improved console list formatting for issue lines and duplicate-code alignment.
- 🔧 Refactored analyzer, graph, and config internals to remove duplicated logic and keep behavior consistent.

### Fixed

- 🧭 Project metadata resolution now correctly infers package name/version/type when analyzing from folders without a root `pubspec.yaml`, and returns `unknown` for ambiguous multi-pubspec workspaces.
- ✅ Updated duplicate-code output test expectations after formatting improvements.

## [0.9.6] 2026-02-10

### Added

- 🧬 **Code Duplication Detection**
  - Duplicate-code analysis for similar executable blocks (functions/methods/constructors) using normalized token comparison.
  - Added file-level ignore support with `// ignore: fcheck_duplicate_code`.
  - Support for `.fcheck` options for `similarity_threshold`, `min_tokens`, and `min_non_empty_lines`.

### Changed

- README positioning as an 8-in-1 deterministic workflow.

### Fixed

- removed remaining magic-number literals in duplicate-code analyzer utilities by introducing named constants

## [0.9.5] 2026-02-09

### Added

- support for .fcheck config file

### Fixed

- normalize input path

## [0.9.4] 2026-02-09

### Added

- ✅ Added more test, code coverage is now at 81%

### Changed

- 🧭 **Layers Analyzer** now runs through the unified single directory pass for more consistent dependency analysis.
- 📘 Updated `RULES_LAYERS.md` guidance to match the latest layers analysis behavior.
- 🖥️ Refactored CLI console input/output into focused modules and simplified output rendering paths.
- 🎨 SVG graph exports now use adaptive text sizing to keep labels and titles readable across different graph densities.

## [0.9.3] 2026-02-08

### Added

- 🧾 Control list output (console only)

```bash
fcheck --list none       # summary only
fcheck --list partial    # top 10 per list (default)
fcheck --list full       # full lists
fcheck --list filenames  # unique file names only
```

### Changed

- 📚 Test Code Coverage now at 76%

## [0.9.2] 2026-02-08

### Fixed

- 🧰 **Dead Code Analyzer**: Treat generic class declarations (e.g. `class Box<T>`) as their base class name so usages like `Box<int>` no longer get flagged as dead classes.

## [0.9.1] 2026-02-08

### Fixed

- 🧰 **Dead Code Analyzer**: Avoid flagging constructor field parameters (`this.foo`) as unused when they initialize class properties.
- 🧩 **Dead Code Analyzer**: Avoid flagging parameters in `@override` methods or abstract/external signatures with empty bodies.

## [0.9.0] 2026-02-08

### Added

- 🧹 **Dead Code Analyzer**: Detects dead files, unused top-level classes/functions, and unused local variables using dependency reachability and symbol usage tracking.
- 🚫 **Dead Code Ignore**: New `// ignore: fcheck_dead_code` directive for file-level and node-level suppression.
- 📚 **Rules**: Added `RULES_DEAD_CODE.md` documentation.

### Changed

- 🧩 **Layers Dependency Graph**: Conditional imports/exports (`if (dart.library...)`) are now included in dependency resolution.
- 📊 **Metrics Output**: Added dead code counts and issue lists to CLI and JSON reports.

## [0.8.6] 2026-02-07

### Added

- 🧵 **Hardcoded Strings**: Added support for additional ignore comments (`hardcoded.string`, `hardcoded.ok`, and `avoid_hardcoded_strings_in_widgets`) to suppress specific string literals.

### Changed

- 🔢 **CLI Output**: Counts now use comma separators for thousands grouping.

## [0.8.5] 2026-02-06

### Changed

- 🔐 **Secrets Detection**: Generic secrets now extract assignment values (including triple-quoted strings) and apply entropy/length checks to the value, reducing false positives on full-line scans.
    GH <https://github.com/vteam-com/fCheck/issues/2>
- 🧾 **CLI Output**: Standardized status markers (`[✓]`, `[!]`, `[✗]`) and clarified report messaging, including explicit secrets counts and always showing excluded file counts.
- 📚 **Docs**: Updated rules and comments.

### Removed

- 🧹 **Dead Code**: Dropped legacy per-analyzer classes now superseded by the unified delegate-based analyzer runner.

## [0.8.4] 2026-02-06

### Added

- 📚 **Rules**: Added per-domain rule documents for:
  - hardcoded strings,
  - magic numbers,
  - secrets,
  - code sorting,
  - layers

### Changed

- 🧠 **Hardcoded String Detection**: Improved Flutter vs Dart project handling to make string detection rules project-aware
- 🧹 **Analyzer Refactor**: Reduced duplication across analyzers and utilities.

## [0.8.3] 2026-02-04

### Added

- 🔍 **Hidden Folder Filtering**: Automatically exclude files in hidden directories (starting with '.') from analysis
- 📊 **Excluded Files Listing**: New `--excluded`/`-x` CLI flag to list all excluded files and directories
- 📋 **Comprehensive Exclusion Reporting**: Display excluded Dart files, non-Dart files, and directories separately
- 🎯 **JSON Support for Exclusions**: Full JSON output support for excluded files listing
- 📚 **Enhanced Documentation**: Updated README.md with comprehensive documentation for excluded files functionality

### Changed

- ⚡ **Unified Directory Scanning**: Enhanced `scanDirectory` method to return excluded file/folder counts in addition to regular metrics
- 🏗️ **File Enumeration Logic**: Updated `listDartFiles` method to skip hidden directories consistently
- 📊 **Performance Optimization**: Maintained 67-72% performance improvement while adding new exclusion tracking

## [0.8.2] 2026-02-03

### Changed

- 📘 Clarified the README "Magic Numbers" guidance so it now explains the new definition, outlines when literals are allowed (descriptive const/static/final declarations and annotations/const expressions), and shows how to fix detections by replacing inline literals with named constants before referencing the opt-out directive.

## [0.8.1] 2026-02-02

### Added

- ⏱️ **Execution Timing**: Added elapsed time display in the footer showing how long the analysis took to run
- 📊 **Performance Visibility**: Footer now shows "fCheck completed (X.XXs)" to help users track analysis performance
- 🎯 **JSON Compatibility**: Timing display is automatically suppressed in JSON output mode to maintain clean format

## [0.8.0] 2026-02-02

### ⚡ **Major Performance Optimization**

- 🚀 **Unified Analysis Architecture**: Implemented single-pass file traversal with delegate pattern, eliminating redundant file operations and AST parsing
- 📈 **67-77% Performance Improvement**: Analysis now runs 67-77% faster by performing one file discovery and one AST parse per file shared across all analyzers
- 🔄 **Delegate Pattern**: All analyzers (HardcodedString, MagicNumber, SourceSort, Layers, Secrets) now work from shared parsed file context
- 🎯 **Zero Breaking Changes**: All existing functionality preserved with dramatic performance improvements

### 🏗️ **Architecture Refactoring**

- 📁 **Reorganized Analyzer Structure**: Moved all analyzers to `src/analyzers/` directory for better organization
- 🔧 **AnalyzerRunner**: New unified analysis engine replaces individual analyzer traversals
- 📋 **AnalysisFileContext**: Shared file context eliminates redundant I/O operations
- 🎨 **Cleaner Codebase**: Removed old individual analyzer strategy, fully migrated to unified approach

### 🔍 **Secret Detection**

- 🛡️ **Advanced Secret Analyzer**: Comprehensive secret detection rules
- 🔑 **Multiple Secret Types**: AWS keys, GitHub PATs, Stripe keys, Bearer tokens, Private keys, Email PII, High entropy strings
- 📊 **Entropy-Based Detection**: Advanced entropy calculation for unknown secret patterns
- 🎯 **Improved Accuracy**: Better false positive reduction with configurable thresholds

### 🧹 **Code Quality Improvements**

- ✅ **One Class Per File**: Fixed violations in analyzer files by proper separation
- 📝 **Documentation**: Added comprehensive documentation for all new unified analysis components

### Changed

- ⚡ **Default Analysis Method**: `analyze()` now uses unified high-performance approach automatically
- 🗂️ **File Organization**: Restructured analyzer directories for better maintainability
- 📊 **Result Processing**: Optimized result aggregation with type-safe handling

---

## [0.7.3] 2026-02-01

### Added

- 🔍 **Enhanced pubspec.yaml Detection**: Implemented parent directory traversal to find pubspec.yaml when analyzing from subdirectories, ensuring project name and version are always available regardless of analysis starting point
- 📊 **Improved SVG Folder Display**: Enhanced folder-based SVG visualization to show project name, version, and input folder information instead of generic "." root folder
- 🎨 **Smart Folder Title Formatting**: Implemented intelligent title display - shows only "Project vVersion" when folder name matches project name, or multi-line format "Folder\nProject vVersion" when they differ

### Changed

- 📁 **Folder Name Extraction**: Improved folder name detection logic using proper path handling to ensure accurate folder names in SVG outputs
- 🎯 **SVG Text Rendering**: Enhanced SVG text rendering with proper multi-line support using `<tspan>` elements for better visual hierarchy

## [0.7.2] 2026-01-31

### Changed

- 🛡️ **Default Localization Filtering**: Automatically hide generated localization files (`app_localizations_*.dart`) from analysis and dependency graphs by default while keeping the main entry point to avoid cyclic dependency noise.
- 🧹 **Code Cleanup**: Removed magic number violations across the codebase by introducing named constants for better maintainability.

## [0.7.1] 2026-01-31

### Added

- 🎨 **SVG Style Improvements**: Enhanced CSS styles for SVG exports
- 🏷️ **Badge Tooltips**: Improved tooltip text for better clarity
- 📁 **Folder Layout**: Refined virtual sub-folder logic for folder dependency graphs
- 📝 **Code Documentation**: Updated internal comments for better maintainability

## [0.7.0] 2026-01-30

### Breaking change

- **Unified Ignore Directive System**: Replaced inconsistent ignore patterns with a standardized `// ignore: fcheck_<domain>` format across all analysis domains

### Added

- 🎯 **Generic Ignore Pattern**: New standardized format `// ignore: fcheck_<domain>` for all ignore directives
- 🔧 **One Class Per File Ignore**: Support for `// ignore: fcheck_one_class_per_file` to skip one-class-per-file rule for individual files
- 🧮 **Magic Number Ignore**: Enhanced support for `// ignore: fcheck_magic_numbers` with consistent pattern matching
- 📝 **Hardcoded String Ignore**: Improved `` directive handling
- 🏗️ **Layers Ignore**: Added `// ignore: fcheck_layers` for layer architecture violations
- 📚 **Comprehensive Documentation**: Updated all ignore directive examples and documentation

## [0.6.2] 2026-01-29

### Added

- 🧮 **Magic Number Ignore**: Support for `// fcheck - ignore magic numbers` comment directive to skip magic number analysis for individual files.

## [0.6.1] 2026-01-29

### Added

- 🏷️ **Tooltip Consistency**: Standardized all edge tooltips to use "Source ▶ Target" format across all graph export formats

### Changed

- ⚡ **Performance**: Reduced code duplication and improved maintainability of edge rendering logic

## [0.6.0] 2026-01-29

### Added

- 🔺 **Triangular Directional Badges**: New BadgeModel class with triangular badges that indicate dependency direction (incoming blue pointing west, outgoing green pointing east)
- 📐 **Enhanced Badge Design**: Triangular badges with rounded corners, improved text positioning, and better visual alignment with dependency edges
- 📚 **Comprehensive Documentation**: Added detailed DartDoc comments to BadgeModel class and all its methods
- 🔄 **Edge Alignment Fix**: Updated SVG edge rendering to properly connect to triangular badge centers instead of old circular badge positions

### Changed

- 🎯 **Badge System Refactor**: Complete refactor from circular badges to directional triangular badges with improved visual design
- ⚡ **Performance Improvements**: Optimized badge rendering and edge calculations for better SVG generation

## [0.5.2] 2026-01-29

### Added

- 🧮 **Magic Number Detection**: New feature to detect numeric literals that should be expressed as named constants to make intent clearer

### Changed

- 🔧 Replaced the build_runner-based version builder with a simple bash script that generates `lib/src/models/version.dart` from `pubspec.yaml`.

### Added

- you can optionally add  ```// fcheck: ignore-one-class-per-file``` to a file to ignore the one-class-per-file rule

## [0.5.1] 2026-01-28

### Changed

- 🔧 Replaced the build_runner-based version builder with a simple bash script that generates `lib/src/models/version.dart` from `pubspec.yaml`.

### Added

- you can optionally add  ```// fcheck: ignore-one-class-per-file``` to a file to ignore the one-class-per-file rule

## [0.5.0] 2026-01-27

### Breaking

- 📦 **Library API rename**: `package:fcheck/fcheck.dart` now exposes `AnalyzeFolder` (old `FCheck` is deprecated alias). CLI flags/behavior are unchanged.

### Changed

- 📚 Docs updated to reflect the public API and current source layout.
- 🧹 Shared SVG helpers consolidated in `svg_common.dart` for both SVG generators (no CLI impact).

## [0.4.5] 2026-01-27

### Added

- 📋 **Version Display**: Added `--version` / `-v` flag to show fCheck CLI version
- 🏷️ **Project Metadata**: Analysis reports now include the project name and version from pubspec.yaml
- 🎯 **Enhanced CLI**: Improved argument parsing with better positional vs named argument handling

## [0.4.4] 2026-01-27

### Changed

- ⚠️/❌ **Localization-Aware Hardcoded Strings**: Hardcoded strings now surface as errors (❌ with sample listings) only when a project uses localization (l10n/AppLocalizations/.arb). Non-localized projects show a caution count (⚠️) without listing individual strings.
- 📄 **Docs**: README documents the new localization-aware hardcoded string behavior.

## [0.4.3] 2026-01-26

### Added

- **Shared Diagram Helpers**: Introduced `graph_format_utils.dart` to centralize label normalization, edge counts, and empty-graph stubs used by all diagram generators.

### Changed

- **Refactor**: Mermaid and PlantUML generators now consume the shared helpers, reducing duplication and keeping node IDs/counters consistent.
- **Docs Refresh**: Update comments and README visualization options for Mermaid/PlantUML outputs.

## [0.4.2] 2026-01-24

### Fixed

- 🐛 **Dependency Detection**: Fixed generator import dependencies not showing in `bin/fcheck.dart` by properly qualifying generator function calls with package prefixes.
- 🔗 **SVG Visualization**: Ensured all dependencies from `fcheck.dart` to graph exporters (`export_mermaid.dart`, `export_plantuml.dart`, `export_svg.dart`) are properly displayed in the dependency graph.

### Changed

- 📦 **Import Structure**: Updated generator imports in `bin/fcheck.dart` to use proper package prefixes for better code organization and dependency tracking.

## [0.4.1] 2026-01-23

### Fixed

- 🐛 **Subdirectory Analysis**: Fixed package import resolution when running analysis on a subdirectory (e.g., `lib/`) by correctly identifying the project root.
- 📐 **SVG Layout**: Optimized column-based layout to ensure consistent grouping and correct layer ordering (Layer 1 on the left).
- 🎨 **SVG Z-Order**: Refined drawing order (Layers -> Nodes -> Edges -> Badges -> Labels) so edges are drawn on top of nodes, but behind text.
- ✨ **Visual Polish**: Added outline dilate filter to node labels for superior readability against edges.
- ✨ **Visual Polish**: Added white shadow filter to nodes to improve legibility against background edges.

- 📐 **Node Sorting**: Updated intra-column sorting to prioritize Incident dependencies (Incoming descending, then Outgoing descending), and finally alphabetical.

### Added

- ✨ **JSON Output Mode**: New `--json` flag to output all analysis results in structured JSON format.
- 🏗️ **Robust Layering Analysis**: Implemented Tarjan's SCC algorithm to correctly handle circular dependencies.
- 📐 **Top-Down Layering Logic**: Improved layering algorithm for consistent "cake" layout.

### Changed

- 📝 **Documentation**: Major improvements to layers layout documentation and `README.md`.
- ⚡ **Model Updates**: Metrics and issues now support JSON serialization.

## [0.3.5] 2026-01-21

### Added

- 📚 Comprehensive API documentation for all public constructors and methods
- 🏗️ Private constructor for `FileUtils` utility class to prevent instantiation
- 📖 Enhanced documentation for `ClassVisitor.visitClassDeclaration` method
- 🔧 Added explicit constructor documentation for hardcoded string analysis
- 📋 Complete documentation for all `@override` methods across the codebase

## [0.3.4] 2026-01-21

### Added

- 🛠️ Global CLI executable support via `executables` configuration
- 📦 Users can now install fcheck globally: `dart pub global activate fcheck`
- 🖥️ Direct command execution: `fcheck ./path/` (after global activation)

## [0.3.3] 2026-01-20

### Added

- ✨ Support for positional path arguments (e.g., `dart run fcheck ./path/`)
- 🆕 `--input/-i` option replacing `--path/-p` for better CLI design
- 📚 `--help/-h` flag with comprehensive usage information
- 🎯 'Explicit option wins' logic when both named and positional arguments provided

### Changed

- 🔄 CLI argument parsing to support both positional and named arguments
- 📝 Improved usage messages and help text

### Fixed

- 🐛 Positional arguments now work correctly (original issue resolved)

## [0.3.2] 2026-01-20

- ✨ Added `--fix` / `-f` flag for automatic sorting fixes
- 🔧 Automatically fixes sorting issues by writing properly sorted code back to files
- Refactored sort_source.dart into separate files: source_sort_issue.dart, class_visitor.dart, member_sorter.dart, source_sort_analyzer.dart
- Added silent mode to ProjectMetrics.printReport() to suppress console output during testing

## [0.3.1] 2026-01-20

- Improved pubspec.yaml description with detailed package information (168 characters)
- Added comprehensive documentation for all public APIs in sort_source.dart

## [0.3.0] 2026-01-20

### Added

- ✨ **Source Code Sorting**: New feature to check if Flutter class members are properly sorted
- 📋 **Member Organization Validation**: Ensures Flutter classes follow consistent member ordering
- 🔧 **Automatic Member Sorting**: Detects when class members need reordering for better code organization

### Technical Details

- Added sorting analyzer for analyzing class member ordering
- Added `MemberSorter` class for sorting class members according to Flutter best practices
- Integrated sorting checks into the main analysis pipeline
- Supports proper ordering: constructors → fields → getters/setters → methods → lifecycle methods

## [0.2.0] 2026-01-20

### Changed

- Upgraded analyzer package to ^10.0.1 for better compatibility
- Updated code to use new analyzer API methods (replaced deprecated name.lexeme with toString())
- Modified file analysis to exclude example/, test/, tool/, and build directories from production code metrics
- Migrated sort_source.dart to work with analyzer ^10.0.1 API changes
- Updated sorting analyzer to use consistent directory exclusion filtering

### Fixed

- Removed unused _classNode field from MemberSorter class
- Fixed compatibility issues with analyzer package version 10.x
- Resolved issue where example directory with intentional "bad code" was being analyzed
- Updated deprecated analyzer API usage in sort_source.dart with appropriate ignore comments
- Fixed dangling library doc comments in bin/fcheck.dart and project_metrics.dart

## [0.1.0] 2026-01-20

### Added

- Initial release of fcheck - a Flutter/Dart code quality analysis tool
- Project structure analysis (folders, files, lines of code, comment ratios)
- One class per file rule enforcement
- Hardcoded string detection
- Command-line interface with path options
- Comprehensive test suite
- MIT license
- Repository information in pubspec.yaml

### Features

- Analyze Flutter and Dart projects for code quality metrics
- Detect violations of one class per file rule
- Identify potential hardcoded strings
- Generate detailed quality reports
- CLI support with customizable paths

### Technical Details

- Built with Dart SDK >=3.0.0 <4.0.0
- Uses analyzer package for AST parsing
- Supports both individual file and directory analysis
- Cross-platform command-line tool
