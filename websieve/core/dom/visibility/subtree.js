  function elementSubtreeHiddenWithin(node, boundary) {
    var current = node && node.nodeType === 11 && node.host ? node.host : node;
    while (current && current !== boundary && current.nodeType === 1) {
      if (elementOwnSubtreeHidden(current)) return true;
      current = composedDomParent(current);
    }
    return false;
  }

  function elementSubtreeHidden(node) {
    return elementSubtreeHiddenWithin(node, null);
  }

  function elementVisuallyHiddenWithin(node, boundary) {
    if (!node || node.nodeType !== 1) return false;
    if (elementSubtreeHiddenWithin(node, boundary)) return true;
    var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    return !!(style && (style.visibility === "hidden" || style.visibility === "collapse"));
  }

  function elementVisuallyHidden(node) {
    return elementVisuallyHiddenWithin(node, null);
  }
