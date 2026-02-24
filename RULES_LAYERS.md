# Rule: Layers

## File Layers Overview

Builds a dependency graph between Dart files in the project, reports cycles, and computes layer numbers for visualization.

Shared analysis/exclusion conventions are defined in `RULES.md`.

## What It Collects

- Dependencies from `import` and `export` directives.
- Entry points are files with a top-level `main()` function.

## How It Works (Project Analysis via `AnalyzeFolder.analyze()`)

- `LayersDelegate` runs inside the unified `AnalyzerRunner` pass and emits per-file dependency metadata (`filePath`, `dependencies`, `isEntryPoint`).
- `LayersAnalyzer.analyzeFromFileData` builds and validates the graph from that metadata.
- This avoids a second parse/traversal pass for layers during full-project analysis.
- `AnalyzeFolder.analyzeLayers()` also uses the same unified pass + `LayersDelegate` flow.

## How It Works (Directory Analysis)

- Uses `FileUtils.listDartFiles` with CLI `--exclude` patterns and default exclusions.
- Skips files with `// ignore: fcheck_layers`.
- Parses each file and uses `LayersVisitor` to collect dependencies and entry point status.
- `LayersAnalyzer` receives `projectRoot` and `packageName` from `AnalyzeFolder` (see `RULES.md` for the project metadata contract).
- Filters the dependency graph to only include analyzed files.
- Detects cycles using DFS and emits `LayersIssueType.cyclicDependency` or `LayersIssueType.folderCycle`.
- If no cycles, assigns layers using SCC-based topological layering.
- Layer numbers are 1-based and increase as dependencies go deeper.

## How It Works (Single File)

- `LayersAnalyzer.analyzeFile` is a simplified check.
- If a file has any `import` or `export` and is not an entry point, it emits `LayersIssueType.wrongLayer`.

## Output

- `LayersAnalysisResult` contains `issues`, `layers`, and `dependencyGraph`.
- `LayersIssue` contains `type`, `filePath`, `message`.

## Related Files

- `lib/src/analyzers/layers/layers_analyzer.dart`
- `lib/src/analyzers/layers/layers_visitor.dart`
- `lib/src/analyzers/layers/layers_issue.dart`
- `lib/src/analyzers/layers/layers_results.dart`
- `lib/src/models/ignore_config.dart`

## Notes

- Only project-local Dart imports are considered. `dart:` and external `package:` imports are ignored.
- The current layer assignment algorithm does not explicitly use entry points beyond dependency flow.
- When used outside `AnalyzeFolder`, callers must supply `projectRoot` and `packageName` explicitly to avoid any metadata lookup.

## Folder Layer Assignment

When computing folder layers from file layers:

- Each folder is assigned the **maximum** layer number of any file within it
- This represents the "deepest" (lowest) position of the folder in the dependency hierarchy
- This is more accurate than using the minimum, as it reflects the lowest position any file in the folder occupies

## Folder Dependency Violations

The layer violation detection for folders skips certain cases:

### Parent-Child Folder Relationships

- **Parent folders can depend on child subfolders**: If folder A contains folder B (A/B), A depending on B is allowed
- **Child folders can depend on parent folders**: If folder B is inside folder A (A/B), B depending on A is allowed

This prevents false positives where code organization naturally creates hierarchical dependencies.

### Folder Hierarchy Ordering

- If two folders share a common ancestor and one is in an "above" branch of the folder tree (alphabetically earlier), dependencies between them are allowed
- For example: `/lib/src/analyzers` can depend on `/lib/src/models` because "analyzers" comes before "models" alphabetically

### Cross-Layer Dependencies

- For folders that don't fall into the above categories, the layer assignment is based on the deepest file in each folder
- Folder-level upward dependencies (`sourceFolderLayer > targetFolderLayer`) are reported as `LayersIssueType.wrongFolderLayer` using the source Dart file path for actionable refactoring
- In console output, these folder-layer issues are warnings; cycle issues remain failures
- The layer assignment still correctly handles cycle detection and file-level layer computation

---

## File Layers SVG Layout Spec

### SVG Layout and Styling Guide for Architecture Diagrams

## Overview

This document describes the fundamental principles and algorithms for creating SVG-based architecture diagrams with hierarchical layouts. The concepts are language-agnostic and can be implemented in any programming language.

