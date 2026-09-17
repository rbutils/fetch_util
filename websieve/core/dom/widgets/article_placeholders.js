function articleAdStructureTokens(node) {
  if (!node || !node.getAttribute) return [];
  return ["id", "class"].reduce(function(tokens, attribute) {
    var value = String(node.getAttribute(attribute) || "").replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
    return tokens.concat(value.split(/[^a-z0-9]+/).filter(Boolean));
  }, []);
}

function articlePlaceholderReferenceTokens(value) {
  var text = String(value || "");
  var tokens = text.split(/[^a-z0-9_.:-]+/i).filter(Boolean);
  var match;
  var fragmentPattern = /#([a-z_][a-z0-9_:-]*)/ig;
  while ((match = fragmentPattern.exec(text))) tokens.push(match[1]);
  var timingPattern = /(?:^|;)\s*([a-z_][a-z0-9_:-]*)\.[a-z_]/ig;
  while ((match = timingPattern.exec(text))) tokens.push(match[1]);
  return tokens;
}

function articlePlaceholderContext(doc) {
  var context = { sourcesById: new Map(), referencedIds: new Set(), owners: new WeakMap(), uncertain: false };
  if (!doc || !doc.querySelectorAll) return context;
  var idReferenceNames = /^(?:for|form|headers|itemref|list|contextmenu|popovertarget|commandfor|aria-activedescendant|aria-controls|aria-describedby|aria-details|aria-errormessage|aria-flowto|aria-labelledby|aria-owns)$/;
  var current;
  try { current = new URL(doc.location.href); } catch (_error) { context.uncertain = true; }

  Array.from(doc.querySelectorAll("*")).forEach(function(candidate) {
    var id = String(candidate.getAttribute("id") || "");
    if (id) {
      if (!context.sourcesById.has(id)) context.sourcesById.set(id, []);
      context.sourcesById.get(id).push(candidate);
    }

    Array.from(candidate.attributes || []).forEach(function(attribute) {
      var name = String(attribute.localName || attribute.name || "").toLowerCase();
      var value = String(attribute.value || "");
      if (!idReferenceNames.test(name)) return;
      value.split(/\s+/).filter(Boolean).forEach(function(referenceId) {
        context.referencedIds.add(referenceId);
      });
    });

    Array.from(candidate.attributes || []).forEach(function(attribute) {
      var name = String(attribute.localName || attribute.name || "").toLowerCase();
      if (/^(?:id|class|data-placeholder-caption|href|xlink:href)$/.test(name)) return;
      articlePlaceholderReferenceTokens(attribute.value).forEach(function(referenceId) {
        context.referencedIds.add(referenceId);
      });
    });
    if (candidate.tagName === "STYLE") {
      articlePlaceholderReferenceTokens(candidate.textContent).forEach(function(referenceId) {
        context.referencedIds.add(referenceId);
      });
    }

    var hrefs = [
      candidate.getAttribute("href"),
      candidate.getAttributeNS("http://www.w3.org/1999/xlink", "href"),
      candidate.getAttribute("xlink:href")
    ].filter(Boolean);
    hrefs.filter(function(href, index) { return hrefs.indexOf(href) === index; }).forEach(function(href) {
      if (String(href).indexOf("#") === -1) return;
      try {
        var target = new URL(href, doc.baseURI);
        var sameDocument = current && target.origin === current.origin &&
          target.pathname === current.pathname && target.search === current.search;
        if (!sameDocument || !target.hash) return;
        var fragment = target.hash.slice(1);
        try { fragment = decodeURIComponent(fragment); } catch (_decodeError) { /* Preserve the exact fragment. */ }
        if (fragment) context.referencedIds.add(fragment);
      } catch (_urlError) {
        var hashIndex = String(href).lastIndexOf("#");
        if (hashIndex === -1) return;
        var rawFragment = String(href).slice(hashIndex + 1);
        try { rawFragment = decodeURIComponent(rawFragment); } catch (_decodeError) { /* Preserve the exact fragment. */ }
        if (rawFragment) context.referencedIds.add(rawFragment);
      }
    });
  });
  return context;
}

function articleNestedPlaceholderNodes(root) {
  var nested = new WeakSet();
  var stack = [{ node: root, inside: false }];
  while (stack.length) {
    var entry = stack.pop();
    if (!entry.node || entry.node.nodeType !== 1) continue;
    var placeholder = !!(entry.node.matches && entry.node.matches("[data-placeholder-caption]"));
    if (placeholder && entry.inside) nested.add(entry.node);
    var inside = entry.inside || placeholder;
    Array.from(entry.node.children || []).forEach(function(child) {
      stack.push({ node: child, inside: inside });
    });
  }
  return nested;
}
