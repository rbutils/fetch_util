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
    if (!bounds || !node || !node.isConnected || !style || /^(inline|contents)$/.test(style.display)) return false;
    var rect = node.getBoundingClientRect();
    if (!rect.width || (rect.right > bounds.left && rect.left < bounds.right)) return false;
    // Long code lines remain complete; their enclosing off-screen panel can still be excluded.
    for (var parent = composedDomParent(node); parent; parent = composedDomParent(parent)) {
      if (parent.matches && parent.matches("pre, code, kbd, samp, .CodeMirror, .cm-editor")) return false;
    }
    return true;
  }