The layers layout generator organizes project files into hierarchical layers based on their import dependencies. This creates a visual "cake" layout where entry point components appear at the top, and foundational components (that don't import anything) appear at the bottom.

## File Layers Core Concepts

### Data Model

The layout system uses these fundamental data structures:

```c
Node:
  id: string             // Unique identifier
  name: string           // Display name
  isLeaf: boolean        // true = file, false = folder
  isOrphan: boolean      // true = no dependencies in either direction
  children: Node[]       // Child nodes (for folders)
  targets: Node[]        // Outgoing dependencies (files this node imports)
  sources: Node[]        // Incoming dependencies (files that import this node)
  x, y: number           // Top-left position coordinates
  width, height: number  // Dimensions
  centerX, centerY: number    // Calculated center coordinates
  top, bottom: number    // Calculated edge coordinates
  left, right: number    // Calculated edge coordinates

Layer:
  index: number          // Layer position (1 = top, higher = lower)
  x, y: number           // Top-left layer position
  width, height: number  // Layer dimensions
  nodes: Node[]          // Nodes in this layer
  centerY: number        // Calculated center Y coordinate
```

### Layout Constants

Key spacing and sizing values (all in pixels):

```c
MIN_NODE_WIDTH = 300     // Minimum node width
MIN_NODE_HEIGHT = 80     // Minimum node height
PADDING = 35             // Spacing between layers
NODE_GAP = 4             // Gap between adjacent nodes
NODE_SPACING = 70        // Vertical spacing between nodes in a layer
PILL_SIZE = 24           // Diameter of dependency counter circles
PILL_OFFSET = 20         // Offset for counter pill positioning
CANVAS_PADDING = 50      // Canvas border padding
TEXT_PADDING = 10        // Padding for text inside nodes
MAX_CHARS = 30           // Threshold for reducing font size
```

## File Layers Layout Algorithm

### Document Structure

The SVG document follows this structure:

```xml
<svg width="total_width" height="total_height" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Filters for visual effects -->
    <filter id="shadow">...</filter>
    <filter id="outlineWhite">...</filter>
    
    <!-- Gradients for backgrounds -->
    <linearGradient id="layerGradient">...</linearGradient>
  </defs>
  
  <!-- White background -->
  <rect width="100%" height="100%" fill="white"/>
  
  <!-- Main content group with padding -->
  <g transform="translate(CANVAS_PADDING, CANVAS_PADDING)">
    <!-- Layer backgrounds (optional) -->
    <!-- Edges (drawn first, appear behind nodes) -->
    <!-- Nodes -->
    <!-- Text labels -->
    <!-- Dependency counters -->
  </g>
</svg>
```

### Layer Assignment Algorithm

The layer assignment algorithm organizes files into a hierarchical "cake" structure based on dependency relationships, where dependencies flow from top (entry points) to bottom (foundation).

#### Step 1: Dependency Analysis

Analyze all files in the project to build a dependency graph:

- Collect import relationships between files
- Include relative imports and `package:` imports for the current package; ignore `dart:` and external `package:` imports
- Build bidirectional references: each node tracks both `targets` (files it imports) and `sources` (files that import it)

#### Step 2: Layer Assignment Rules

The core principle: **Files are placed in layers based on their distance from the entry points. Entry points go to the top (Layer 1), and dependencies flow downwards to foundation components.**

**Layer Assignment Process:**

1. **Layer 1 (Top)**: Entry point files (e.g., files with `main()` function) are assigned to Layer 1.
2. **Subsequent Layers**: A file is placed in a layer based on what imports it:
   - If a file is imported by files in multiple layers, it is assigned to one layer below the *maximum* layer number (deepest position) that imports it. This ensures dependencies always flow downward.
   - If a file has no imports (entry point), it is Layer 1.
   - If a file is never imported but is not an entry point, it is treated as an orphan or placed in Layer 1.
3. **Foundation Rule**: Files with no outgoing dependencies (utilities, models, constants) naturally sink to the bottom-most layers as they are imported by higher-level components.
4. **Same Layer Rule**: Files can share the same layer and have unidirectional dependencies (one file imports another within the same layer). This is allowed and does not indicate an architectural problem. Same-layer dependencies are displayed as dotted lines.
5. **No Conflicts**: Files with circular dependencies must be in the same layer.

#### Step 3: Bottom Layer (Foundation)

**Foundation Layer (Highest Layer Number):**

- Files with no imports (utilities, models, constants)
- Low-level components that other files depend on
- The "foundation" of the project

#### Step 4: Layer Optimization

After initial assignment, optimize the layout:

- Consolidate layers where possible
- Balance node distribution across layers
- Minimize edge crossings by reordering nodes within layers
- Identify and flag circular dependencies

#### Example 1: Basic Layer Assignment

```text
File A: main() entry point -> Layer 1 (top)
File B: imported by A -> Layer 2 (below A)
File C: imported by B -> Layer 3 (below B)
File D: imports A -> Architectural smell (importing an entry point), placed in Layer 1 or flagged
File E: imported by A and B -> Layer 3 (placed one layer below its deepest dependent B)
File F: no imports, not an entry point -> Layer 1 (orphan/top level)
```

#### Example 2: Real Project Structure

```text
Project Structure:
  main.dart (imports: app.dart)
  app.dart (imports: service.dart, widget.dart)
  service.dart (imports: model.dart)
  widget.dart (imports: helper.dart, model.dart)
  helper.dart (imports: model.dart)
  model.dart (imports: none)

Layer Assignment (top to bottom):
  Layer 1: main.dart (entry point - imports app.dart)
  Layer 2: app.dart (imports service.dart and widget.dart)
  Layer 3: service.dart + widget.dart (both import from lower layers)
  Layer 4: helper.dart (imports model.dart)
  Layer 5: model.dart (foundation - no imports)

Explanation:
- main.dart is the entry point, goes to top (Layer 1)
- app.dart imports from Layer 3, so it goes to Layer 2
- service.dart and widget.dart can be in same layer (Layer 3)
  because they don't depend on each other
- helper.dart imports model.dart, goes to Layer 4
- model.dart is the foundation with no dependencies (Layer 5, bottom)

Dependency Flow (all arrows point downward):
  main.dart → app.dart → service.dart → model.dart
                       → widget.dart → helper.dart → model.dart
                                    → model.dart
```

### Position Calculation

After layer assignment, calculate precise positions for all elements.

#### Container and Layer Positioning

```python
def calculate_layout(layers, container_width, alignment="center"):
    """
    Calculate positions for all layers and nodes
    Layers stack vertically from top (Layer 1) to bottom (Layer N)
    """
    current_y = CANVAS_PADDING
    max_width = 0
    
    for layer in layers:
        # Calculate layer dimensions
        layer_node_count = len(layer.nodes)
        layer_height = max(
            (layer_node_count * MIN_NODE_HEIGHT) + ((layer_node_count - 1) * NODE_SPACING),
            MIN_NODE_HEIGHT
        )
        
        # Position layer
        layer.y = current_y
        layer.height = layer_height
        layer.width = container_width
        layer.centerY = layer.y + layer.height / 2
        
        # Calculate total width needed for nodes
        total_nodes_width = sum(max(node.width, MIN_NODE_WIDTH) for node in layer.nodes)
        
        # Determine starting X based on alignment
        if alignment == "center":
            start_x = (container_width - total_nodes_width) / 2
        else if alignment == "left":
            start_x = PADDING
        else if alignment == "right":
            start_x = container_width - total_nodes_width - PADDING
        else:
            start_x = 0
        
        # Position nodes within layer (vertically stacked)
        current_node_y = layer.y + PADDING
        for node in layer.nodes:
            node.x = start_x + PADDING
            node.y = current_node_y
            node.width = max(node.width, MIN_NODE_WIDTH)
            node.height = max(node.height, MIN_NODE_HEIGHT)
            
            # Calculate derived coordinates
            node.centerX = node.x + node.width / 2
            node.centerY = node.y + node.height / 2
            node.top = node.y
            node.bottom = node.y + node.height
            node.left = node.x
            node.right = node.x + node.width
            
            current_node_y += node.height + NODE_SPACING
            max_width = max(max_width, node.right + PADDING)
        
        current_y += layer_height + PADDING
    
    total_height = current_y + CANVAS_PADDING
    total_width = max_width + CANVAS_PADDING
    
    return {"width": total_width, "height": total_height}
```

## SVG Styling System

### Unified CSS Classes

The SVG visualization system uses a unified styling approach with consistent CSS classes embedded in the SVG `<defs>` section. This ensures visual consistency across both layers and folder-based visualizations.

```css
/* Unified edge styles - all maintain gradients on hover */
.edge { 
  fill: none; 
  stroke: url(#edgeGradient); 
  stroke-width: 1; 
  transition: all 0.1s ease-in-out; 
}
.edge:hover { 
  stroke: url(#edgeGradient); 
  stroke-width: 5; 
  opacity: 1.0; 
}

.edgeVertical { 
  fill: none; 
  stroke: url(#edgeGradient); 
  stroke-width: 0.5; 
  opacity: 0.5; 
  transition: all 0.1s ease-in-out; 
}
.edgeVertical:hover { 
  stroke: url(#edgeGradient); 
  stroke-width: 5; 
  opacity: 1.0; 
}

/* Unified badge styles with '?' cursor */
.badge { 
  font-size: 8px; 
  font-weight: bold; 
  fill: white; 
  text-anchor: middle; 
  dominant-baseline: middle; 
  cursor: help; 
  transition: all 0.1s ease-in-out; 
}
.badge:hover { 
  opacity: 0.8; 
}

/* Node and container styles */
.layerBackground { 
  fill: rgba(52, 58, 64, 0.08); 
  stroke: none; 
  rx: 12; 
  ry: 12; 
  filter: url(#hierarchicalShadow); 
  transition: all 0.1s ease-in-out; 
}
.layerBackground:hover { 
  fill: rgba(52, 58, 64, 0.12); 
}

/* Special edge styles */
.cycleEdge { 
  stroke: red; 
  stroke-width: 5; 
  opacity: 0.9; 
}
```

### Visual Effects

#### Unified SVG Filters

The unified styling system uses three core filters:

**White Shadow Filter (for nodes and interactive elements):**

```xml
<filter id="whiteShadow" x="-20%" y="-20%" width="140%" height="140%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="3"/>
  <feOffset dx="0" dy="0" result="offsetblur"/>
  <feFlood flood-color="white" flood-opacity="1"/>
  <feComposite in2="offsetblur" operator="in"/>
  <feMerge>
    <feMergeNode/>
    <feMergeNode in="SourceGraphic"/>
  </feMerge>
</filter>
```

**Hierarchical Shadow Filter (for folder containers):**

```xml
<filter id="hierarchicalShadow" x="-20%" y="-20%" width="140%" height="140%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="5"/>
  <feOffset dx="2" dy="2" result="offsetblur"/>
  <feFlood flood-color="rgba(0,0,0,0.1)" flood-opacity="0.8"/>
  <feComposite in2="offsetblur" operator="in"/>
  <feMerge>
    <feMergeNode/>
    <feMergeNode in="SourceGraphic"/>
  </feMerge>
</filter>
```

**White Outline Filter (for text readability):**

```xml
<filter id="outlineWhite">
  <feMorphology in="SourceAlpha" result="DILATED" operator="dilate" radius="2"/>
  <feFlood flood-color="white" flood-opacity="0.5" result="WHITE"/>
  <feComposite in="WHITE" in2="DILATED" operator="in" result="OUTLINE"/>
  <feMerge>
    <feMergeNode in="OUTLINE"/>
    <feMergeNode in="SourceGraphic"/>
  </feMerge>
</filter>
```

#### Simplified Gradients

The unified styling system uses three generic gradients with consistent colors:

**Horizontal Gradient (left green to right blue):**

```xml
<linearGradient id="horizontalGradient" x1="0%" y1="0%" x2="100%" y2="0%">
  <stop offset="0%" stop-color="#28a745"/>
  <stop offset="100%" stop-color="#007bff"/>
</linearGradient>
```

**Vertical Gradient (top green to bottom blue):**

```xml
<linearGradient id="verticalGradient" x1="0%" y1="0%" x2="0%" y2="100%">
  <stop offset="0%" stop-color="#28a745"/>
  <stop offset="100%" stop-color="#007bff"/>
</linearGradient>
```

**Color Consistency:**

- Green: `#28a745` (consistent across all gradients)
- Blue: `#007bff` (consistent across all gradients)

### Key Features of Unified Approach

1. **Consistent Hover Behavior**: All edges maintain their gradient colors on hover instead of changing to solid colors
2. **Unified Cursor Styles**: All badges use `cursor: help` to show '?' cursor on hover
3. **Consistent Transitions**: All interactive elements use 0.1s ease-in-out transitions
4. **Gradient Maintenance**: Hover states preserve visual gradients for better UX
5. **Single Source of Truth**: All styles defined in one place, used by both visualization types

## Rendering Components

### Node Rendering

Render nodes as rounded rectangles with appropriate styling:

```python
def render_node(node):
    # Apply gap between nodes to prevent overlap
    x = node.x + NODE_GAP / 2
    y = node.y + NODE_GAP / 2
    width = node.width - NODE_GAP
    height = node.height - NODE_GAP
    
    # Determine CSS class and corner radius based on node type
    if node.isLeaf:
        if node.isOrphan:
            css_class = "nodeFileOrphan"
        else:
            css_class = "nodeFile"
        corner_radius = 8
    else:
        css_class = "nodeFolder"
        corner_radius = 2
    
    # Generate SVG rectangle element
    return (f'<rect x="{x}" y="{y}" width="{width}" height="{height}" '
            f'class="{css_class}" rx="{corner_radius}" ry="{corner_radius}"/>')
```

### Text Labels

Render text with appropriate positioning and dynamic sizing:

```python
def render_text_label(node):
    if node.isLeaf:
        # File name - adjust size based on length
        font_size = "16px"
        if len(node.name) > MAX_CHARS:
            font_size = "12px"
        
        return (f'<text x="{node.centerX}" y="{node.centerY}" '
                f'class="nodeName" font-size="{font_size}">'
                f'{escape_xml(node.name)}</text>')
    else:
        # Folder name - positioned at top-left with padding
        return (f'<text x="{node.x + TEXT_PADDING}" y="{node.y + TEXT_PADDING}" '
                f'class="folderName">{escape_xml(node.name)}</text>')

def escape_xml(text):
    """Escape special XML characters in text"""
    return (text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace('"', "&quot;")
                .replace("'", "&apos;"))
```

### Edge Rendering

Render edges as curved paths. **All edges should flow downward** from higher layers to lower layers in a properly architected system.

```python
def render_edge(source, target):
    # Classify edge type
    edge_type = classify_edge(source, target)
    
    # Determine CSS class based on edge type
    css_classes = {
        "circular": "edgeCircular",
        "upward": "edgeUpward",
        "normal": "edgeNormal"
    }
    css_class = css_classes.get(edge_type, "edgeNormal")
    
    # Calculate connection points (source imports target)
    # Edge should go from source (higher in diagram) to target (lower in diagram)
    start_x = source.centerX
    start_y = source.bottom
    end_x = target.centerX
    end_y = target.top
    
    # Calculate quadratic bezier control point for smooth curve
    control_x = (start_x + end_x) / 2
    control_y = (start_y + end_y) / 2
    
    # Generate SVG path with quadratic curve
    path_data = f"M {start_x},{start_y} Q {control_x},{control_y} {end_x},{end_y}"
    
    return f'<path d="{path_data}" class="{css_class}"/>'

def classify_edge(source, target):
    """
    Classify edge based on dependency direction
    In proper architecture, all edges flow downward (source.y < target.y)
    """
    # Check for circular dependency (mutual imports)
    if source in target.targets and target in source.targets:
        return "circular"
    
    # Check for upward dependency (architectural smell)
    # This means a file in a lower layer imports from a higher layer
    elif target.y < source.y:
        return "upward"
    
    # Normal downward dependency (proper architecture)
    else:
        return "normal"
```

### Dependency Counters

Render circular badges showing dependency counts:

```python
def render_dependency_counter(x, y, count, color, tooltip_text):
    """Render a circular counter badge with tooltip"""
    return f'''<g class="dependencyCounter">
    <circle cx="{x}" cy="{y}" r="{PILL_SIZE / 2}"
            fill="{color}" class="counterCircle"/>
    <text x="{x}" y="{y}" class="counterText">{count}</text>
    <title>{escape_xml(tooltip_text)}</title>
</g>'''

def render_all_counters(node):
    """Render both outgoing and incoming dependency counters for a node"""
    counters = []

    # Incoming dependencies (sources that import this node) - blue badge at top-left
    if len(node.sources) > 0:
        x = node.left + PILL_OFFSET
        y = node.top + PILL_OFFSET
        tooltip = f"Imported by {len(node.sources)} files: " + ", ".join(s.name for s in node.sources)
        counters.append(render_dependency_counter(x, y, len(node.sources), "#2E5C8A", tooltip))

    # Outgoing dependencies (targets this node imports) - green badge at bottom-right
    if len(node.targets) > 0:
        x = node.right - PILL_OFFSET
        y = node.bottom - PILL_OFFSET
        tooltip = f"Imports {len(node.targets)} files: " + ", ".join(t.name for t in node.targets)
        counters.append(render_dependency_counter(x, y, len(node.targets), "#377E22", tooltip))

    return '\n'.join(counters)
```

### Layer Background Rendering

Optionally render layer backgrounds for visual grouping:

```python
def render_layer_background(layer):
    """Render a layer background rectangle with label"""
    return f'''<g class="layer">
    <rect x="{layer.x}" y="{layer.y}" 
          width="{layer.width}" height="{layer.height}" 
          class="layerRectangle"/>
    <text x="{layer.x + TEXT_PADDING}" y="{layer.y + TEXT_PADDING}" 
          class="layerText">Layer {layer.index}</text>
</g>'''
```

## Complete Implementation

### Main Generation Function

```python
def generate_architecture_diagram(nodes, edges, options=None):
    """
    Generate complete SVG architecture diagram
    
    Args:
        nodes: List of Node objects
        edges: List of (source, target) tuples where source imports target
        options: Optional configuration (alignment, show_layers, etc.)
    
    Returns:
        Complete SVG markup as string
    """
    options = options or {}
    alignment = options.get("alignment", "center")
    show_layers = options.get("show_layers", True)
    container_width = options.get("width", 1200)
    
    # Step 1: Assign nodes to layers based on dependencies
    layers = assign_nodes_to_layers(nodes, edges)
    
    # Step 2: Calculate precise layout positions
    dimensions = calculate_layout(layers, container_width, alignment)
    
    # Step 3: Generate SVG markup
    svg_parts = []
    
    # SVG header
    svg_parts.append(f'<svg width="{dimensions["width"]}" height="{dimensions["height"]}" '
                    f'xmlns="http://www.w3.org/2000/svg">')
    
    # Definitions (styles, filters, gradients)
    svg_parts.append(generate_defs())
    
    # White background
    svg_parts.append('<rect width="100%" height="100%" fill="white"/>')
    
    # Main content group
    svg_parts.append(f'<g transform="translate({CANVAS_PADDING}, {CANVAS_PADDING})">')
    
    # Render layer backgrounds (optional)
    if show_layers:
        for layer in layers:
            svg_parts.append(render_layer_background(layer))
    
    # Render edges (drawn first so they appear behind nodes)
    for source, target in edges:
        svg_parts.append(render_edge(source, target))
    
    # Render nodes
    for layer in layers:
        for node in layer.nodes:
            svg_parts.append(render_node(node))
    
    # Render text labels
    for layer in layers:
        for node in layer.nodes:
            svg_parts.append(render_text_label(node))
    
    # Render dependency counters
    for layer in layers:
        for node in layer.nodes:
            svg_parts.append(render_all_counters(node))
    
    # Close main group and SVG
    svg_parts.append('</g>')
    svg_parts.append('</svg>')
    
    return '\n'.join(svg_parts)

def generate_defs():
    """Generate SVG definitions section with styles and filters"""
    return '''<defs>
    <style>
        /* Include all CSS from styling section */
    </style>
    
    <!-- Filters -->
    <filter id="shadow">...</filter>
    <filter id="outlineWhite">...</filter>
    
    <!-- Gradients -->
    <linearGradient id="layerGradient">...</linearGradient>
</defs>'''
```

## Key Algorithms

### Assignment to a layer

```python
def assign_nodes_to_layers(nodes, edges):
    """
    Assign nodes to layers using dependency-based algorithm.
    Entry points go to Layer 1 (top), foundation files go to bottom.
    Each file is placed one layer above its deepest dependency.
    
    Args:
        nodes: List of Node objects
        edges: List of (source, target) tuples where source imports target
    
    Returns: List of Layer objects, ordered from top (1) to bottom (n)
    """
    # Build dependency maps
    for source, target in edges:
        if target not in source.targets:
            source.targets.append(target)
        if source not in target.sources:
            target.sources.append(source)
    
    # Initialize layer assignments
    node_layers = {}  # node -> layer_number
    
    # Step 1: Find entry points (files with no imports or main functions)
    entry_points = [node for node in nodes if len(node.targets) == 0 or node.is_entry_point]
    
    # Step 2: Assign layers using iterative approach
    # Files go one layer above their deepest dependency
    max_iterations = len(nodes) * 2  # Prevent infinite loops
    iteration = 0
    
    while iteration < max_iterations:
        iteration += 1
        changed = False
        
        for node in nodes:
            if node in entry_points and node not in node_layers:
                # Entry points go to Layer 1
                node_layers[node] = 1
                changed = True
            elif len(node.targets) == 0 and node not in node_layers:
                # Foundation files (no imports) go to bottom
                # We'll assign them a temporary high number
                node_layers[node] = 9999
                changed = True
            else:
                # Files go one layer above their deepest import
                target_layers = [node_layers.get(target) for target in node.targets if target in node_layers]
                
                if target_layers and len(target_layers) == len(node.targets):
                    # All dependencies have been assigned
                    new_layer = max(target_layers) - 1
                    if new_layer < 1:
                        new_layer = 1
                    
                    if node not in node_layers or node_layers[node] != new_layer:
                        node_layers[node] = new_layer
                        changed = True
        
        # If nothing changed, we're done
        if not changed:
            break
    
    # Step 3: Normalize layer numbers (remove gaps, fix foundation layer)
    if node_layers:
        # Find actual max layer
        max_layer = max(node_layers.values())
        
        # Replace temporary foundation layer number (9999) with max_layer + 1
        for node in nodes:
            if node_layers.get(node) == 9999:
                node_layers[node] = max_layer + 1
        
        # Renumber layers to be sequential from 1
        unique_layers = sorted(set(node_layers.values()))
        layer_mapping = {old: new for new, old in enumerate(unique_layers, 1)}
        for node in nodes:
            if node in node_layers:
                node_layers[node] = layer_mapping[node_layers[node]]
    
    # Step 4: Create Layer objects
    layers_dict = {}
    for node, layer_num in node_layers.items():
        if layer_num not in layers_dict:
            layers_dict[layer_num] = Layer(index=layer_num, nodes=[])
        layers_dict[layer_num].nodes.append(node)
    
    # Return layers sorted from top (1) to bottom (n)
    return [layers_dict[i] for i in sorted(layers_dict.keys())]
```

### Circular Dependency Detection

```python
def find_circular_dependencies(nodes):
    """
    Find all nodes involved in circular dependencies.
    Circular dependencies occur when two files import each other.
    
    Returns: Set of nodes that have circular dependencies
    """
    circular = set()
    
    for node in nodes:
        for target in node.targets:
            # Check if target also imports node (creates a cycle)
            if node in target.targets:
                circular.add(node)
                circular.add(target)
    
    return circular
```

### Edge Crossing Minimization

```python
def minimize_edge_crossings(layer):
    """
    Reorder nodes within a layer to minimize edge crossings.
    Uses barycenter heuristic.
    """
    if len(layer.nodes) <= 1:
        return layer.nodes
    
    # Calculate barycenter (average position of connected nodes)
    node_scores = []
    for node in layer.nodes:
        connected_positions = []
        
        # Consider positions of nodes this node imports (targets)
        for target in node.targets:
            connected_positions.append(target.x)
        
        # Consider positions of nodes that import this node (sources)
        for source in node.sources:
            connected_positions.append(source.x)
        
        if connected_positions:
            barycenter = sum(connected_positions) / len(connected_positions)
        else:
            barycenter = 0
        
        node_scores.append((barycenter, node))
    
    # Sort nodes by barycenter
    node_scores.sort(key=lambda x: x[0])
    return [node for _, node in node_scores]
```

## Optimization Considerations

### Performance Optimizations

1. **Spatial Indexing**: For diagrams with 100+ nodes, use quadtree or R-tree data structures for efficient neighbor queries
2. **Incremental Layout**: Cache layer assignments and recalculate only affected portions when dependencies change
3. **Edge Batching**: Group edges by type and render in batches to reduce DOM operations
4. **Lazy Rendering**: For very large diagrams, implement viewport-based rendering to only draw visible elements

### Visual Quality Improvements

1. **Edge Routing**: Implement orthogonal edge routing to avoid overlapping node boundaries
2. **Node Clustering**: Group related nodes visually using color coding or proximity
3. **Interactive Highlighting**: Add hover effects to highlight dependency paths
4. **Zoom and Pan**: Implement SVG viewport manipulation for navigating large diagrams

### Scalability Guidelines

| Node Count | Recommended Approach                                  |
| ---------- | ----------------------------------------------------- |
| < 50       | Full rendering, all optimizations optional            |
| 50-200     | Implement edge crossing minimization                  |
| 200-500    | Add viewport-based rendering, spatial indexing        |
| 500+       | Consider hierarchical clustering, progressive loading |

### Accessibility Considerations

1. **Semantic Markup**: Use `<title>` and `<desc>` elements for screen reader support
2. **Keyboard Navigation**: Ensure diagram elements can be accessed via keyboard
3. **Color Contrast**: Maintain WCAG AA compliant contrast ratios (4.5:1 minimum)
4. **Alternative Formats**: Provide text-based dependency lists as fallback

## Error Handling

### Common Issues and Solutions

#### Issue: Infinite loops in circular dependencies

- Solution: Track visited nodes during traversal, limit iterations, handle circular groups together

#### Issue: Overlapping nodes

- Solution: Validate minimum spacing constraints, add collision detection

#### Issue: Missing dependencies

- Solution: Validate edge references point to existing nodes before rendering

#### Issue: Upward dependencies (architectural smells)

- Solution: Flag with orange color, suggest refactoring to eliminate

#### Issue: Inconsistent layer heights

- Solution: Normalize layer heights or implement dynamic height calculation

### Validation Checklist

Before rendering, validate:

- [ ] All edge source/target nodes exist in node list
- [ ] No duplicate node IDs
- [ ] All numeric coordinates are finite values
- [ ] Layer assignments follow top-down rule (entry points at top, foundation at bottom)
- [ ] All edges flow downward in Y-axis (source.y < target.y for normal edges)
- [ ] Node dimensions meet minimum requirements
- [ ] Text content is properly escaped for XML

## Architecture Quality Indicators

### Edge Color Meanings

- **Green (Normal)**: Proper downward dependency flow - good architecture
- **Red (Upward)**: File in lower layer imports from higher layer - architectural smell, consider refactoring
- **Gray/Dotted (Same Layer)**: Unidirectional dependency within the same layer - allowed, no architectural issue
- **Red (Circular)**: Mutual dependencies between files - architectural problem, must be resolved

### Ideal Architecture Characteristics

1. **Clear Hierarchy**: Entry points at top, foundation at bottom
2. **Downward Flow**: All dependencies flow from top to bottom
3. **Minimal Layers**: Fewer layers indicate better-organized code
4. **Balanced Layers**: Even distribution of files across layers
5. **No Circular Dependencies**: No red edges in the diagram
6. **Few Upward Dependencies**: Minimal or no orange edges

## Conclusion

This guide provides a comprehensive foundation for implementing architecture diagram layouts. Key principles to remember:

1. **Layer assignment** is based on dependency depth: entry points at top, foundation at bottom
2. **Dependency flow** should always be downward (top to bottom)
3. **Edge classification** (green/orange/red) communicates architectural quality
4. **Consistent spacing** ensures readability
5. **Visual feedback** (colors, counters)

---

## Folder SVG Layout Spec

### Folder-Based Dependency Visualization Layout (Execution Spec)

This spec defines **how to compute and render** a dependency diagram that shows the project **as it exists**, using folder containers and file nodes. The layout is driven purely by **observed dependencies** (imports), while folders preserve the **human grouping constraint**.
The folder-based SVG visualization provides a hierarchical view of project dependencies organized by folder structure. This layout helps identify architectural patterns, component relationships, and potential refactoring opportunities.

---

## 1) Inputs and Outputs

### Folder Spec Input

A directed file dependency graph:

- File nodes: `filePath`
- File edges: `A → B` meaning “A depends on B”

### Folder Spec Output

One SVG diagram with two parallel lanes:

- **Left lane:** Folder-to-folder connections (rolled-up)
- **Right lane:** File-to-file connections (raw)

Folders and files are laid out in the same top-to-bottom ordering logic, but edges are visually separated by lane.

---

## 2) Folder Extraction and Grouping

Map each file to a folder key `F(file)` (deterministic, stable).

- Folder containers list their files.
- All cross-folder relationships are derived from file edges.

### 2.1) Virtual Folders and Loose File Grouping

When a folder contains both files and subfolders, the system creates a **virtual folder** to group the loose files. This provides a cleaner visualization by separating files from the folder hierarchy.

#### Virtual Folder Creation

- **Trigger**: A folder has both files and subfolders
- **Name**: Virtual folders are named "..." to indicate they contain loose files
- **Position**: Virtual folders are positioned **above** all other subfolders within the parent folder
- **Content**: Contains only the files that are directly in the parent folder (not in any subfolder)
- **Styling**: Rendered with a **dash-dot border** (`stroke-dasharray: 4 2`) to distinguish from regular subfolders
- **Ordering**: Follows the same ordering rules as regular subfolders (consumers above providers)

#### Purpose

- Ensures consistent hierarchical visualization where files are always contained within some folder-like container
- Provides cleaner visual separation between files and folder structure
- Maintains accurate dependency relationships that originate from where files actually reside

#### Note on File Identity

Virtual folders are a **visual grouping construct only**.

- They **do not** change the logical relative path of the files they contain.
- Dependency lookups, edge anchors, and graph keys must always use the **original file path** (e.g., `folder/file.dart`), **not** a path including the virtual folder (e.g., **avoid** `folder/.../file.dart`).

### 2.2) Folder Connection Rules

The system distinguishes between external and internal folder connections:

#### External Folder Connections

- **Definition**: When a file from one folder imports a file from another folder
- **Behavior**: The connection is routed between the parent folders (not virtual subfolders)
- **Example**: If Folder A contains file X and Folder B contains file Y, and X imports Y, the connection shows A → B

#### Internal Folder Connections  

- **Definition**: When a file from a virtual subfolder imports a file from a subfolder within the same parent
- **Behavior**: The connection is routed from the virtual subfolder to the target subfolder
- **Example**: If Folder B has a virtual subfolder with file Y and a subfolder C with file Z, and Y imports Z, the connection shows "virtual subfolder of B" → C

#### Connection Logic

```dart
// For external connections, return the parent folder
if (targetParent != currentParent) {
  // External connection - return parent folder
  return current.fullPath;
} else {
  // Internal connection - return virtual subfolder
  return child.fullPath;
}
```

This distinction ensures that:

- External dependencies are shown at the folder level for clarity
- Internal dependencies within the same parent folder show the actual source location (virtual subfolder)
- The visualization maintains both hierarchical relationships and accurate dependency origins

### 2.3) Hierarchical Roll-Up Rule (External Connections)

To maintain architectural clarity and prevent a "spiderweb" of cross-folder lines, external dependencies MUST be rolled up to the shallowest folders that are distinct siblings under a common parent.

- **Rule**: For any file edge `A → B`, find the lowest common ancestor folder `P`.
- **Source Folder**: The direct child of `P` that contains `A` (or the virtual folder inside `P` if `A` is a loose file in `P`).
- **Target Folder**: The direct child of `P` that contains `B` (or the virtual folder inside `P` if `B` is a loose file in `P`).
- **Visual Impact**: External connections always happen between folders at the same "branch" level, ensuring that deep internal structures do not clutter the top-level architectural view.

Example:

- File `lib/screens/login/auth.dart` depends on `lib/models/user.dart`.
- Common ancestor is `lib`.
- Roll-up: `lib/screens` → `lib/models`.

---

## 3) Roll-Up: Folder Consumption Graph

For each file edge `A → B`:

- `FA = F(A)`
- `FB = F(B)`
- If `FA != FB`, accumulate:

`consumes[FA][FB] += 1`

Interpretation:

- `FA consumes FB` (FA depends on FB)

### 3.1) Consumption Weight (for Ordering)

For each file edge `A → B`:

- `Weight(FA, FB) += 1`
- Used in Phase 2 ordering to determine which consumer is "stronger".

### 3.2) Connection Degree (for Badges)

For each unique folder pair `(FA, FB)` where `Weight > 0`:

- **Degree Out**: `outgoing(FA) += 1`
- **Degree In**: `incoming(FB) += 1`

**Visual Rule**: The numbers displayed in folder badges MUST correspond to the **number of unique lines** (Connection Degree) drawn in the left lane, NOT the sum of file-level consumption weights.

---

## 4) Vertical Ordering Rule (Folders)

The folder vertical order is computed in **two phases**:

### Phase 1: Hard Dependency Constraints

First, apply **hard dependency constraints** based on direct consumption:

For any two folders `A` and `B`:

- If `consumes[A][B] > 0` (A consumes B), then **A must be above B**
- If `consumes[B][A] > 0` (B consumes A), then **B must be above A**

**Hard Constraint Rule:** If both folders consume each other (cyclic), the folder with **higher consumption strength** gets priority (see Phase 2).

### Phase 2: Consumption Strength Ordering

After applying hard constraints, order folders by **observed consumption strength** within the remaining flexibility.

#### 4.1 Pair Rule (2 folders)

For any two folders `A` and `B` that have cross dependencies:

- If `consumes[A][B] > consumes[B][A]` then place **A above B**
- If `consumes[B][A] > consumes[A][B]` then place **B above A**
- If equal, apply a deterministic tiebreaker (e.g., folder path ascending)

#### 4.2 Group Rule (3+ folders)

When 3+ folders participate in a connected set (including cyclic or triangular relationships), use aggregate consumption within that set:

For a group `G` and folder `F ∈ G`:

`groupOut(F) = Σ consumes[F][K] for K ∈ G, K != F`

Sort folders in **descending `groupOut(F)`**:

- Highest consumer goes **highest**
- Lowest consumer goes **lowest**

Tiebreakers:

1) `groupOut` desc  
2) `incoming` asc (optional stabilization)  
3) folder path asc

