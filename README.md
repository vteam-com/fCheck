# fcheck

A command-line tool for analyzing the quality of Flutter and Dart projects. Get instant insights into your codebase with comprehensive metrics and quality checks.

## 🚀 Quick Start

```bash
# Install
dart pub global activate fcheck

# Analyze your project & Generate beautiful dependency diagrams
fcheck /path/to/your/project --svg
```

## ✨ What fcheck Does

fcheck analyzes your Flutter/Dart project and provides:

- **📊 Project Overview**: Files, folders, lines of code, comment ratios
- **✅ Code Quality**: One class per file compliance, member sorting
- **🔍 Issue Detection**: Hardcoded strings, magic numbers, layer violations
- **🌐 Visualizations**: SVG, Mermaid, and PlantUML dependency graphs

## 📈 Example Output

```text
↓ -------- fCheck v0.6.2 -------- ↓
Project          : my_app (version: 1.0.0)
Folders          : 15
Files            : 89
Dart Files       : 23
Lines of Code    : 2,456
Comment Lines    : 312
Comment Ratio    : 12.70%
Hardcoded Strings: 6
Magic Numbers    : 2
Layers           : 5
Dependencies     : 12

✅ All files comply with the "one class per file" rule.
⚠️ 6 potential hardcoded strings detected
🔧 2 Flutter classes have unsorted members
✅ All layers architecture complies with standards.
↑ ----------------------- ↑
```

## 🛠️ Installation

### Option 1: Global Installation (Recommended)

```bash
dart pub global activate fcheck
```

### Option 2: DevDependencies

```bash
dart pub add fcheck -d
dart run fcheck
```

## 📋 Usage

### Basic Commands

```bash
# Analyze current directory
fcheck

# Analyze specific project
fcheck /path/to/project

# Show help
fcheck --help

# Show version
fcheck --version

# Generate SVG dependency graph
fcheck --svg

# Generate folder-based visualization
fcheck --svgfolder

# Output as JSON
fcheck --json

# Auto-fix sorting issues
fcheck --fix
```

## 🎯 Quality Checks

### One Class Per File Rule

- ✅ **Compliant**: 1 public class per file (or 2 for StatefulWidget)
- ❌ **Violation**: Too many public classes in one file

**Opt-out**: Add `// ignore: fcheck_one_class_per_file` at the top of the file

### Magic Numbers

- 🔍 **Detects**: Numeric literals (except 0, 1, -1) used directly in code
- ✅ **Allows**: Constants, annotation values, common numbers

**Opt-out**: Add `// ignore: fcheck_magic_numbers` at the top of the file

### Hardcoded Strings

- ⚠️ **Caution**: Potential user-facing strings (project not localized)
- ❌ **Error**: Hardcoded strings when localization is enabled

**Opt-out**: Add `// ignore: fcheck_hardcoded_strings` at the top of the file

### Member Sorting

- 🔧 **Auto-fix**: Reorganizes Flutter class members automatically
- ✅ **Validates**: Proper order of constructors, fields, methods, lifecycle methods

## 🌐 Visualizations

### SVG Dependency Graph

```bash
fcheck --svg
```

Generates `layers.svg` showing:

- Layered architecture (Layer 1 = entry points)
- File dependencies with directional edges
- Interactive tooltips
![Dependency Graph Visualization](https://raw.githubusercontent.com/vteam-com/fcheck/main/layers.svg)

### Folder-Based Visualization

```bash
fcheck --svgfolder
```

- Shows files grouped by folders with dependencies.
![Folder-Based Dependency Graph Visualization](https://raw.githubusercontent.com/vteam-com/fcheck/main/layers_folders.svg)

### Mermaid & PlantUML

```bash
fcheck --mermaid    # Generates layers.mmd
fcheck --plantuml   # Generates layers.puml
```

## 📊 Understanding the Output

### Project Statistics

- **Folders**: Number of directories
- **Files**: Total files in project
- **Dart Files**: `.dart` files analyzed
- **Lines of Code**: Total lines in Dart files
- **Comment Ratio**: Documentation percentage

### Quality Indicators

- ✅ **All good**: No issues found
- ⚠️ **Caution**: Potential issues (non-blocking)
- ❌ **Error**: Violations that need attention
- 🔧 **Fixable**: Issues that can be auto-fixed

## 🛡️ Default Exclusions

By default, **fcheck** excludes common non-project directories:
`example/`, `test/`, `tool/`, `.dart_tool/`, `build/`, `.git/`, `ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`.

### Localization Filtering

To reduce noise and avoid cyclic dependency displays from generated code, **fcheck** automatically filters out generated localization files:
- 🙈 **Excluded**: `app_localizations_*.dart` and `app_localization_*.dart` (generated locale-specific files)
- ✅ **Included**: `app_localizations.dart` (the main entry point)

## 🔧 Configuration

### Global Ignore (`.fcheck` file)

Create a `.fcheck` file in your project root:

```yaml
ignores:
  magic_numbers: true
  hardcoded_strings: true
  layers: true
```

### Per-File Ignore

Add at the top of any Dart file:

```dart
// ignore: fcheck_one_class_per_file
// ignore: fcheck_magic_numbers
// ignore: fcheck_hardcoded_strings
// ignore: fcheck_layers
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run `./tool/check.sh` to ensure quality
5. Submit a pull request

## 📋 Requirements

- Dart SDK >= 3.0.0
- Works with any Flutter/Dart project

## 📄 License

MIT License - see LICENSE file for details.
