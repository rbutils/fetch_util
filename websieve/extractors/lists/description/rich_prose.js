  function listDescriptionRichInline(node) {
    if (node.nodeType === 3 || node.nodeType === 8) return true;
    if (node.nodeType !== 1) return false;
    if (listCardNodeHidden(node) || listNodeWithinClosedDisclosure(node)) return true;
    if (node.namespaceURI !== "http://www.w3.org/1999/xhtml" || listDescriptionListInterface(node)) return false;
    if (!node.matches("span, br, strong, b, em, i, u, s, del, small, sub, sup, abbr, mark, q, cite, " +
        "time, data, code, kbd, samp, a, img")) return false;
    if (node.matches("a[href]") && !materializedHttpUrl(node.getAttribute("href"))) return false;
    if (node.matches("img") && !materializedHttpUrl(node.getAttribute("src") ||
        node.getAttribute("data-src") || node.getAttribute("data-lazy-src") || "")) return false;
    return Array.from(node.childNodes).every(listDescriptionRichInline);
  }

  function listDescriptionRichProsePart(node) {
    if (!node.matches("p, div") || node.namespaceURI !== "http://www.w3.org/1999/xhtml" ||
        listDescriptionListInterface(node) ||
        !node.querySelector("strong, b, em, i, u, s, del, small, sub, sup, abbr, mark, q, cite, time, data, code, kbd, samp") ||
        !Array.from(node.childNodes).every(listDescriptionRichInline)) return null;
    var sourceClones = new Map();
    var clone = visibilityPrunedClone(node, document, sourceClones);
    restorePrunedNamedCodeTargets(node, sourceClones);
    var markdown = markdownFor(clone.outerHTML).trim();
    return markdown ? { node: node, markdown: markdown } : null;
  }