#### 4.3 Layered Ranking (Global)

To prevent diagrams from becoming excessively tall and to ensure consistent flow:

1. **Shared Levels**: Multiple folders SHOULD occupy the same level if they can be processed in parallel.
2. **Rank Calculation**: Use a layering algorithm where `level(N) = max(level(consumers_of_N)) + 1`. This groups independent "leaves" at the same depth and brings "consumer roots" (like `screen`) to the top.
3. **Global Scope**: Leveling must be calculated on the **global** folder graph before any visual grouping is applied. This ensures that a consumer in one component stays above its providers even if they are logically separated into different connected sets.

> **Note:** Phase 1 hard constraints take precedence over Phase 2 ordering. If hard constraints create conflicts (e.g., cycles), resolve using Phase 2 consumption strength within the conflicting group, but keep the group aligned with its immediate predecessors.

---

## 5) Vertical Ordering Rule (Files within a Folder)

Inside each folder container, order files deterministically, for example:

- Primary: file outgoing dependencies (desc)
- Secondary: file incoming dependencies (asc)
- Tiebreaker: file path asc

(Any stable rule is acceptable; folder-to-folder ordering is the main requirement.)

---

## 6) Edge Classification and Color Rules

All edges exist as raw file edges, but we render them in two forms:

### 6.1 Folder Edges (Left Lane)

