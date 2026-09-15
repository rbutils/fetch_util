  function overflowEscapingDescendant(node) {
    return composedDomChildren(node).some(function(child) {
      return child.nodeType === 1 && (/^(absolute|fixed)$/.test(window.getComputedStyle(child).position) || overflowEscapingDescendant(child));
    });
  }

  function collapsedOverflowNode(node, style) {
    if (!node || !node.isConnected || !style || !/^(block|flow-root|inline-block|flex|inline-flex|grid|inline-grid|list-item)$/.test(style.display)) return false;
    var clipMargin = style.overflowClipMargin || "0px";
    var zeroClipMargin = /^(?:(?:content|padding|border)-box\s+)?0(?:\.0+)?(?:px)?$/.test(clipMargin);
    var clipsX = style.overflowX === "hidden" || (style.overflowX === "clip" && zeroClipMargin);
    var clipsY = style.overflowY === "hidden" || (style.overflowY === "clip" && zeroClipMargin);
    if (!clipsX && !clipsY) return false;
    var rect = node.getBoundingClientRect();
    if (!(clipsX && rect.width === 0) && !(clipsY && rect.height === 0)) return false;
    // Out-of-flow descendants can use a containing block outside this clipping box.
    return !overflowEscapingDescendant(node);
  }

  function horizontalClipBounds(node, style, bounds) {
    if (!node || !node.isConnected || !style || !/^(hidden|clip)$/.test(style.overflowX)) return bounds;
    var rect = node.getBoundingClientRect();
    if (!rect.width) return bounds;
    return {
      left: bounds ? Math.max(bounds.left, rect.left) : rect.left,
      right: bounds ? Math.min(bounds.right, rect.right) : rect.right
    };
  }

  function ancestorHorizontalClipBounds(node) {
    var bounds = null;
    for (var parent = composedDomParent(node); parent; parent = composedDomParent(parent)) {
      if (parent.nodeType !== 1) continue;
      bounds = horizontalClipBounds(parent, window.getComputedStyle(parent), bounds);
    }
    return bounds;
  }

  function horizontallyClippedElement(node, style, bounds) {
    if (!bounds || !node || !node.isConnected || !style || style.display === "contents") return false;
    var rect = node.getBoundingClientRect();
    if (!rect.width || (rect.right > bounds.left && rect.left < bounds.right)) return false;
    // Long code lines remain complete; their enclosing off-screen panel can still be excluded.
    for (var parent = composedDomParent(node); parent; parent = composedDomParent(parent)) {
      if (parent.matches && parent.matches("pre, code, kbd, samp, .CodeMirror, .cm-editor")) return false;
    }
    return true;
  }
