  function physicalLiteralClipboardControl(node) {
    return node && node.matches("button.copybutton") &&
      /^(?:copy|copy code to clipboard|copy to clipboard)$/i.test(normalizeText(node.getAttribute("aria-label") || node.getAttribute("title") || node.textContent)) &&
      (!normalizeText(node.textContent) || /^(?:copy|copy code to clipboard|copy to clipboard)$/i.test(normalizeText(node.textContent))) &&
      !node.querySelector("a, img, audio, video, iframe, object, [href], [src], [id], [name], input, select, textarea, p, table, pre");
  }

  function literalCodeTokenIdentified(node) {
    return node.hasAttribute("id") || node.hasAttribute("name") || node.hasAttribute("role") ||
      node.hasAttribute("tabindex") || node.hasAttribute("aria-label") || node.hasAttribute("title") ||
      node.hasAttribute("data-fetchutil-controlled");
  }

  function physicalLiteralCodeProjection(node, pruningOwnsAncestorChecks, sourceTreeHasNoShadow) {
    if (!node || node.nodeType !== 1 || !node.isConnected || node.ownerDocument !== document ||
        !node.querySelectorAll) return null;
    if (!node.matches("pre")) {
      // A prose/section owner cannot be a literal-only wrapper. Reject it from
      // direct physical children before repeatedly searching complete chapters.
      var children = Array.prototype.filter.call(node.children, function(child) {
        return !physicalLiteralClipboardControl(child);
      });
      if (!node.matches("div") || children.length !== 1 || !children[0].matches("div, pre") ||
          Array.prototype.some.call(node.childNodes, function(child) {
            return child.nodeType === 3 && child.textContent.trim();
          })) return null;
    }
    var pre = node.matches("pre") ? node : node.querySelector("pre");
    if (!pre || node.querySelectorAll("pre").length > 1) return null;
    // The paired whole-tree pruner checks each physical ancestor before it can
    // accept a projection. Standalone callers still prove that ancestry here.
    if (!pruningOwnsAncestorChecks && (elementSubtreeHidden(node) || ancestorHorizontalClipBounds(node))) return null;

    var wrappers = [];
    for (var current = pre.parentElement; current && current !== node.parentElement; current = current.parentElement) {
      var materialChildren = Array.prototype.filter.call(current.children, function(child) {
        return !physicalLiteralClipboardControl(child);
      });
      if (!current.matches("div") || materialChildren.length !== 1 ||
          Array.prototype.some.call(current.childNodes, function(child) {
            return child.nodeType === 3 && child.textContent.trim();
          })) return null;
      wrappers.unshift(current);
    }
    var sourceNodes = wrappers.concat([pre], Array.prototype.slice.call(pre.querySelectorAll("*")));
    if (sourceNodes.some(function(source) {
      var tag = source.localName;
      if (source.namespaceURI !== "http://www.w3.org/1999/xhtml" ||
          tag !== "div" && tag !== "pre" && tag !== "code" && tag !== "span" ||
          !sourceTreeHasNoShadow && nodeHasShadowContent(source) ||
          source !== pre && !wrappers.includes(source) && literalCodeTokenIdentified(source)) return true;
      if (source.hasAttribute("hidden") || source.hasAttribute("inert") || source.getAttribute("aria-hidden") === "true") return true;
      var style = sourceVisibilityStyle(source);
      return style.display === "none" || style.visibility !== "visible" || Number(style.opacity) === 0 ||
        /^(hidden|clip)$/.test(style.overflowX) || /^(hidden|clip)$/.test(style.overflowY);
    })) return null;

    var clone = pre.cloneNode(false);
    var originalCode = pre.querySelector("code");
    var code = originalCode ? originalCode.cloneNode(false) : document.createElement("code");
    // With only visible inline spans/code and text, the native aggregate is
    // exactly the literal program. Block-line DIVs retain the newline renderer.
    code.textContent = pre.querySelector("div") ? codeSurfaceText(pre) : pre.textContent;
    clone.appendChild(code);
    wrappers.slice().reverse().forEach(function(source) {
      var wrapper = source.cloneNode(false);
      wrapper.appendChild(clone);
      clone = wrapper;
    });
    return clone;
  }

  function physicalManualVisibilityClone(node) {
    // The immutable physical subtree's complete composed-content proof covers
    // every token. Composed/manual fallback paths still check each token fresh.
    return withIndexedPhysicalVisibility(node, function() {
      var sourceTreeHasNoShadow = !nodeHasShadowContent(node);
      return visibilityPrunedClone(node, document, null, false, function(source) {
        return source.matches("pre, div") ? physicalLiteralCodeProjection(source, true, sourceTreeHasNoShadow) : null;
      });
    });
  }
