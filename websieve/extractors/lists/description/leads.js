  function listDescriptionLeadInline(node) {
    if (node.nodeType === 3 || node.nodeType === 8) return true;
    if (node.nodeType !== 1) return false;
    if (listCardNodeHidden(node) || listNodeWithinClosedDisclosure(node)) return true;
    if (node.namespaceURI !== "http://www.w3.org/1999/xhtml" || listDescriptionListInterface(node)) return false;
    if (!node.matches("p, h1, h2, h3, h4, h5, h6, span, br, strong, b, em, i, u, s, del, small, sub, sup, " +
        "abbr, mark, q, cite, time, data, code, kbd, samp, a")) return false;
    if (node.matches("a[href]") && !materializedHttpUrl(node.getAttribute("href"))) return false;
    return Array.from(node.childNodes).every(listDescriptionLeadInline);
  }

  function listDescriptionLeadProse(node) {
    if (listCardNodeHidden(node) || listNodeWithinClosedDisclosure(node) || listDescriptionListInterface(node)) return false;
    if (node.tagName === "P") {
      var text = normalizeText(node.textContent || "");
      return text.length >= 30 && text.length <= 2000 && !listNoiseText(text) &&
        !cookieNoticeText(text) && !legalFooterText(text) && !weatherModuleText(text) && listDescriptionLeadInline(node);
    }
    if (node.tagName !== "DIV" || node.namespaceURI !== "http://www.w3.org/1999/xhtml") return false;
    var children = Array.from(node.childNodes).filter(function(child) {
      return child.nodeType !== 8 && !(child.nodeType === 3 && !normalizeText(child.nodeValue)) &&
        !(child.nodeType === 1 && listCardNodeHidden(child));
    });
    return children.length > 0 && children.every(function(child) {
      return child.nodeType === 1 && listDescriptionLeadProse(child);
    });
  }

  function listDescriptionLeadPart(lead, root, items) {
    if (lead.tagName !== "P" || !items || !items.length || !lead.closest("main, [role='main']") ||
        lead.closest("a, table, pre, code, kbd, samp, blockquote") || listDescriptionListInterface(lead)) return null;
    var text = normalizeText(lead.textContent || "");
    if (!text || text.length >= 30 || listNoiseText(text) || cookieNoticeText(text) ||
        legalFooterText(text) || weatherModuleText(text) || !listDescriptionLeadInline(lead)) return null;
    var owner = lead.parentElement;
    if (!owner || !owner.matches("section, article") || !root.contains(owner)) return null;
    if (items.some(function(item) {
      return (item.sourceOrderedRepeatedRecord || item.sourceOrderedStructuredCard || item.sourceOrderedHeadingCard) &&
        item.card && item.card.contains(lead);
    })) return null;
    var children = Array.from(owner.childNodes).filter(function(child) {
      return child.nodeType !== 8 && !(child.nodeType === 3 && !normalizeText(child.nodeValue)) &&
        !(child.nodeType === 1 && listCardNodeHidden(child));
    });
    var heading = children[0];
    if (children.length < 3 || children[1] !== lead || !heading || heading.nodeType !== 1 ||
        !/^H[1-6]$/.test(heading.tagName) || heading.querySelector("a[href]") ||
        !normalizeText(heading.textContent) || !listDescriptionLeadInline(heading) ||
        !children.slice(2).every(function(child) { return child.nodeType === 1 && listDescriptionLeadProse(child); })) return null;
    var links = lead.querySelectorAll("a[href]").length;
    if (links > 1 && (links / text.split(/\s+/).length) >= 0.3) return null;
    var sourceClones = new Map();
    var clone = visibilityPrunedClone(lead, document, sourceClones);
    restorePrunedNamedCodeTargets(lead, sourceClones);
    var markdown = markdownFor(clone.outerHTML).trim();
    return markdown ? { node: lead, markdown: markdown, descriptiveLead: true } : null;
  }
