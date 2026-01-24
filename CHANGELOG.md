# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2026-01-24

### Fixed

- 🐛 **Dependency Detection**: Fixed generator import dependencies not showing in `bin/fcheck.dart` by properly qualifying generator function calls with package prefixes.
- 🔗 **SVG Visualization**: Ensured all dependencies from `fcheck.dart` to generator files (`mermaid_generator.dart`, `plantuml_generator.dart`, `svg_generator.dart`) are properly displayed in the dependency graph.

### Changed

- 📦 **Import Structure**: Updated generator imports in `bin/fcheck.dart` to use proper package prefixes for better code organization and dependency tracking.

## [0.4.1] - 2026-01-23

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

- 📝 **Documentation**: Major improvements to `LAYOUT.md` and `README.md`.
- ⚡ **Model Updates**: Metrics and issues now support JSON serialization.

## [0.3.5] - 2026-01-21

### Added

- 📚 Comprehensive API documentation for all public constructors and methods
- 🏗️ Private constructor for `FileUtils` utility class to prevent instantiation
- 📖 Enhanced documentation for `ClassVisitor.visitClassDeclaration` method
- 🔧 Added explicit constructor documentation for `HardcodedStringAnalyzer`
- 📋 Complete documentation for all `@override` methods across the codebase

## [0.3.4] - 2026-01-21

### Added

- 🛠️ Global CLI executable support via `executables` configuration
- 📦 Users can now install fcheck globally: `dart pub global activate fcheck`
- 🖥️ Direct command execution: `fcheck ./path/` (after global activation)

## [0.3.3] - 2026-01-20

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

## [0.3.2] - 2026-01-20

- ✨ Added `--fix` / `-f` flag for automatic sorting fixes
- 🔧 Automatically fixes sorting issues by writing properly sorted code back to files
- Refactored sort_source.dart into separate files: source_sort_issue.dart, class_visitor.dart, member_sorter.dart, source_sort_analyzer.dart
- Added silent mode to ProjectMetrics.printReport() to suppress console output during testing

## [0.3.1] - 2026-01-20

- Improved pubspec.yaml description with detailed package information (168 characters)
- Added comprehensive documentation for all public APIs in sort_source.dart

## [0.3.0] - 2026-01-20

### Added

- ✨ **Source Code Sorting**: New feature to check if Flutter class members are properly sorted
- 📋 **Member Organization Validation**: Ensures Flutter classes follow consistent member ordering
- 🔧 **Automatic Member Sorting**: Detects when class members need reordering for better code organization

### Technical Details

- Added `SourceSortAnalyzer` class for analyzing class member ordering
- Added `MemberSorter` class for sorting class members according to Flutter best practices
- Integrated sorting checks into the main analysis pipeline
- Supports proper ordering: constructors → fields → getters/setters → methods → lifecycle methods

## [0.2.0] - 2026-01-20

### Changed

- Upgraded analyzer package to ^10.0.1 for better compatibility
- Updated code to use new analyzer API methods (replaced deprecated name.lexeme with toString())
- Modified file analysis to exclude example/, test/, tool/, and build directories from production code metrics
- Migrated sort_source.dart to work with analyzer ^10.0.1 API changes
- Updated SourceSortAnalyzer to use consistent directory exclusion filtering

### Fixed

- Removed unused _classNode field from MemberSorter class
- Fixed compatibility issues with analyzer package version 10.x
- Resolved issue where example directory with intentional "bad code" was being analyzed
- Updated deprecated analyzer API usage in sort_source.dart with appropriate ignore comments
- Fixed dangling library doc comments in bin/fcheck.dart and project_metrics.dart

## [0.1.0] - 2026-01-20

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
