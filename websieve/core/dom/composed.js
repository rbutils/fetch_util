  var composedDomReadContext = null;

  function composedDomParent(node) {
    if (!node) return null;
    return node.assignedSlot || node.parentElement || (node.getRootNode && node.getRootNode().host) || null;
  }

  function composedDomChildren(node) {
    if (node && node.shadowRoot) return Array.prototype.slice.call(node.shadowRoot.childNodes);
    if (node && node.tagName === "SLOT" && node.getRootNode().host) {
      var assigned = node.assignedNodes();
      if (assigned.length) return Array.prototype.slice.call(assigned);
    }
    return Array.prototype.slice.call((node && node.childNodes) || []);
  }

  function nodeHasOpenShadowContent(node) {
    if (!node) return false;
    if (node.shadowRoot || (node.nodeType === 11 && node.host)) return true;
    if (composedDomReadContext && (node === document || (node.isConnected && node.ownerDocument === document))) {
      return composedDomReadContext.has(node);
    }
    return !!(node.querySelectorAll && Array.prototype.some.call(node.querySelectorAll("*"), function(child) {
      return !!child.shadowRoot;
    }));
  }

  function pageContentProbe(content) {
    var root = document.createElement("div");
    if (content && content.html) {
      root.innerHTML = content.html;
    } else if (nodeHasOpenShadowContent(document.body)) {
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
      var context = new WeakSet();
      var roots = [document];
      for (var index = 0; index < roots.length; index += 1) {
        Array.prototype.forEach.call(roots[index].querySelectorAll("*"), function(node) {
          if (!node.shadowRoot) return;
          roots.push(node.shadowRoot);
          context.add(document);
          for (var parent = node; parent; parent = composedDomParent(parent)) context.add(parent);
        });
      }
      composedDomReadContext = context;
      try {
        return extract(options);
      } finally {
        composedDomReadContext = previous;
      }
    };
  }
