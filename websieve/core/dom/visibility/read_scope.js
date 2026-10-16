  var sourceVisibilityReadContext = null;

  function withSourceVisibilityRead(extract) {
    var previous = sourceVisibilityReadContext;
    sourceVisibilityReadContext = { hidden: new WeakMap(), escaping: new WeakMap() };
    try {
      return extract();
    } finally {
      sourceVisibilityReadContext = previous;
    }
  }

  function elementOwnSubtreeHidden(node, knownStyle) {
    // Only the physical page is immutable during this synchronous read. Detached
    // rendering trees remain fresh, and no style object or clone is retained.
    var cache = sourceVisibilityReadContext && node.isConnected && node.ownerDocument === document
      ? sourceVisibilityReadContext.hidden : null;
    if (cache && cache.has(node)) return cache.get(node);
    var hidden = computeElementOwnSubtreeHidden(node, knownStyle, arguments.length > 1);
    if (cache) cache.set(node, hidden);
    return hidden;
  }

  function computeElementOwnSubtreeHidden(node, knownStyle, styleKnown) {
    if (node.parentElement && node.parentElement.shadowRoot && !node.assignedSlot) return true;
    var style = styleKnown ? knownStyle : sourceVisibilityStyle(node);
    if (node.hidden) return true;
    if (style && (style.display === "none" || (style.opacity !== "" && Number(style.opacity) === 0 && !deferredRevealContentNode(node, style)))) return true;
    return collapsedOverflowNode(node, style);
  }