Render rolled-up folder edges for all pairs where `consumes[A][B] > 0`.

- Lane: **left**
- Edge represents: `consumes[A][B]` (weight)
- Tooltip includes: weight and top contributing file edges

### 6.2 File Edges (Right Lane)

Render raw file-to-file edges.

- Lane: **right**
- Tooltip includes: exact `A → B`

---

## 7) Direction Semantics and Warnings

The diagram is read **top-to-bottom**.

### 7.1 Normal Direction

A “healthy / expected” direction is:

- **Top consumes bottom**  
(i.e., consumer above provider)

This is purely a visual convention to help humans scan. The diagram remains “as-is”.

### 7.2 Upward Consumption Warning (Orange)

If an edge goes **upward** in the diagram (source is lower than target), it is a warning:

- Condition: `y(source) > y(target)`
- Style: **Orange** stroke (warning)

> [!IMPORTANT]
> **Visual Truth**: Upward detection MUST use finalized vertical coordinates (`y`), not logical levels or sorting indices. This ensures the warning strictly matches the visual "point up" behavior, even if logical ordering constraints are partially relaxed for layout stability.

Applies to both:

- Folder edges (rolled-up)
- File edges (raw)

This highlights boundary inversions like:

- “lower layer consuming higher layer”

### 7.3 Cycle Highlight (Red)

