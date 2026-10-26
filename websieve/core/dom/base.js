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
    if (node.nodeType === 8) return ownerDoc.createComment(node.textContent || "");
    if (node.nodeType === 11) {
      var fragment = ownerDoc.createDocumentFragment();
      composedDomChildren(node).forEach(function(child) {
        var childClone = cloneIntoDocument(child, ownerDoc);
        if (childClone) fragment.appendChild(childClone);
      });
      return fragment;
    }
    if (node.nodeType !== 1) return null;

    var tag = (node.tagName || "").toLowerCase();
    var cloneTag = tag && !/-/.test(tag) ? tag : "div";
    var clone;
    try {
      clone = node.namespaceURI && node.namespaceURI !== "http://www.w3.org/1999/xhtml" ?
        ownerDoc.createElementNS(node.namespaceURI, node.localName) : ownerDoc.createElement(cloneTag || "div");
    } catch (e) {
      clone = ownerDoc.createElement("div");
    }

    Array.prototype.forEach.call(node.attributes || [], function(attr) {
      if (!attr || !attr.name || /^on/i.test(attr.name)) return;
      try {
        if (attr.namespaceURI) clone.setAttributeNS(attr.namespaceURI, attr.name, attr.value);
        else clone.setAttribute(attr.name, attr.value);
      } catch (e) {}
    });

    composedDomChildren(node).forEach(function(child) {
      var childClone = cloneIntoDocument(child, ownerDoc);
      if (childClone) clone.appendChild(childClone);
    });

    return clone;
  }

  function safeDeepClone(node, ownerDoc) {
    try {
      if (nodeHasShadowContent(node)) {
        var inertDoc = ownerDoc && !ownerDoc.defaultView ? ownerDoc : document.implementation.createHTMLDocument("");
        return cloneIntoDocument(node, inertDoc);
      }
      return node.cloneNode(true);
    } catch (e) {
      return cloneIntoDocument(node, ownerDoc);
    }
  }

  function visibilityPrunedClone(node, ownerDoc, sourceClones, collectionFlow, sourceProjection) {
    if (!node || elementSubtreeHidden(node)) return (ownerDoc || document).createElement("div");
    var physicalTree = node.isConnected && node.ownerDocument === document && node.getRootNode() === document &&
      (!composedDomShadowReaderProperty || composedDomStableShadowReaderKnown) && !nodeHasShadowContent(node);
    if (sourceProjection && !sourceClones && physicalTree) {
      var physicalClone = visibilityPrunedPhysicalClone(node, sourceProjection, collectionFlow);
      if (physicalClone) return physicalClone;
      // The stateful/template fallback retains the complete native copy,
      // including its ordinary presentation descendants.
      sourceProjection = null;
    }
    var clone = safeDeepClone(node, ownerDoc || document);
    if (!clone) return (ownerDoc || document).createElement("div");
    pruneHiddenClone(node, clone, null, null, false, sourceClones, null, collectionFlow === true, sourceProjection, physicalTree);
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
      if (nodeHasShadowContent(document.documentElement)) {
        var composed = document.cloneNode(false);
        composed.appendChild(cloneIntoDocument(document.documentElement, composed));
        return composed;
      }
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

  function mapDomCloneElements(source, clone, elementMap) {
    if (!source || !clone || source.nodeType !== clone.nodeType ||
        (source.nodeType === 1 && source.tagName !== clone.tagName)) return;
    elementMap.set(source, clone);
    var sourceChildren = source.childNodes || [];
    var cloneChildren = clone.childNodes || [];
    if (sourceChildren.length !== cloneChildren.length) return;
    for (var index = 0; index < sourceChildren.length; index++) {
      mapDomCloneElements(sourceChildren[index], cloneChildren[index], elementMap);
    }
  }

  function cleanClone(node, preserveSelector, elementMap) {
    if (cookieChromeNode(node)) {
      var empty = document.createElement("div");
      return empty;
    }

    var clone = safeDeepClone(node, document);
    if (!clone) return document.createElement("div");
    return cleanClonedContent(node, clone, preserveSelector, elementMap);
  }

  function disposableDomRoot(node) {
    return !!(node && node.nodeType === 1 && !node.parentNode && !node.isConnected &&
      node.ownerDocument && node.ownerDocument !== document && !node.ownerDocument.defaultView);
  }

  function cleanDisposableClone(node, preserveSelector) {
    // Only a caller-owned, detached inert root may be consumed. Physical source
    // nodes and children still owned by another tree retain the copying path.
    if (!disposableDomRoot(node)) return cleanClone(node, preserveSelector);
    if (cookieChromeNode(node)) return document.createElement("div");
    return cleanClonedContent(node, node, preserveSelector, null);
  }

  function articleOwnedFooter(node) {
    if (!node || node.tagName !== "FOOTER") return false;
    if (node.closest("nav, form, button, [role~='navigation' i], [role~='contentinfo' i]")) return false;
    return !!node.closest("article, [itemprop~='articleBody' i]");
  }

  function materializeArticleOwnedFooters(root) {
    root.querySelectorAll("footer").forEach(function(footer) {
      if (!articleOwnedFooter(footer)) return;
      var replacement = footer.ownerDocument.createElement("div");
      Array.from(footer.attributes).forEach(function(attribute) {
        replacement.setAttribute(attribute.name, attribute.value);
      });
      while (footer.firstChild) replacement.appendChild(footer.firstChild);
      footer.replaceWith(replacement);
    });
  }

  function cleanClonedContent(source, clone, preserveSelector, elementMap) {
    elementMap = materializeEditorialPreviewImages(source, clone, elementMap);
    materializeEditorialFrameLinks(source, clone, elementMap);
    preserveSvgCloneVisibility(source, clone, elementMap);
    prepareSourceOwnedEngagementClone(source, clone, elementMap);
    clone = materializeFooterDataGroups(source, clone, elementMap);
    normalizeCodeSurfaces(clone);
    if (preserveSelector) {
      clone.querySelectorAll(preserveSelector).forEach(function(el) {
        el.setAttribute("data-fetchutil-preserve", "true");
      });
    }
    materializeArticleOwnedFooters(clone);
    cleanupCookieChrome(clone);
    stripArticleWidgets(clone);
    if (stripEmptyCommentUi(clone)) return document.createElement("div");
    if (clone.matches("form[class~='comment-form' i], form[id='comment-form-div' i]")) {
      var commentContent = document.createElement("div");
      while (clone.firstChild) commentContent.appendChild(clone.firstChild);
      clone = commentContent;
    }
    preserveLinkedResourceButtons(clone);
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
      var record = el.tagName === "FOOTER" && el.closest("a[href]");
      if (record && genericListWrappedAnchorCard(record) && !el.querySelector("a, button, input")) {
        while (el.firstChild) el.parentNode.insertBefore(el.firstChild, el);
        el.remove();
        return;
      }
      if (!el.hasAttribute("data-fetchutil-preserve")) el.remove();
    });
    return materializeHttpAttributes(clone, true);
  }

  function meaningfulDisclosureHeading(el, heading, text) {
    if (!heading || !text || !/^(true|false)$/.test(el.getAttribute("aria-expanded") || "")) return false;
    var popup = el.getAttribute("aria-haspopup");
    if (popup && popup !== "false") return false;
    if (heading.closest("nav, form, [role~='navigation' i], [role~='menu' i], [role~='menubar' i], [role~='toolbar' i]")) return false;
    if (el.querySelector("[class*='http-verb']")) return false;
    if (normalizeText(heading.innerText || heading.textContent || "") !== text) return false;
    return !cookieNoticeText(text) && !utilityHeadingText(text) &&
      !playerControlText(text) && !BUTTON_ACTION_TEXT_PATTERN.test(text);
  }

  function preserveMeaningfulButtons(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("button, [role='button'], input[type='button'], input[type='submit']").forEach(function(el) {
      var text = normalizeText(el.innerText || el.textContent || el.getAttribute("value") || "");
      if (el.hasAttribute("data-fetchutil-preserve")) return;
      if (el.tagName !== "BUTTON" && el.getAttribute("role") === "button" &&
          el.querySelector("a[href], pre, code, table, img, picture, video, audio, article, section, ul, ol, blockquote")) return;
      var heading = el.parentElement && el.parentElement.closest("h1, h2, h3, h4, h5, h6");
      if (!meaningfulButtonText(text) && !meaningfulDisclosureHeading(el, heading, text)) return;
      var replacement = document.createElement(heading ? "span" : "p");
      replacement.textContent = text;
      replacement.setAttribute("data-fetchutil-button-text", "true");
      el.replaceWith(replacement);
    });

    return root;
  }
