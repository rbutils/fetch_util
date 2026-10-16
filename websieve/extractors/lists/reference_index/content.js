function datedReferenceInlineHeadings(root) {
  root.querySelectorAll("h1 > p, h2 > p, h3 > p, h4 > p, h5 > p, h6 > p").forEach(function(paragraph) {
    var heading = paragraph.parentElement;
    if (heading.children.length !== 1 || Array.from(heading.childNodes).some(function(node) {
      return node !== paragraph && node.nodeType === 3 && normalizeText(node.nodeValue || "");
    }) || paragraph.querySelector("p, div, section, article, header, footer, aside, nav, pre, table, ul, ol, dl, blockquote, h1, h2, h3, h4, h5, h6, br, hr")) return;
    var inline = paragraph.ownerDocument.createElement("span");
    Array.from(paragraph.attributes).forEach(function(attribute) {
      inline.setAttribute(attribute.name, attribute.value);
    });
    while (paragraph.firstChild) inline.appendChild(paragraph.firstChild);
    paragraph.replaceWith(inline);
  });
}

function datedReferenceIndexContent(metadata) {
  var context = datedReferenceIndexContext();
  if (!context) return null;
  return withInertDomWork(function() {
    var clone = visibilityPrunedClone(context.root, document);
    if (!clone) return null;
    var holder = document.createElement("div");
    holder.appendChild(clone);
    try {
      cleanDisposableClone(clone);
      cleanupAgentRoot(holder);
      materializeHttpAttributes(holder, false, false);
      var html = holder.innerHTML;
      datedReferenceInlineHeadings(holder);
      var markdown = markdownFromDisposableRoot(holder, false, true, true, turndownBlockUnits).trim();
      var content = listItemsContentResult(metadata, {
        title: context.title,
        excerpt: metadata.declaredDescription || metadata.excerpt,
        html: html,
        markdown: markdown,
        textContent: normalizeText(markdown)
      });
      content.sourceOwnedDatedReferenceIndex = true;
      return content;
    } finally { holder.replaceChildren(); }
  })();
}
