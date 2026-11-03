  function listDescriptionListInterface(node) {
    var interfaces = "nav, header, footer, aside, menu, form, button, input, select, textarea, option, dialog, " +
      "script, style, template, iframe, [role='navigation'], [role='menu'], [role='menubar'], " +
      "[role='menuitem'], [role='menuitemcheckbox'], [role='menuitemradio'], [role='toolbar'], " +
      "[role='banner'], [role='contentinfo'], [role='button'], [role='tab'], [role='tablist'], " +
      "[role='tabpanel'], [role='dialog'], [role='alertdialog'], [role='checkbox'], [role='radio'], " +
      "[role='switch'], [role='listbox'], [role='option'], [role='combobox'], [role='tree'], " +
      "[role='treeitem'], [role='textbox'], [role='searchbox'], [role='slider'], [role='spinbutton'], " +
      "[role='scrollbar'], [role='tooltip'], [contenteditable]:not([contenteditable='false']), " +
      "[tabindex], [aria-controls], [aria-haspopup], [aria-expanded], [aria-modal='true']";
    if (node.closest(interfaces)) return true;
    for (var current = node; current; current = current.parentElement) {
      // The existing clone map preserves this exact negative source witness after sanitization.
      if (listImageCollectionEventOwners.has(current) || Array.from(current.attributes || []).some(function(attribute) {
        return /^on/i.test(attribute.name);
      })) return true;
      if (current.matches("main, [role='main']")) break;
    }
    return false;
  }

  function completeListDescriptionList(list) {
    function visit(node) {
      if (node.nodeType === 3 || node.nodeType === 8) return true;
      if (node.nodeType !== 1) return false;
      if (listCardNodeHidden(node) || listNodeWithinClosedDisclosure(node)) return true;
      if (node.namespaceURI !== "http://www.w3.org/1999/xhtml" || listDescriptionListInterface(node)) return false;
      if (!node.matches("ol, ul, li, p, div, span, br, strong, b, em, i, u, s, del, small, sub, sup, " +
          "abbr, mark, q, cite, time, data, code, pre, kbd, samp, a, img, h1, h2, h3, h4, h5, h6")) return false;
      if (node.matches("a[href]") && !materializedHttpUrl(node.getAttribute("href"))) return false;
      if (node.matches("img") && !materializedHttpUrl(node.getAttribute("src") || "")) return false;
      if (node.matches("li") && (!node.parentElement || !node.parentElement.matches("ol, ul"))) return false;
      if (node.matches("ol, ul")) {
        var items = Array.from(node.childNodes).filter(function(child) {
          return child.nodeType !== 8 && !(child.nodeType === 3 && !normalizeText(child.nodeValue)) &&
            !(child.nodeType === 1 && listCardNodeHidden(child));
        });
        if (!items.length || items.some(function(item) { return item.nodeType !== 1 || item.tagName !== "LI"; })) return false;
      }
      return Array.from(node.childNodes).every(visit);
    }
    return visit(list);
  }

  function listDescriptionListParts(root, items) {
    if (!items || !items.length) return [];
    var lists = Array.from(root.querySelectorAll("ol, ul"));
    if (root.matches("ol, ul")) lists.unshift(root);
    return lists.filter(function(list) {
      if (!list.closest("main, [role='main']") || listCardNodeHidden(list) || listNodeWithinClosedDisclosure(list) ||
          list.closest("a, table, pre, code, kbd, samp") || listDescriptionListInterface(list)) return false;
      if (list.parentElement && list.parentElement.closest("ol, ul")) return false;
      if (items.some(function(item) {
        return [item.card, item.contentCard, item.sourceNode].some(function(owner) {
          return owner && (owner.contains(list) || list.contains(owner));
        });
      })) return false;
      return completeListDescriptionList(list);
    }).map(function(list) {
      var sourceClones = new Map();
      var clone = visibilityPrunedClone(list, document, sourceClones);
      restorePrunedNamedCodeTargets(list, sourceClones);
      if (!normalizeText(clone.textContent)) return null;
      var markdown = markdownFor(clone.outerHTML).trim();
      return markdown ? { node: list, markdown: markdown, descriptiveList: true } : null;
    }).filter(Boolean);
  }
