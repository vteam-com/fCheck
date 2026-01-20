# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
