  var footerDataGroupNodes = new WeakSet();

  function ownedFooterDataGroups(root) {
    return Array.from(root.querySelectorAll("table")).map(function(table) {
      return table.parentElement;
    }).filter(function(group) { return footerDataGroupNodes.has(group); });
  }

  function footerKeyValueTable(table) {
    if (!table || table.closest("nav, form, button, pre, code, [role='navigation'], [role='menu']")) return false;
    if (table.querySelector("table, pre, ul, ol, input, button, select, textarea, img, video, audio, svg")) return false;
    var rows = Array.from(table.rows || []);
    if (!rows.length) return false;
    return rows.every(function(row) {
      var cells = Array.from(row.cells || []);
      if (cells.length !== 2) return false;
      var label = cells[0];
      var text = normalizeText(label.textContent || "");
      if (!text || label.querySelector("a[href]") || !normalizeText(cells[1].textContent || "")) return false;
      return /:$/.test(text) || (label.tagName === "TH" && label.getAttribute("scope") === "row");
    });
  }

  function atomicFooterDataGroup(table) {
    if (!footerKeyValueTable(table)) return null;
    var group = table.parentElement;
    if (!group || !group.matches("div, section")) return null;
    var children = Array.from(group.children);
    if (children.length !== 2 || children[1] !== table) return null;
    var label = children[0];
    if (!label.matches("span, p, strong, h1, h2, h3, h4, h5, h6") || !normalizeText(label.textContent || "")) return null;
    if (label.querySelector("a, table, pre, code, ul, ol, img, svg, input, button, select, textarea")) return null;
    if (Array.from(group.childNodes).some(function(node) {
      return node.nodeType === 3 && !!normalizeText(node.textContent || "");
    })) return null;
    if (group.closest("nav, form, button, details:not([open]), [role='navigation'], [role='menu']")) return null;
    return group;
  }

  function materializeFooterDataGroups(source, clone, elementMap) {
    var sources = Array.from(source.querySelectorAll("footer"));
    var copies = Array.from(clone.querySelectorAll("footer"));
    if (source.tagName === "FOOTER") sources.unshift(source);
    if (clone.tagName === "FOOTER") copies.unshift(clone);
    if (sources.length !== copies.length) return clone;
    sources.forEach(function(footer, index) {
      var copied = copies[index];
      if (articleOwnedFooter(copied) || !footer.querySelector("table") || copied.closest("a[href], nav, form, pre, code")) return;
      var visible = visibilityPrunedClone(footer, copied.ownerDocument, elementMap, true);
      var groups = Array.from(visible.querySelectorAll("table")).map(atomicFooterDataGroup).filter(Boolean);
      if (!groups.length) return;
      // Retain complete physical groups in order, without importing the
      // surrounding navigation or subscription interface from their footer.
      var replacement = copied.ownerDocument.createElement("div");
      groups.forEach(function(group) {
        footerDataGroupNodes.add(group);
        replacement.appendChild(group);
      });
      if (copied === clone) clone = replacement;
      else copied.replaceWith(replacement);
    });
    return clone;
  }
