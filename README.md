# fcheck

A command-line tool for analyzing the quality of Flutter and Dart projects. It provides comprehensive metrics including code statistics, comment ratios, and compliance with coding standards like the "one class per file" rule.

## Features

- 📊 **Project Statistics**: Total files, folders, lines of code, and comment ratios
- 📝 **Comment Analysis**: Measures code documentation levels
- ✅ **Code Quality Checks**: Validates compliance with "one class per file" rule
- 🎯 **StatefulWidget Support**: Special handling for Flutter StatefulWidget classes
- 🔍 **Hardcoded String Detection**: Identifies potentially hardcoded user-facing strings
- 🔧 **Source Code Sorting**: Ensures Flutter class members are properly organized
- 📁 **Recursive Analysis**: Scans entire project directory trees
- 🚀 **Fast CLI**: Command-line interface with simple usage

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/vteam-com/fCheck.git
cd fcheck
```

2. Install dependencies:
```bash
dart pub get
```

3. Run the tool:
```bash
dart run bin/fcheck.dart --path /path/to/your/flutter/project
```

### As a Global Tool

```bash
# Activate as a global Dart package
dart pub global activate fcheck

# Run from anywhere
fcheck --path /path/to/your/project
```

## Usage

### Basic Usage

```bash
# Analyze current directory
dart run fcheck

# Analyze specific project
dart run fcheck --path /path/to/project

# Use short option
dart run fcheck -p /path/to/project
```

### Example Output

```
Analyzing project at: /path/to/project...
--- Quality Report ---
Total Folders: 15
Total Files: 89
Total Dart Files: 23
Total Lines of Code: 2456
Total Comment Lines: 312
Comment Ratio: 12.70%
----------------------
❌ 3 files violate the "one class per file" rule:
  - lib/widgets.dart (4 classes found)
  - lib/main.dart (2 classes found)
  - lib/models.dart (3 classes found)

⚠️ 6 potential hardcoded strings detected:
  - lib/ui/messages.dart:15: "Welcome back!"
  - lib/screens/login.dart:42: "Please enter your password"
  - lib/widgets/buttons.dart:23: "Submit"

✅ All Flutter classes have properly sorted members.
```

## Quality Metrics

### Project Statistics
- **Total Folders**: Number of directories in the project
- **Total Files**: Total number of files (all types)
- **Total Dart Files**: Number of `.dart` files analyzed
- **Total Lines of Code**: Sum of all lines in Dart files
- **Total Comment Lines**: Lines containing comments
- **Comment Ratio**: Percentage of lines that are comments

### Code Quality Rules

#### One Class Per File Rule
- **Public Classes**: Maximum 1 public class per file (classes not starting with `_`)
- **StatefulWidget Files**: Maximum 2 public classes per file (widget + state)
- **Private Classes**: Unlimited (implementation details starting with `_`)
- **Violations**: Files with too many public classes are flagged

## Library Usage

You can also use fcheck as a Dart library in your own tools:

```dart
import 'package:fcheck/evaluator.dart';

void main() {
  final projectDir = Directory('/path/to/project');
  final engine = AnalyzerEngine(projectDir);
  final metrics = engine.analyze();

  // Access metrics programmatically
  print('Total files: ${metrics.totalFiles}');
  print('Comment ratio: ${(metrics.commentRatio * 100).toStringAsFixed(1)}%');

  // Print full report
  metrics.printReport();
}
```

## Quality Standards

### Comment Ratio Guidelines
- **Excellent**: > 20%
- **Good**: 10-20%
- **Needs Improvement**: < 10%

### Class Organization
- **Compliant**: Files with appropriate public class counts
- **StatefulWidget**: Allowed 2 public classes (widget + State)
- **Private Classes**: Unlimited (starting with `_` are implementation details)
- **Non-compliant**: Files with too many public classes

### Member Sorting (Flutter Classes)
- **Proper Order**: Constructors → Fields → Getters/Setters → Methods → Lifecycle Methods
- **Lifecycle Methods**: `initState`, `dispose`, `didChangeDependencies`, `didUpdateWidget`, `build`
- **Field Grouping**: Related getters/setters are grouped with their fields
- **Validation**: Checks if Flutter class members follow consistent organization patterns

## Project Structure

```
fcheck/
├── bin/
│   └── fcheck.dart          # CLI entry point
├── lib/
│   ├── evaluator.dart       # Public API exports
│   └── src/
│       ├── analyzer_engine.dart           # Core analysis logic
│       ├── hardcoded_string_analyzer.dart # Hardcoded string detection
│       ├── hardcoded_string_issue.dart    # Hardcoded string issue model
│       ├── hardcoded_string_visitor.dart  # AST visitor for strings
│       ├── sort_source.dart               # Source code sorting analysis
│       ├── utils.dart                     # File utilities
│       └── models/
│           ├── file_metrics.dart          # File-level metrics
│           └── project_metrics.dart       # Project-level metrics
├── example/                 # Test example project
├── pubspec.yaml             # Package configuration
└── README.md               # This file
```

## Development

### Running Tests

```bash
dart test
```

### Building

```bash
dart pub get
dart compile exe bin/fcheck.dart
```

### Testing with Example

The project includes a test example you can analyze:

```bash
dart run fcheck --path example
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `dart test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Requirements

- Dart SDK >= 3.0.0
- Flutter projects (for Flutter-specific analysis features)
