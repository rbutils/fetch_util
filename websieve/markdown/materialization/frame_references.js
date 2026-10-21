function markdownFrameReferences(root) {
  return Array.prototype.map.call(root.querySelectorAll("iframe[src]"), function(frame) {
    if (frame.hasAttribute("srcdoc") || frame.closest("pre, code, kbd, samp, script, style, noscript, template") ||
        markdownVideoPosterHidden(frame, root)) return null;
    var url = materializedHttpUrl(frame.getAttribute("src"));
    if (!url) return null;
    return {
      node: frame,
      url: url,
      label: normalizeText(frame.getAttribute("aria-label") || frame.getAttribute("title")) || "Embedded content"
    };
  }).filter(Boolean);
}

function materializeMarkdownFrameReferences(root, references) {
  references.forEach(function(reference) {
    if (!root.contains(reference.node)) return;
    var paragraph = reference.node.ownerDocument.createElement("p");
    var link = reference.node.ownerDocument.createElement("a");
    link.setAttribute("href", reference.url);
    link.textContent = reference.label;
    paragraph.appendChild(link);
    reference.node.replaceWith(paragraph);
  });
}
