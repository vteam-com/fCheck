/// Unified SVG definitions and styles for consistent visualization across all SVG exports.
library;

/// Utility class providing common SVG definitions, filters, gradients, and styles.
/// This consolidated approach minimizes duplication and ensures consistency.
class SvgDefinitions {
  /// Common filters

  /// White shadow filter for creating a subtle white glow effect around elements.
  /// Used for node rectangles and interactive elements.
  /// Creates depth and makes elements appear elevated from the background.
  static const String whiteShadowFilter = '''
  <filter id="whiteShadow" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="3"/>
    <feOffset dx="0" dy="0" result="offsetblur"/>
    <feFlood flood-color="white" flood-opacity="1"/>
    <feComposite in2="offsetblur" operator="in"/>
    <feMerge>
      <feMergeNode/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>''';

  /// Hierarchical shadow filter for folder containers.
  /// Creates a more pronounced shadow with offset to enhance the hierarchical structure.
  static const String hierarchicalShadowFilter = '''
  <filter id="hierarchicalShadow" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"/>
    <feOffset dx="2" dy="2" result="offsetblur"/>
    <feFlood flood-color="rgba(0,0,0,0.1)" flood-opacity="0.8"/>
    <feComposite in2="offsetblur" operator="in"/>
    <feMerge>
      <feMergeNode/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>''';

  /// White outline filter for text elements to improve readability against complex backgrounds.
  /// Creates a white border around text by dilating the alpha channel and filling with white.
  /// Essential for maintaining text visibility over gradients and patterns.
  static const String outlineWhiteFilter = '''
  <filter id="outlineWhite">
    <feMorphology in="SourceAlpha" result="DILATED" operator="dilate" radius="2"/>
    <feFlood flood-color="white" flood-opacity="0.5" result="WHITE"/>
    <feComposite in="WHITE" in2="DILATED" operator="in" result="OUTLINE"/>
    <feMerge>
      <feMergeNode in="OUTLINE"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>''';

  /// Common gradients

  /// Generic horizontal gradient (left green to right blue).
  /// Used for horizontal dependency arrows and edges.
  static const String horizontalGradient = '''
  <linearGradient id="horizontalGradient" x1="0%" y1="0%" x2="100%" y2="0%">
    <stop offset="0%" stop-color="#28a745"/>
    <stop offset="100%" stop-color="#007bff"/>
  </linearGradient>''';

  /// Generic vertical gradient (top green to bottom blue).
  /// Used for vertical dependency arrows and edges.
  static const String verticalGradient = '''
  <linearGradient id="verticalGradient" x1="0%" y1="0%" x2="0%" y2="100%">
    <stop offset="0%" stop-color="#28a745"/>
    <stop offset="100%" stop-color="#007bff"/>
  </linearGradient>''';

  /// Generate complete unified SVG definitions block.
  ///
  /// Returns a complete `<defs>` block containing all necessary filters and gradients:
  /// - White shadow filter for node depth
  /// - Hierarchical shadow filter for folder depth
  /// - Outline filter for text readability
  /// - Horizontal gradient for left-to-right edges
  /// - Vertical gradient for top-to-bottom edges
  /// - Hierarchical gradient for parent-child relationships
  ///
  /// Used by both [exportGraphSvg] and [exportGraphSvgFolders].
  static String generateUnifiedDefs() {
    return '''
<defs>
$whiteShadowFilter
$hierarchicalShadowFilter
$outlineWhiteFilter
$horizontalGradient
$verticalGradient
</defs>''';
  }

  /// Generate unified CSS styles for all SVG visualizations.
  ///
  /// Returns a complete `<style>` block containing:
  /// - Layer and hierarchical container styling
  /// - Node rectangle styling with hover effects
  /// - Text styling with outline filters
  /// - Unified edge styling that maintains gradients on hover
  /// - Unified badge styling with '?' cursor
  /// - File node styling
  ///
  /// Key features:
  /// - All edges maintain their gradient colors on hover
  /// - All badges use '?' cursor for help interaction
  /// - Consistent transition timing (0.1s) across all elements
  /// - Unified hover behavior for visual consistency
  static String generateUnifiedStyles() {
    return '''
<style>
  /* Container and layer styles */
  .layerBackground { 
    fill: rgba(52, 58, 64, 0.08); 
    stroke: #dee2e6; 
    stroke-width: 1; 
    stroke-dasharray: 4,4; 
  }

  .layerBackground:hover { 
    fill: rgba(52, 58, 64, 0.12); 
    stroke: black; 
    stroke-dasharray: 0; 
    transition: all 0.3s ease-in-out; 
  }
  
  .layerTitle { 
    fill: black; 
    font-size: 14px; 
    font-weight: bold; 
    text-anchor: middle; 
    filter: url(#outlineWhite); 
  }
  
  /* Node styles */
  .nodeRect { 
    fill: #ffffff; 
    stroke: #343a40; 
    stroke-width: 2; 
    rx: 6; 
    ry: 6; 
    cursor: pointer; 
    filter: url(#whiteShadow); 
    transition: all 0.1s ease-in-out; 
  }
  
  .nodeRect:hover { 
    stroke: black; 
    stroke-width: 5; 
  }
  
  .nodeText { 
    fill: #212529; 
    font-size: 14px; 
    font-weight: 900; 
    text-anchor: middle; 
    dominant-baseline: middle; 
    filter: url(#outlineWhite); 
  }
  
  /* File node styles */
  .fileNode { 
    fill: #ffffff; 
    stroke: #d0d7de; 
    stroke-width: 1; 
    transition: all 0.1s ease-in-out; 
  }
  
  .fileNode:hover { 
    stroke: #007bff; 
    stroke-width: 2; 
  }
  
  /* Unified edge styles */
  .edge { 
    fill: none; 
    stroke: url(#horizontalGradient); 
    stroke-width: 1; 
    opacity: 0.5;
    transition: all 0.1s ease-in-out; 
  }
  
  .edge:hover { 
    stroke: url(#horizontalGradient); 
    stroke-width: 3; 
    opacity: 1.0; 
  }
  
  .edgeVertical { 
    fill: none; 
    stroke: url(#verticalGradient); 
    stroke-width: 1; 
    opacity: 0.5; 
    transition: all 0.1s ease-in-out; 
  }
  
  .edgeVertical:hover { 
    stroke: url(#verticalGradient); 
    stroke-width: 3; 
    opacity: 1.0; 
  }
  
  /* Special edge styles */
  .cycleEdge { 
    fill: none; 
    stroke: red; 
    stroke-width: 5; 
    opacity: 0.9; 
  }
  
  .warningEdge { 
    fill: none; 
    stroke: orange; 
    stroke-width: 3; 
    opacity: 0.9; 
    transition: all 0.1s ease-in-out; 
  }
  
  .warningEdge:hover { 
    fill: none; 
    stroke: orange; 
    stroke-width: 5; 
    opacity: 1.0; 
  }
  
  /* Unified badge styles with '?' cursor */
  .badge { 
    font-size: 10px; 
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
  
  /* Special styles */
  .folderTitleLayer { 
    pointer-events: none; 
    isolation: isolate; 
  }
</style>''';
  }
}
