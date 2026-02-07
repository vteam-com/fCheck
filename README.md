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

- **⚡ High Performance**: 67%+ faster analysis with unified file traversal and execution timing
- **⚠️ No Duplication**: Unlike Flutter LINT or Dart compiler, fcheck focuses on unique architectural and structural analysis
- **📊 Project Overview**: Files, folders, lines of code, comment ratios
- **✅ Code Quality**: One class per file compliance, member sorting
- **🔍 Issue Detection**: Hardcoded strings, magic numbers, layer violations, secrets
- **⏱️ Performance Tracking**: Shows exact execution time for analysis runs
- **🌐 Visualizations**: SVG, Mermaid, and PlantUML dependency graphs

## 📈 Example Output

```text
↓ --------------------------------- fCheck 0.8.5 --------------------------------- ↓
Project          : my_app (version: 1.0.0)
Project Type     : Flutter | Dart
Folders          : 14
Files            : 57
Dart Files       : 36
Excluded Files   : 19
Lines of Code    : 7,550
Comment Lines    : 1,452
Comment Ratio    : 19.23%
Localization     : No
Hardcoded Strings: 7 (warning)
Magic Numbers    : 0
Secrets          : 0
Layers           : 6
Dependencies     : 73
↓····································· Lists ·····································↓
[✓] One class per file check passed.
[!] Hardcoded strings check: 7 found (localization off). Example: fcheck.dart
[✓] Magic numbers check passed.
[✓] Flutter class member sorting passed.
[✓] Secrets scan passed.
[✓] Layers architecture check passed.
↓································· Output files ·································↓
SVG layers         : ./layers.svg
SVG layers (folder): ./layers_folders.svg
↑--------------------------- fCheck completed (0.43s) ---------------------------↑
```

## ⚡ Performance Optimization

fcheck now features **unified file traversal** that dramatically improves analysis speed:

### How It Works

- **Single File Discovery**: One directory scan instead of 6+ separate traversals
- **Shared AST Parsing**: Each file parsed once, results shared across all analyzers
- **Cached File Context**: Eliminates redundant I/O operations
- **Parallel Delegation**: Multiple analyzers work on the same file context

### Performance Gains

- **67-72% faster** analysis on typical projects
- **Scales better** with larger codebases
- **Same results** with better performance
- **Built-in timing** to track analysis speed

### Usage

The performance optimization is automatic - just use fcheck normally:

```bash
# Uses optimized unified traversal automatically
fcheck /path/to/project

# All existing features work with the optimization
fcheck --svg --fix
```

## ⏱️ Execution Timing

fcheck automatically tracks and displays how long each analysis takes:

```text
↑ --------------------------- fCheck completed (0.42s) --------------------------- ↑
```

### Timing Features

- **Precise Measurement**: Shows elapsed time in seconds with 2 decimal places
- **Always Visible**: Displayed in footer for all output modes (except JSON)
- **Performance Tracking**: Helps monitor analysis performance over time
- **JSON Compatible**: Automatically suppressed in JSON output to maintain clean format

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

# List excluded files and directories
fcheck --excluded
```

### Excluded Files Listing

Use the `--excluded` flag to see exactly which files and directories are being excluded from analysis:

```bash
# List excluded files and directories
fcheck --excluded

# List excluded files in JSON format
fcheck --excluded --json
```

#### Example Output

```text
Excluded Dart files (18):
  ./test/layers_analyzer_test.dart
  ./test/analyzer_engine_test.dart
  ./example/lib/comments_example.dart
  ./example/lib/subfolder/subclass.dart
  ...

Excluded non-Dart files (1,528):
  ./.DS_Store
  ./.fcheck
  ./example/pubspec.lock
  ./example/layers.svg
  ...

Excluded directories (15):
  ./.git
  ./.dart_tool
  ./test
  ./example
  ./build
  ...
```

#### What Gets Excluded

**By Default:**

- Hidden directories (starting with `.`)
- Common project directories: `test/`, `example/`, `tool/`, `.dart_tool/`, `build/`, `.git/`, `ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`
- Generated localization files (except main `app_localizations.dart`)

**With Custom Patterns:**

- Files matching glob patterns specified with `--exclude`
- Files in directories matching exclude patterns

**Hidden Directory Filtering:**

- Any directory starting with `.` is automatically excluded
- This includes `.git`, `.dart_tool`, `.vscode`, etc.
- Nested hidden directories are also excluded (e.g., `src/.cache/`)

## 🎯 Quality Checks

### One Class Per File Rule

- ✅ **Compliant**: 1 public class per file (or 2 for StatefulWidget)
- ❌ **Violation**: Too many public classes in one file

**Opt-out**: Add `// ignore: fcheck_one_class_per_file` at the top of the file

### Magic Numbers

- 🔍 **Detects**: Numeric literals other than `0`, `1`, or `-1` when they appear inline in code (i.e., not part of an annotation, a `const` declaration, a `static const`, a descriptive `final` numeric, or a `const` expression like const lists/maps/sets/constructors).
- ✅ **Allows**: Descriptive `const`/`static const`/`final` numerics (name length > 3), annotation values, and all const expressions. Example: `final int defaultRetryCount = 2;` is allowed because the name is descriptive.
- 🔧 **How to fix**: Replace inline literals with a named `const`/`static const`/`final` value (e.g., `const defaultTimeoutMs = 5000;`) or move the literal into a const expression that already documents intent.

**Opt-out**: Add `// ignore: fcheck_magic_numbers` at the top of the file

### Hardcoded Strings

- ⚠️ **Caution**: Potential user-facing strings (project not localized)
- ❌ **Error**: Hardcoded strings when localization is enabled

**Opt-out**: Add `// ignore: fcheck_hardcoded_strings` at the top of the file
**Alternative**: Add `// ignore_for_file: avoid_hardcoded_strings_in_widgets` at the top of the file

### Secrets Detection

- 🔒 **Security**: Detects API keys, tokens, private keys, and other sensitive information
- 🚨 **Critical**: AWS keys, GitHub PATs, Stripe keys, emails
- 📊 **Advanced**: High entropy string detection for unknown secret patterns

**Opt-out**: Add `// ignore: fcheck_secrets` at the top of the file

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
// ignore: fcheck_secrets
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
