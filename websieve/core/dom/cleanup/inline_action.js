  function sectionActionReferenceLink(node) {
    var link = node.matches("a[href]") ? node : null;
    if (!link && node.matches("p") && node.children.length === 1 &&
        node.firstElementChild.matches("a[href]") &&
        normalizeText(node.textContent) === normalizeText(node.firstElementChild.textContent)) link = node.firstElementChild;
    if (!link || !materializedHttpUrl(link.getAttribute("href")) ||
        link.matches("[aria-controls], [aria-expanded], [aria-haspopup]") ||
        link.querySelector("button, input, select, textarea, [role='button']") ||
        link.closest("form, nav, button, [role='button'], [role='navigation'], [role='dialog'], [role='toolbar'], [hidden], [aria-hidden='true']")) return null;
    return link;
  }

  function authoredSectionActionReference(node) {
    var link = node.matches("a[href]") ? node : node.closest("a[href]");
    if (!link || normalizeText(node.textContent) !== normalizeText(link.textContent)) return false;
    if (sectionActionReferenceLink(link) !== link) return false;

    var resource = sectionActionReferenceLink(link.parentElement) === link ? link.parentElement : link;
    var group = resource.parentElement;
    if (!group || !group.matches("div, header")) return false;
    var children = Array.from(group.children);
    var headings = children.filter(function(child) { return child.matches("h1, h2, h3, h4, h5, h6"); });
    if (headings.length !== 1 || !normalizeText(headings[0].textContent)) return false;
    if (headings[0].querySelector("button, input, select, textarea, [role='button']")) return false;
    if (!children.every(function(child) {
      return child === headings[0] || !!sectionActionReferenceLink(child);
    })) return false;
    if (Array.from(group.childNodes).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && normalizeText(child.textContent);
    })) return false;

    var section = group.parentElement;
    if (!section || !section.matches("section, article, main, div") || section.querySelector("form")) return false;
    var material = "h1, h2, h3, h4, h5, h6, p, ul, ol, dl, table, pre, blockquote, figure, img, picture, svg text, video, audio";
    return Array.from(section.children).some(function(sibling) {
      if (sibling === group || sibling.matches("nav, form, [role='navigation'], [role='toolbar'], [hidden], [aria-hidden='true']")) return false;
      return sibling.matches(material) || !!sibling.querySelector(material);
    });
  }

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
