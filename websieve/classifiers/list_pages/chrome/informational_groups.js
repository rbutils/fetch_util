  function listInformationInterfaceSelector() {
    return "nav, header, footer, menu, form, button, input, select, textarea, [onclick], [aria-controls], [aria-expanded], [aria-haspopup], [contenteditable]:not([contenteditable='false']), [role='navigation'], [role='menubar'], [role='menu'], [role='menuitem'], [role='toolbar'], [role='banner'], [role='contentinfo'], [role='dialog'], [role='button']";
  }

  function listInformationParagraph(node) {
    var walker = node.ownerDocument.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var text = walker.currentNode;
      if (normalizeText(text.nodeValue || "") && !text.parentElement.closest("a")) return true;
    }
    return false;
  }

  function listInformationSection(node) {
    if (!node.matches("div, section") || listCardNodeHidden(node)) return false;
    var headings = [], paragraphs = [];
    var complete = Array.prototype.every.call(node.childNodes, function(child) {
      if (child.nodeType === 3) return !normalizeText(child.nodeValue || "");
      if (child.nodeType === 8) return true;
      if (child.nodeType !== 1 || listCardNodeHidden(child)) return false;
      if (child.matches("h2, h3, h4, h5, h6")) {
        if (child.querySelector("a[href]") || !normalizeText(child.textContent || "")) return false;
        headings.push(child);
        return true;
      }
      if (!child.matches("p")) return false;
      paragraphs.push(child);
      return true;
    });
    return complete && headings.length > 0 && paragraphs.some(listInformationParagraph);
  }

  function listInformationReferenceOwner(node) {
    if (!node.matches("div, section, article, li") || listCardNodeHidden(node) ||
        node.matches("[role='main'], article.type-page, [itemtype$='/WebPage']") ||
        node.querySelector(listInformationInterfaceSelector() + ", pre, table, ul, ol, details:not([open])")) return false;
    var sections = Array.prototype.filter.call(node.children, listInformationSection);
    if (sections.length < 2) return false;
    var bounded = Array.prototype.every.call(node.children, function(child) {
      if (sections.indexOf(child) >= 0) return true;
      return child.matches("div, section, p, a[href], span") &&
        !child.querySelector("h1, h2, h3, h4, h5, h6");
    });
    if (!bounded) return false;
    return Array.prototype.some.call(node.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      return !sections.some(function(section) { return section.contains(link); }) &&
        !listCardNodeHidden(link) && href.trim().charAt(0) !== "#" &&
        !!materializedHttpUrl(href) && !!normalizeText(link.textContent || "");
    });
  }

  function listInformationalChromeOwner(node) {
    if (!node || !node.closest || node.closest(listInformationInterfaceSelector() +
        ", pre, code, samp, kbd, details:not([open])")) return null;
    var current = node;
    while (current && !current.matches("body, html, main, [role='main']")) {
      if (listInformationReferenceOwner(current)) return current;
      current = current.parentElement;
    }
    return null;
  }
