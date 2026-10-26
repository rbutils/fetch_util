  var sourceVisibilityReadContext = null;

  function clearProfileRevealReads(context, root, nodes) {
    nodes.forEach(function(node) {
      context.hidden.delete(node);
      for (var current = node; current; current = current.parentElement) {
        context.escaping.delete(current);
        if (current === root) break;
      }
    });
  }

  function withSourceVisibilityRead(extract, options) {
    var previous = sourceVisibilityReadContext;
    var root = options && options.profileRoot;
    var shared = previous && root;
    var declarations = shared ? Array.from(root.querySelectorAll("[data-animation-style]")) : [];
    if (shared && root.hasAttribute("data-animation-style")) declarations.unshift(root);
    sourceVisibilityReadContext = {
      hidden: shared ? previous.hidden : new WeakMap(),
      escaping: shared ? previous.escaping : new WeakMap(),
      profileRoot: root
    };
    // The physical page is unchanged. Only the scoped reveal interpretation varies.
    if (shared) clearProfileRevealReads(previous, root, declarations);
    try {
      return extract();
    } finally {
      if (shared) clearProfileRevealReads(previous, root, declarations);
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
