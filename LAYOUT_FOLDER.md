# Folder-Based Dependency Visualization Layout

## Overview

The folder-based SVG visualization provides a hierarchical view of project dependencies organized by folder structure. This layout helps identify architectural patterns, component relationships, and potential refactoring opportunities.

## Visualization Structure

### Folder Containers

Each folder is represented as a container with:

- **Folder Name**: Displayed at the top
- **Dependency Metrics**: Shows incoming (↓) and outgoing (↑) dependencies
- **Files**: List of files within the folder with individual dependency badges
- **Visual Style**: White background with rounded corners and shadow

### Dependency Edges

Connections between folders are shown as curved lines using the unified styling system:

- **Direction**: Left-to-right (source → target)
- **Style**: Unified horizontal gradient from green (#28a745) to blue (#007bff) using `url(#horizontalGradient)`
- **Interactive**: Hover to see specific file dependencies
- **Hover Behavior**: Maintains gradient color, increases stroke-width to 5px, opacity to 1.0
- **Transitions**: Smooth 0.1s ease-in-out transitions
- **Cursor**: Uses help cursor for interactive tooltips

**Edge Styling Classes:**

- `.edgeVertical` - Main folder-to-folder dependencies
- `.edgeVertical` - Parent-child folder relationships  
- `.edgeVertical` - File-to-file dependencies within folders

All edge types maintain their gradient colors on hover and use consistent visual feedback.

### Layout Algorithm

## Sorting Logic

The folder sorting algorithm follows a three-tier approach:

### 1. Entry Point Detection (Primary Sort)

Folders with **0 incoming dependencies** are considered true entry points and appear first:

```dart
final aIsEntry = aIncoming == 0;
final bIsEntry = bIncoming == 0;
if (aIsEntry != bIsEntry) {
  return aIsEntry ? -1 : 1; // Entry points first
}
```

**Examples of Entry Points:**

- `bin/` - Contains main executable (0 incoming)
- `.` (root) - Contains configuration files (0 incoming)
- `test/` - Test files that don't depend on other folders (0 incoming)

### 2. Outgoing Dependencies (Secondary Sort)

Among folders with the same entry point status, sort by outgoing dependencies (descending):

```dart
final outgoingDiff = bOutgoing.compareTo(aOutgoing);
if (outgoingDiff != 0) return outgoingDiff;
```

**Rationale:**

- Folders that depend on many others are typically core modules
- High outgoing = more fundamental/important
- Creates natural hierarchy from core → utilities

### 3. Incoming Dependencies (Tertiary Sort)

Among folders with similar outgoing dependencies, sort by incoming dependencies (ascending):

```dart
return aIncoming.compareTo(bIncoming);
```

**Rationale:**

- Fewer incoming dependencies = less coupled
- Helps identify leaf modules and utilities

## Expected Folder Ordering

### Left Side (Entry Points)

1. **True Entry Points**: Folders with 0 incoming dependencies
   - `bin/` - Main executables
   - `.` (root) - Configuration files
   - `test/` - Test suites

2. **Core Modules**: High outgoing, some incoming
   - `lib/` - Main library code
   - `src/` - Core source files

### Middle (Dependent Modules)

1. **Shared Components**: Medium outgoing/incoming
   - `utils/` - Utility functions
   - `common/` - Shared components

### Right Side (Leaf Modules)

1. **Specialized Utilities**: Low outgoing, high incoming
   - `graphs/` - Graph exporters (Mermaid, PlantUML, SVG)
   - `helpers/` - Helper functions

2. **Leaf Modules**: Minimal outgoing, high incoming
   - `hardcoded_strings/` - Specific functionality
   - `layers/` - Layer analysis

## Visual Hierarchy

```text
[Entry Points] → [Core Modules] → [Dependent Modules] → [Leaf Modules]
(Left)            (Middle Left)      (Middle Right)        (Right)
```

## Folder Metrics Interpretation

### Incoming Dependencies (↓)

- **↓0**: Entry point / root folder
- **↓1-3**: Lightly used by others
- **↓4-6**: Moderately depended upon
- **↓7+**: Heavily depended upon (core module)

### Outgoing Dependencies (↑)

- **↑0**: Leaf module / standalone
- **↑1-3**: Uses few other modules
- **↑4-6**: Moderate dependencies
- **↑7+**: Depends on many modules (integrator)

## Common Patterns

### Healthy Architecture

```text
[Entry] → [Core] → [Utils] → [Leaf]
 bin     lib     metrics   layers
```

### Problematic Patterns

**Circular Dependencies:**

```text
[A] ↔ [B]  // Avoid bidirectional dependencies
```

**Overly Connected Core:**

```text
[Core] → Everything  // Single point of failure
```

**Orphaned Modules:**

```text
[Leaf] with no incoming  // Unused code?
```

## Folder Layout Examples

### Example 1: Well-Structured Project

```text
bin(↓0↑5) → lib(↓2↑7) → src(↓7↑6) → graphs(↓5↑4)
   ↓
metrics(↓3↑3) → sort(↓3↑3)
   ↓
hardcoded_strings(↓5↑1) → layers(↓7↑1)
```

### Example 2: Problematic Architecture

```text
lib(↓10↑15) → Everything  // Overly connected core
   ↑
All other folders depend on lib
```

## Best Practices

### Ideal Folder Structure

1. **Entry Points**: Minimal incoming, moderate outgoing
2. **Core Modules**: Balanced incoming/outgoing
3. **Utilities**: Moderate incoming, low outgoing
4. **Leaf Modules**: High incoming, minimal outgoing

### Refactoring Guidelines

- **Move leaf modules closer to entry points** if they become core
- **Split overly connected modules** into smaller components
- **Eliminate circular dependencies** between folders
- **Group related functionality** in the same folder

## Implementation Details

### Folder Extraction

```dart
String _extractFolderPath(String filePath) {
  final parts = filePath.split('/');
  if (parts.length >= 2) {
    return parts[parts.length - 1]; // Immediate parent folder
  }
  return 'root';
}
```

### Dependency Counting

```dart
// Cross-folder dependency detection
if (sourceFolder != targetFolder) {
  folderOutgoingCounts[sourceFolder]++;
  folderIncomingCounts[targetFolder]++;
}
```

### Visual Encoding

The unified styling system provides consistent visual elements across all visualizations:

- **Blue Badges (↓)**: Incoming dependencies with '?' cursor on hover
- **Green Badges (↑)**: Outgoing dependencies with '?' cursor on hover
- **File Icons (📄)**: Individual files within folders
- **Hover Effects**: Interactive tooltips on all badges with smooth transitions
- **Unified Cursors**: All badges use `cursor: help` showing '?' cursor

**Badge Styling Features:**

- Consistent 0.1s ease-in-out transitions
- Opacity changes on hover (0.8)
- Help cursor for all badge types
- Unified font sizing and positioning

## Troubleshooting

### Folder Appears in Wrong Position

1. Check incoming/outgoing counts with debug script
2. Verify dependency graph accuracy
3. Review sorting algorithm logic

### Missing Folder Dependencies

1. Ensure cross-folder dependencies are counted
2. Check folder extraction logic
3. Verify file-to-folder mapping

### Performance Issues

1. Optimize dependency graph traversal
2. Consider caching folder metrics
3. Review SVG generation efficiency

## Future Enhancements

- **Folder Grouping**: Group related folders visually
- **Dependency Strength**: Visualize strong/weak dependencies
- **Circular Dependency Detection**: Highlight problematic patterns
- **Interactive Reordering**: Allow manual folder positioning
