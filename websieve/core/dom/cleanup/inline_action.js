  function authoredInlineActionReference(node) {
    var paragraph = node.closest("p, li, dd, td, th");
    if (!paragraph || paragraph.querySelector("button, input, select, textarea, [role='button']")) return false;
    var link = node.matches("a[href]") ? node : null;
    if (!link && node.matches("span, strong, b, em, i")) {
      var links = node.querySelectorAll("a[href]");
      if (links.length === 1 && normalizeText(node.textContent) === normalizeText(links[0].textContent)) link = links[0];
      var enclosing = node.closest("a[href]");
      if (!link && enclosing && normalizeText(node.textContent) === normalizeText(enclosing.textContent)) link = enclosing;
    }
    if (!link) return false;
    if (!link.matches("a[href]") || !materializedHttpUrl(link.getAttribute("href")) ||
        link.closest("form, nav, button, [role='button'], [role='navigation'], [role='dialog']")) return false;
    var before = paragraph.ownerDocument.createRange();
    before.selectNodeContents(paragraph);
    before.setEndBefore(node);
    var after = paragraph.ownerDocument.createRange();
    after.selectNodeContents(paragraph);
    after.setStartAfter(node);
    return /\p{L}/u.test(before.toString()) && /\p{L}/u.test(after.toString());
  }
