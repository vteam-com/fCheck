# fcheck

Fast quality checks for Flutter and Dart. Run one command to see architecture issues, risky strings, magic numbers, and high-level project metrics - without replacing your existing lint setup.

## ✨ Why fcheck

- **Easy wins**: actionable checks in a single run
- **Architectural focus**: layers, one-class-per-file, sorting
- **Risk detection**: secrets, hardcoded strings, magic numbers
- **Code surface reduction**: dead code
- **Fast**: optimized traversal, visible timing
- **Nice output**: JSON and diagrams when you need them

fcheck exists to fill a gap today. We hope these features become first-class in Dart and Flutter by default, and that one day you won’t need fcheck at all.

## 🛠️ Installation

```bash
# Global (recommended)
dart pub global activate fcheck
fcheck .
```

```bash
# Project-local
dart pub add fcheck -d
dart run fcheck .
```

## 🚀 Quick Start

If you installed project-local, run the same commands with `dart run` (for example, `dart run fcheck --json`).

```bash
# Analyze current folder
fcheck .

# Analyze a different folder (positional)
fcheck ../my_app

# Analyze a different folder (explicit option)
fcheck --input ../my_app

# CI-friendly output
fcheck --json

# Generate all dependency graph outputs
fcheck --svg --svgfolder --mermaid --plantuml
```

## 📈 Example Output

```text
↓--------------------------------- fCheck 0.9.4 ---------------------------------↓
Input            : /Users/me/my_app/.
Project          : my_app (version: 1.0.0)
Project Type     : Dart
Folders          : 14
Files            : 57
Dart Files       : 36
Excluded Files   : 19
Lines of Code    : 7,550
Comment Lines    : 1,452
Comment Ratio    : 19%
Localization     : No
Hardcoded Strings: 7 (warning)
Magic Numbers    : 0
Secrets          : 0
Dead Code        : 0
Layers           : 6
Dependencies     : 73
↓····································· Lists ·····································↓
[✓] One class per file check passed.
[!] Hardcoded strings check: 7 found (localization off). Example: fcheck.dart
[✓] Magic numbers check passed.
[✓] Flutter class member sorting passed.
[✓] Secrets scan passed.
[✓] Dead code check passed.
[✓] Layers architecture check passed.
↓································· Output files ·································↓
SVG layers         : ./layers.svg
SVG layers (folder): ./layers_folders.svg
↑--------------------------- fCheck completed (0.43s) ---------------------------↑
```

## 📋 Usage

### Target Folder

```bash
# Current folder (default)
fcheck .

# Positional folder
fcheck ../my_app

# Explicit folder option (wins over positional folder)
fcheck --input ../my_app
```

### Report Controls

```bash
# Output as JSON (machine-readable)
fcheck --json

# Control list output (console only)
fcheck --list none       # summary only
fcheck --list partial    # top 10 per list (default)
fcheck --list full       # full lists
fcheck --list filenames  # unique file names only

# Exclude custom patterns
fcheck --exclude "**/generated/**" --exclude "**/*.g.dart"

# Show excluded files/directories
fcheck --excluded

# Excluded items as JSON
fcheck --excluded --json
```

### Visualizations

```bash
fcheck --svg
fcheck --svgfolder
fcheck --mermaid
fcheck --plantuml
```

### Utility Commands

```bash
# Show help
fcheck --help

# Show version
fcheck --version

# Auto-fix sorting issues
fcheck --fix
```

## 🙈 Ignore Warnings (Quick Opt-Out)

You can silence a specific warning with a `// ignore:` comment on the same line,
or ignore an entire file by placing a directive at the top (before any code).

### File-Level Ignore (entire file)

```dart
// ignore: fcheck_hardcoded_strings
// ignore: fcheck_magic_numbers
// ignore: fcheck_secrets
// ignore: fcheck_dead_code
// ignore: fcheck_layers
// ignore: fcheck_one_class_per_file
```

### Hardcoded Strings (extra ignores)

fcheck also respects common analyzer ignore comments used in Flutter projects:

```dart
// ignore_for_file: avoid_hardcoded_strings_in_widgets

Text('OK'); // ignore: hardcoded.ok
Text('Title'); // ignore: hardcoded.string
```

## 🎯 Quality Checks

Need to silence a rule? See Ignore Warnings above.

### One Class Per File Rule

- ✅ **Compliant**: 1 public class per file (or 2 for StatefulWidget)
- ❌ **Violation**: Too many public classes in one file

### Magic Numbers

- 🔍 **Detects**: Numeric literals other than `0`, `1`, or `-1` when they appear inline in code (i.e., not part of an annotation, a `const` declaration, a `static const`, a descriptive `final` numeric, or a `const` expression like const lists/maps/sets/constructors).
- ✅ **Allows**: Descriptive `const`/`static const`/`final` numerics (name length > 3), annotation values, and all const expressions. Example: `final int defaultRetryCount = 2;` is allowed because the name is descriptive.
- 🔧 **How to fix**: Replace inline literals with a named `const`/`static const`/`final` value (e.g., `const defaultTimeoutMs = 5000;`) or move the literal into a const expression that already documents intent.

### Hardcoded Strings

- ⚠️ **Caution**: Potential user-facing strings (project not localized)
- ❌ **Error**: Hardcoded strings when localization is enabled

### Secrets Detection

- 🔒 **Security**: Detects API keys, tokens, private keys, and other sensitive information
- 🚨 **Critical**: AWS keys, GitHub PATs, Stripe keys, emails
- 📊 **Advanced**: High entropy string detection for unknown secret patterns

### Dead Code

- 🧹 **Detects**: Dead files, dead classes, dead functions, and unused variables
- 🎯 **Goal**: Reduce code surface area and improve maintainability
- 🔍 **How it works**: Builds a dependency graph from imports/exports and tracks symbol usage
- 🔧 **How to fix**: Remove unused code or reference it explicitly

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

## 🛡️ Exclusions

Use `--exclude` to skip custom glob patterns, and `--excluded` to inspect what was skipped:

```bash
# Custom excludes
fcheck --exclude "**/generated/**" --exclude "**/*.g.dart"

# Inspect excluded items
fcheck --excluded
fcheck --excluded --json
```

### Example Output

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

### What Gets Excluded

- Hidden directories (starting with `.`), including nested hidden folders
- Common project directories: `test/`, `example/`, `tool/`, `.dart_tool/`, `build/`, `.git/`, `ios/`, `android/`, `web/`, `macos/`, `windows/`, `linux/`
- Generated localization files (`app_localizations_*.dart`, `app_localization_*.dart`), while keeping `app_localizations.dart`
- Files matching `--exclude` glob patterns
- Files in directories that match exclude patterns

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

## 🔧 Configuration

### Global Ignore (`.fcheck` file)

Create a `.fcheck` file in your project root:

```yaml
ignores:
  magic_numbers: true
  hardcoded_strings: true
  layers: true
```

Per-line and per-file ignore comments are covered in Ignore Warnings above.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run `./tool/check.sh` to ensure quality
5. Submit a pull request

## 📋 Requirements

- Dart SDK >= 3.0.0 < 4.0.0
- Works with any Flutter/Dart project

## 📄 License

MIT License - see LICENSE file for details.
