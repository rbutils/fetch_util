  var composedDomReadContext = null;
  var composedDomShadowToken = null;
  var composedDomShadowReaderProperty = null;

  function composedDomShadowRoot(node) {
    if (!node) return null;
    if (node.shadowRoot) return node.shadowRoot;
    try {
      var reader = composedDomShadowReaderProperty && window[composedDomShadowReaderProperty];
      return typeof reader === "function" ? reader(composedDomShadowToken, "get", node) || null : null;
    } catch (_error) {
      return null;
    }
  }

  function composedDomParent(node) {
    if (!node) return null;
    return node.assignedSlot || node.parentElement || (node.getRootNode && node.getRootNode().host) || null;
  }

  function composedDomChildren(node) {
    var shadowRoot = composedDomShadowRoot(node);
    if (shadowRoot) return Array.prototype.slice.call(shadowRoot.childNodes);
    if (node && node.tagName === "SLOT" && node.getRootNode().host) {
      var assigned = node.assignedNodes();
      if (assigned.length) return Array.prototype.slice.call(assigned);
    }
    return Array.prototype.slice.call((node && node.childNodes) || []);
  }

  function nodeHasShadowContent(node) {
    if (!node) return false;
    if (composedDomShadowRoot(node) || (node.nodeType === 11 && node.host)) return true;
    if (composedDomReadContext && (node === document || (node.isConnected && node.ownerDocument === document))) {
      return composedDomReadContext.has(node);
    }
    return !!(node.querySelectorAll && Array.prototype.some.call(node.querySelectorAll("*"), function(child) {
      return !!composedDomShadowRoot(child);
    }));
  }

  function pageContentProbe(content) {
    var root = document.createElement("div");
    if (content && content.html) {
      root.innerHTML = content.html;
    } else if (nodeHasShadowContent(document.body)) {
      var clone = visibilityPrunedClone(document.body, document);
      while (clone.firstChild) root.appendChild(clone.firstChild);
    } else {
      root.innerHTML = (document.body && document.body.innerHTML) || "";
    }
    return root;
  }

  function withComposedDomRead(extract) {
    return function(options) {
      var previous = composedDomReadContext;
      var previousToken = composedDomShadowToken;
      var previousReaderProperty = composedDomShadowReaderProperty;
      var context = new WeakSet();
      composedDomShadowToken = options && options.shadow_root_token;
      composedDomShadowReaderProperty = options && options.shadow_root_reader_property;
      var roots = [document];
      for (var index = 0; index < roots.length; index += 1) {
        Array.prototype.forEach.call(roots[index].querySelectorAll("*"), function(node) {
          var shadowRoot = composedDomShadowRoot(node);
          if (!shadowRoot) return;
          roots.push(shadowRoot);
          context.add(document);
          for (var parent = node; parent; parent = composedDomParent(parent)) context.add(parent);
        });
      }
      composedDomReadContext = context;
      try {
        return extract(options);
      } finally {
        composedDomReadContext = previous;
        composedDomShadowToken = previousToken;
        composedDomShadowReaderProperty = previousReaderProperty;
      }
    };
  }