If an edge is part of a detected cycle, render it in **Red** (overrides orange).

- Style: **Red** stroke for cycle edges
- Purpose: make cycles immediately visible for refactoring

Applies to:

- Folder graph cycles (derived from rolled-up folder edges)
- File graph cycles (raw)

**Priority rule:** `Red (cycle) > Orange (upward) > Default (gradient)`

---

## 8) Cycle Detection (Required)

Detect cycles in both graphs:

1) **Folder graph**: nodes are folders, edges exist where `Weight(A, B) > 0`.
2) **File graph**: nodes are files, edges are file imports

Any edge that participates in at least one cycle is marked as `isCycle = true`.

---

## 9) Rendering Styles

### 9.1 Default Edge Style

Used when not cycle and not upward:

- Stroke: unified horizontal gradient `url(#horizontalGradient)` (green → blue)
- Width: 3px
- Opacity: 0.8
- Cursor: `help`
- Transition: 0.1s ease-in-out

### 9.2 Warning Edge Style (Upward)

- Stroke: **Orange**
- Width: 3px (hover 5px)
- Opacity: 0.9 (hover 1.0)

### 9.3 Cycle Edge Style

- Stroke: **Red**
- Width: 4px (hover 6px)
- Opacity: 1.0

### 9.4 Hover Behavior (All Edges)

