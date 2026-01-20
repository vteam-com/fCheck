# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
