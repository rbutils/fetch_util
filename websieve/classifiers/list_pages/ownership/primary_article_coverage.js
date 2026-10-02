function sourceOwnedPrimaryMaterialSignature(node) {
  var text = normalizeText(node.textContent || "");
  var attributes = ["href", "src", "data", "poster", "srcset", "alt", "title", "aria-label"].map(function(name) {
    var value = node.getAttribute && node.getAttribute(name);
    if (!value) return "";
    if (/^(?:href|src|data|poster)$/.test(name)) value = materializedHttpUrl(value) || value;
    return name + ":" + value;
  }).filter(Boolean);
  return node.tagName.toLowerCase() + "\u0000" + text + "\u0000" + attributes.join("\u0001");
}

function sourceOwnedPrimaryCandidateCovered(content, owner) {
  if (content.markdown) {
    var renderedMarkdown = markdownFor(content.html || "");
    if (normalizeText(content.markdown) !== normalizeText(renderedMarkdown)) return false;
  }
  var candidate = document.createElement("div");
  candidate.innerHTML = content.html || "";
  if (!candidate.firstElementChild ||
      (content.textContent && normalizeText(candidate.textContent || "") !== normalizeText(content.textContent))) return false;
  var selector = "h1, h2, h3, h4, h5, h6, p, li, blockquote, table, pre, code, figure, img, picture, source, " +
    "video, audio, iframe, object, embed, a[href], button, summary, details, input, select, textarea";
  var candidateNodes = Array.prototype.filter.call(candidate.querySelectorAll(selector), function(node) {
    var signature = sourceOwnedPrimaryMaterialSignature(node);
    return !!(normalizeText(node.textContent || "") || node.matches("input, select, textarea") ||
      /(?:href|src|data|poster|srcset):/.test(signature));
  });
  var sourceNodes = Array.prototype.filter.call(owner.querySelectorAll(selector), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipArticleChrome(node, owner);
  });
  var used = new Set();
  var previousIndex = -1;
  return candidateNodes.every(function(candidateNode) {
    var signature = sourceOwnedPrimaryMaterialSignature(candidateNode);
    var matches = sourceNodes.map(function(sourceNode, index) {
      return { node: sourceNode, index: index };
    }).filter(function(entry) {
      return sourceOwnedPrimaryMaterialSignature(entry.node) === signature;
    });
    var visibleMatch = matches.find(function(entry) {
      return !elementSubtreeHidden(entry.node) && !sourceOwnershipArticleChrome(entry.node, owner) &&
        !used.has(entry.node) && entry.index > previousIndex;
    });
    if (!visibleMatch) return false;
    used.add(visibleMatch.node);
    previousIndex = visibleMatch.index;
    return true;
  }) && sourceOwnedPrimarySelectedTextCovered(candidate, owner);
}

function sourceOwnedPrimarySelectedTextCovered(candidate, owner) {
  function textNodes(root) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    var result = [];
    for (var node = walker.nextNode(); node; node = walker.nextNode()) {
      if (node.parentElement && /^(?:SCRIPT|STYLE|NOSCRIPT|TEMPLATE)$/.test(node.parentElement.tagName)) continue;
      if (root === owner && (elementSubtreeHidden(node.parentElement) ||
          sourceOwnershipArticleChrome(node.parentElement, owner))) continue;
      var value = normalizeText(node.nodeValue || "");
      if (value) result.push(value);
    }
    return result;
  }
  var source = textNodes(owner);
  var selected = textNodes(candidate);
  var index = 0;
  return selected.every(function(value) {
    while (index < source.length && source[index] !== value) index += 1;
    if (index === source.length) return false;
    index += 1;
    return true;
  });
}