- Maintain current stroke color (gradient/orange/red)
- Increase stroke-width
- Opacity to 1.0

---

## 10) Lane Placement (Left vs Right)

### Left Lane: Folder edges

- Render folder containers centered in the main column
- Draw aggregated folder edges routed to the **left side** of the folder stack
- Keep these edges visually distinct from file edges (spacing + consistent left routing)

### Right Lane: File edges

- Render file nodes inside folder containers
- Draw file-to-file edges routed to the **right side** of the overall diagram

### 10.3) Straight Gutter Alignment (Global and Nested)

Vertical edge segments MUST use **fixed global X-coordinates** relative to their respective gutters (Gutter Alignment):

- **Global Left Lane**: For edges between root-level branches, use fixed coordinates from the diagram's left margin.
- **Nested Left Lanes**: For edges between sibling folders within a parent, use **local fixed coordinates** relative to the parent container's left boundary. This keeps internal lines grouped within their logical scope.
- **Right Lane**: Use fixed coordinates starting from the right side of the root container.
- **Visual Impact**: Ensures perfectly straight vertical lines within their scope, preventing a jagged look while making the diagram significantly more compact.

---

## 11) Container Sizing Rules

### 11.1) Uniform Width (Flush Look)

To maintain a professional, clean grid look, subfolders (including virtual folders) MUST expand horizontally to match the interior width of their parent container.

- **Rule**: `child.width = parent.innerWidth`
- **Visual Impact**: All children within a folder appear "flush" on both sides, creating a consistent column regardless of the child's own content width.

### 11.2) Shrink-to-Fit Height

Folder containers MUST be vertically sized to exactly fit their content (files, subfolders, and padding).

- **Rule**: No arbitrary minimum height (e.g., 140px) should be applied.
- **Visual Impact**: Small folders with only 1-2 files remain compact, reducing the overall vertical footprint of the diagram.

---

## 12) Determinism Requirements

To prevent jitter between runs:

- All ordering steps must have stable tiebreakers.
- Folder extraction must be deterministic.
- Cycle detection must be deterministic for the same graph.
- Edge styling must follow the priority rule strictly.
