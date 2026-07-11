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
    cleanupCookieChrome(clone);
    clone.querySelectorAll("a").forEach(function(el) {
      var href = el.getAttribute("href");
      if (href) el.setAttribute("href", absoluteUrl(href));
    });
    clone.querySelectorAll("img").forEach(function(el) {
      var src = el.getAttribute("src");
      var lazySrc = el.getAttribute("data-lazy-src") || el.getAttribute("data-src") || el.getAttribute("data-original") || el.getAttribute("data-lazy");
      // Prefer lazy-load attribute when src is a placeholder (data URI or empty)
      if (lazySrc && (!src || /^data:image\//i.test(src))) src = lazySrc;
      if (!src) src = lazySrc;
      if (src) el.setAttribute("src", absoluteUrl(src));
    });
    return clone;
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
