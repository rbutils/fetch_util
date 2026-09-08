  function hostMatches(pattern, host) {
    host = host || location.hostname || "";

    if (!pattern) return false;
    if (Array.isArray(pattern)) {
      for (var i = 0; i < pattern.length; i += 1) {
        if (hostMatches(pattern[i], host)) return true;
      }
      return false;
    }
    if (pattern instanceof RegExp) return pattern.test(host);
    if (typeof pattern === "function") return pattern(host);
    if (typeof pattern === "string") return host === pattern || host.slice(-(pattern.length + 1)) === "." + pattern;
    return false;
  }

  function domainLikeText(text) {
    return /^[\w.-]+\.[a-z]{2,}$/i.test(normalizeText(text || ""));
  }

  function cloneIntoDocument(node, ownerDoc) {
    ownerDoc = ownerDoc || document;
    if (!node) return null;
    if (node.nodeType === 3) return ownerDoc.createTextNode(node.textContent || "");
    if (node.nodeType !== 1) return null;

    var tag = (node.tagName || "").toLowerCase();
    var cloneTag = tag && !/-/.test(tag) ? tag : "div";
    var clone;
    try {
      clone = ownerDoc.createElement(cloneTag || "div");
    } catch (e) {
      clone = ownerDoc.createElement("div");
    }

    Array.prototype.forEach.call(node.attributes || [], function(attr) {
      if (!attr || !attr.name || /^on/i.test(attr.name)) return;
      try {
        clone.setAttribute(attr.name, attr.value);
      } catch (e) {}
    });

    Array.prototype.forEach.call(node.childNodes || [], function(child) {
      var childClone = cloneIntoDocument(child, ownerDoc);
      if (childClone) clone.appendChild(childClone);
    });

    return clone;
  }

  function safeDeepClone(node, ownerDoc) {
    try {
      return node.cloneNode(true);
    } catch (e) {
      return cloneIntoDocument(node, ownerDoc);
    }
  }

  function elementSubtreeHiddenWithin(node, boundary) {
    var current = node;
    while (current && current !== boundary && current.nodeType === 1) {
      var style = window.getComputedStyle ? window.getComputedStyle(current) : null;
      if (current.hidden) return true;
      if (style && (style.display === "none" || (style.opacity !== "" && Number(style.opacity) === 0 && !deferredRevealContentNode(current, style)))) return true;
      current = current.parentElement;
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

  function pruneHiddenClone(source, clone, preservedRoots, preservingRoot) {
    if (!source || !clone) return;
    var exactPreservedRoot = !!(preservedRoots && preservedRoots.indexOf(source) !== -1);
    var preservedRoot = exactPreservedRoot ? source : preservingRoot;
    var subtreeHidden = preservedRoot ? elementSubtreeHiddenWithin(source, preservedRoot) : elementSubtreeHidden(source);
    if (source.nodeType === 1 && !exactPreservedRoot && subtreeHidden) {
      clone.remove();
      return;
    }

    if (source.nodeType === 1 && exactPreservedRoot) {
      clone.removeAttribute("hidden");
      clone.removeAttribute("inert");
      if (clone.getAttribute("aria-hidden") === "true") clone.removeAttribute("aria-hidden");
      if (clone.style) {
        clone.style.removeProperty("display");
        clone.style.removeProperty("visibility");
        clone.style.removeProperty("opacity");
        if (!clone.getAttribute("style")) clone.removeAttribute("style");
      }
      clone.setAttribute("data-fetchutil-controlled-list-panel", "true");
    }

    var visibilityHidden = source.nodeType === 1 && !exactPreservedRoot &&
      (preservedRoot ? elementVisuallyHiddenWithin(source, preservedRoot) : elementVisuallyHidden(source));
    var sourceChildren = Array.prototype.slice.call(source.childNodes || []);
    var cloneChildren = Array.prototype.slice.call(clone.childNodes || []);
    sourceChildren.forEach(function(child, index) {
      var childClone = cloneChildren[index];
      if (!childClone) return;
      if (visibilityHidden && child.nodeType !== 1) {
        childClone.remove();
        return;
      }
      pruneHiddenClone(child, childClone, preservedRoots, preservedRoot);
    });

    if (visibilityHidden) {
      clone.style.setProperty("visibility", "visible", "important");
      ["aria-label", "title", "alt", "value"].forEach(function(attribute) {
        clone.removeAttribute(attribute);
      });
      if (!clone.children.length) clone.remove();
    }
  }

  function visibilityPrunedClone(node, ownerDoc) {
    if (!node || elementSubtreeHidden(node)) return (ownerDoc || document).createElement("div");
    var clone = safeDeepClone(node, ownerDoc || document);
    if (!clone) return (ownerDoc || document).createElement("div");
    pruneHiddenClone(node, clone);
    return clone;
  }

  function topLevelQualifiedDescendants(root, selector, qualifies) {
    var nodes = Array.prototype.slice.call(root.querySelectorAll(selector));
    return nodes.filter(function(node, index) {
      if (qualifies && !qualifies(node)) return false;
      return !nodes.some(function(other, otherIndex) {
        return otherIndex < index && other.contains(node);
      });
    });
  }

  function safeReadableDocumentClone() {
    try {
      return document.cloneNode(true);
    } catch (e) {}

    var fallback = document.implementation.createHTMLDocument(document.title || "");
    if (document.documentElement && document.documentElement.getAttribute("lang")) {
      fallback.documentElement.setAttribute("lang", document.documentElement.getAttribute("lang"));
    }

    while (fallback.head.firstChild) fallback.head.removeChild(fallback.head.firstChild);
    Array.prototype.forEach.call((document.head && document.head.childNodes) || [], function(child) {
      var childClone = cloneIntoDocument(child, fallback);
      if (childClone) fallback.head.appendChild(childClone);
    });

    if (document.body) {
      var bodyClone = cloneIntoDocument(document.body, fallback) || fallback.createElement("body");
      fallback.documentElement.replaceChild(bodyClone, fallback.body);
    }

    return fallback;
  }

  function cleanClone(node, preserveSelector) {
    if (cookieChromeNode(node)) {
      var empty = document.createElement("div");
      return empty;
    }

    var clone = safeDeepClone(node, document);
    if (!clone) return document.createElement("div");
    if (preserveSelector) {
      clone.querySelectorAll(preserveSelector).forEach(function(el) {
        el.setAttribute("data-fetchutil-preserve", "true");
      });
    }
    cleanupCookieChrome(clone);
    preserveMeaningfulButtons(clone);
    // Preserve ReDoc endpoint bars before removing buttons.
    // These have: <button><span class="http-verb get">get</span><span>/path</span></button>
    clone.querySelectorAll("button").forEach(function(btn) {
      var verb = btn.querySelector("[class*='http-verb']");
      if (!verb) return;
      var path = "";
      var spans = btn.querySelectorAll("span");
      for (var si = 0; si < spans.length; si++) {
        if (spans[si] !== verb && !spans[si].querySelector("[class*='http-verb']") && !/collapser|ellipsis|arrow/i.test(spans[si].className || "")) {
          var t = normalizeText(spans[si].textContent);
          if (t && /^\//.test(t)) { path = t; break; }
        }
      }
      if (path) {
        var methodLine = document.createElement("p");
        methodLine.innerHTML = "<code>" + normalizeText(verb.textContent).toUpperCase() + " " + path + "</code>";
        btn.replaceWith(methodLine);
      }
    });
    clone.querySelectorAll("script, style, noscript, template, iframe, form, button, input, aside, nav, footer").forEach(function(el) {
      if (!el.hasAttribute("data-fetchutil-preserve")) el.remove();
    });
    return materializeHttpAttributes(clone, true);
  }

  function preserveMeaningfulButtons(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("button, [role='button'], input[type='button'], input[type='submit']").forEach(function(el) {
      var text = normalizeText(el.innerText || el.textContent || el.getAttribute("value") || "");
      if (el.hasAttribute("data-fetchutil-preserve") || !meaningfulButtonText(text)) return;

      var replacement = document.createElement("p");
      replacement.textContent = text;
      replacement.setAttribute("data-fetchutil-button-text", "true");
      el.replaceWith(replacement);
    });

    return root;
  }
