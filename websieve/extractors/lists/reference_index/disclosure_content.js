function disclosureCatalogTransferReferences(root) {
  root.querySelectorAll("a[href]").forEach(function(link) {
    var url;
    try { url = new URL(link.getAttribute("href"), document.baseURI); } catch (_error) { return; }
    if (url.protocol !== "ftp:" || !url.hostname || url.username || url.password) return;
    var span = link.ownerDocument.createElement("span");
    ["id", "name", "title", "class", "lang", "dir"].forEach(function(attribute) {
      if (link.hasAttribute(attribute)) span.setAttribute(attribute, link.getAttribute(attribute));
    });
    while (link.firstChild) span.appendChild(link.firstChild);
    if (normalizeText(span.textContent || "") !== url.href) {
      var code = link.ownerDocument.createElement("code");
      code.textContent = url.href;
      span.appendChild(link.ownerDocument.createTextNode(" ("));
      span.appendChild(code);
      span.appendChild(link.ownerDocument.createTextNode(")"));
    }
    link.replaceWith(span);
  });
}

function disclosureCatalogContent(metadata) {
  var context = disclosureCatalogContext();
  if (!context) return null;
  var paragraph = Array.from(context.root.querySelectorAll("p")).find(function(node) {
    return normalizeText(node.textContent || "") && !elementVisuallyHidden(node);
  });
  var excerpt = paragraph ? normalizeText(paragraph.textContent || "") : null;
  return withInertDomWork(function() {
    var clone = visibilityPrunedClone(context.root, document);
    if (!clone) return null;
    var holder = document.createElement("div");
    holder.appendChild(clone);
    try {
      (context.trailingResources || []).forEach(function(source) {
        var resource = visibilityPrunedClone(source, document);
        if (resource) holder.appendChild(resource);
      });
      if (context.nativeRecordDisclosures) retainNativeDisclosureState(holder);
      holder.querySelectorAll("script, style, noscript, template").forEach(function(node) { node.remove(); });
      holder.querySelectorAll("button").forEach(function(button) {
        var span = button.ownerDocument.createElement("span");
        ["id", "name", "title", "class", "lang", "dir", "aria-label", "aria-labelledby"].forEach(function(attribute) {
          if (button.hasAttribute(attribute)) span.setAttribute(attribute, button.getAttribute(attribute));
        });
        while (button.firstChild) span.appendChild(button.firstChild);
        button.replaceWith(span);
      });
      disclosureCatalogTransferReferences(holder);
      materializeHttpAttributes(holder, false, false);
      var html = holder.innerHTML;
      var markdown = markdownFromDisposableRoot(holder, false, true, true, turndownBlockUnits).trim();
      var content = listItemsContentResult(metadata, {
        title: context.title, excerpt: excerpt, html: html, markdown: markdown, textContent: normalizeText(markdown)
      });
      content.sourceOwnedDisclosureCatalog = true;
      content.sourceOwnedDisclosureCatalogHtml = html;
      return content;
    } finally { holder.replaceChildren(); }
  })();
}
