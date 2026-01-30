# Folder-Based Dependency Visualization Layout (Execution Spec)

This spec defines **how to compute and render** a dependency diagram that shows the project **as it exists**, using folder containers and file nodes. The layout is driven purely by **observed dependencies** (imports), while folders preserve the **human grouping constraint**.
The folder-based SVG visualization provides a hierarchical view of project dependencies organized by folder structure. This layout helps identify architectural patterns, component relationships, and potential refactoring opportunities.

---

## 1) Inputs and Outputs

### Input

A directed file dependency graph:

- File nodes: `filePath`
- File edges: `A → B` meaning “A depends on B”

### Output

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
