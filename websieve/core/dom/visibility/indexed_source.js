  var indexedPhysicalVisibility = null;

  function sharedPhysicalVisibilityStyle(style, records) {
    if (!style) return null;
    var opacity = style.opacity;
    // Only the opacity-zero deferred-reveal path consumes computed transform.
    // Reading it for every visible token can resolve otherwise unused geometry.
    var transform = opacity !== "" && Number(opacity) === 0 ? style.transform : null;
    var values = [style.display, style.visibility, opacity, style.overflowX,
      style.overflowY, style.overflowClipMargin, transform];
    var branch = records;
    for (var index = 0; index < values.length - 1; index++) {
      if (!branch.has(values[index])) branch.set(values[index], new Map());
      branch = branch.get(values[index]);
    }
    var key = values[values.length - 1];
    if (!branch.has(key)) {
      branch.set(key, {display: values[0], visibility: values[1], opacity: values[2],
        overflowX: values[3], overflowY: values[4], overflowClipMargin: values[5], transform: values[6]});
    }
    return branch.get(key);
  }

  function withIndexedPhysicalVisibility(node, read) {
    if (!node || node.nodeType !== 1 || !node.isConnected || node.ownerDocument !== document ||
        !node.getRootNode || node.getRootNode() !== document ||
        (composedDomShadowReaderProperty && !composedDomStableShadowReaderKnown) || nodeHasShadowContent(node)) return read();
    var previous = indexedPhysicalVisibility;
    try {
      // Construction writes only to an inert document. Read immutable source
      // styles on demand, so an excluded ancestor excludes its descendants from
      // both native style resolution and transient clone construction.
      indexedPhysicalVisibility = { root: node, nodes: new WeakMap(), styles: new Map() };
      return read();
    } finally {
      indexedPhysicalVisibility = previous;
    }
  }

  function sourceVisibilityStyle(node) {
    var context = indexedPhysicalVisibility;
    if (context && node && node.ownerDocument === document && node.isConnected && context.root.contains(node)) {
      if (!context.nodes.has(node)) {
        var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
        context.nodes.set(node, sharedPhysicalVisibilityStyle(style, context.styles));
      }
      return context.nodes.get(node);
    }
    return window.getComputedStyle ? window.getComputedStyle(node) : null;
  }

  function sourceVisibilityChildren(node, physicalTree) {
    return physicalTree ? Array.prototype.slice.call(node.childNodes || []) : composedDomChildren(node);
  }
