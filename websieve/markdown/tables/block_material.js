  function tableHasUnrepresentableCellRoles(table) {
    var rows = Array.from(table.querySelectorAll("tr")).filter(function(row) {
      return row.closest("table") === table;
    });
    var columns = null;
    return rows.some(function(row, index) {
      var cells = Array.from(row.children).filter(function(cell) { return cell.matches("th, td"); });
      if (!cells.length) return true;
      if (columns === null) columns = cells.length;
      if (cells.length !== columns) return true;
      var headers = cells.filter(function(cell) { return cell.tagName === "TH"; }).length;
      if (index > 0 && headers) return true;
      if (index === 0 && headers && headers !== cells.length) return true;
      if (index === 0 && !headers && row.parentElement.tagName === "THEAD") return true;
      return cells.some(function(cell) { return cell.matches("th[scope='row'], th[scope='rowgroup']"); });
    });
  }

  function tableRequiresBlockMaterial(table) {
    if (tableHasUnrepresentableCellRoles(table)) return true;
    return Array.from(table.querySelectorAll("th, td")).some(function(cell) {
      if (cell.matches("[rowspan], [colspan]")) return true;
      if (cell.querySelector("ul, ol, dl, blockquote, pre, table, h1, h2, h3, h4, h5, h6, hr, details, figure, br")) return true;
      return cell.querySelectorAll("p").length > 1;
    });
  }

  function generatedTableLabelKey(paragraph, allowFootnoteLinks) {
    if (!paragraph || paragraph.tagName !== "P" || paragraph.attributes.length) return null;
    var clone = paragraph.cloneNode(true);
    var unsupported = Array.from(clone.querySelectorAll("*")).some(function(node) {
      if (node.matches("sup, superscript")) return node.attributes.length || node.parentElement !== clone;
      return !allowFootnoteLinks || node.tagName !== "A" || !node.parentElement.matches("sup, superscript");
    });
    if (unsupported) return null;
    var notesStarted = false;
    var trailingNotes = Array.from(clone.childNodes).every(function(node) {
      if (node.nodeType === Node.ELEMENT_NODE && node.matches("sup, superscript")) {
        notesStarted = true;
        return true;
      }
      return !notesStarted || !normalizeText(node.textContent);
    });
    if (!trailingNotes) return null;
    var notes = [];
    var validNotes = Array.from(clone.querySelectorAll("sup, superscript")).every(function(note) {
      var text = normalizeText(note.textContent).replace(/\s*,\s*/g, ",");
      if (!/^\d+(?:,\d+)*$/.test(text)) return false;
      notes.push(text);
      note.remove();
      return true;
    });
    var label = normalizeText(clone.textContent);
    return validNotes && label ? JSON.stringify([label, notes]) : null;
  }

  function generatedTableLeadingParagraph(root) {
    var paragraph = root.firstElementChild;
    if (!paragraph || paragraph.tagName !== "P") return null;
    for (var previous = paragraph.previousSibling; previous; previous = previous.previousSibling) {
      if (normalizeText(previous.textContent)) return null;
    }
    return paragraph;
  }

  function removeGeneratedTableLabelCopies(table) {
    var ownerIds = new WeakMap();
    table.querySelectorAll("td, th").forEach(function(cell) {
      var owner = cell.closest("table");
      if (!owner || !/(?:^|_)ctl\d+(?:_|$)/.test(owner.id)) return;
      var label = generatedTableLeadingParagraph(cell);
      var body = label && label.nextElementSibling;
      var prefix = owner.id + "_ctl";
      if (!body || body.tagName !== "DIV" || body.id.indexOf(prefix) !== 0) return;
      if (!/^\d+_.+$/.test(body.id.slice(prefix.length))) return;
      for (var between = label.nextSibling; between && between !== body; between = between.nextSibling) {
        if (normalizeText(between.textContent)) return;
      }
      var copy = generatedTableLeadingParagraph(body);
      var key = generatedTableLabelKey(label, true);
      if (!key || key !== generatedTableLabelKey(copy, false)) return;
      if (!ownerIds.has(owner)) {
        var counts = new Map();
        owner.querySelectorAll("[id]").forEach(function(node) {
          counts.set(node.id, (counts.get(node.id) || 0) + 1);
        });
        ownerIds.set(owner, counts);
      }
      if (ownerIds.get(owner).get(body.id) !== 1) return;
      copy.remove();
    });
  }

  function blockMaterialTableHtml(table, allowArticleMailto) {
    var clone = table.cloneNode(true);
    var walker = document.createTreeWalker(clone, NodeFilter.SHOW_COMMENT);
    var comments = [];
    var comment;
    while ((comment = walker.nextNode())) comments.push(comment);
    // Serialized comment markup must never become active table material later.
    comments.forEach(function(node) { node.remove(); });
    removeGeneratedTableLabelCopies(clone);
    var holder = document.createElement("div");
    holder.appendChild(clone);
    materializeHttpAttributes(holder, false, allowArticleMailto !== false);
    return singleBlockMaterializedHtml(sanitizedHtml(clone.outerHTML));
  }

  function prepareBlockMaterialTables(root, allowArticleMailto) {
    var attribute = "data-fetch-util-table-block";
    while (root.hasAttribute(attribute) || root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var prefix = "FETCHUTILTABLEBLOCK";
    while (root.innerHTML.indexOf(prefix) !== -1) prefix += "OWNED";
    var tables = [];
    root.querySelectorAll("table").forEach(function(table) {
      if (table.parentElement && table.parentElement.closest("table, pre, code")) return;
      if (!tableRequiresBlockMaterial(table)) return;
      tables.push(blockMaterialTableHtml(table, allowArticleMailto));
      table.setAttribute(attribute, String(tables.length - 1));
      // The complete snapshot owns every descendant; discarded vendor traversal
      // must not normalize literal programs or flatten the original cell roles.
      table.textContent = "x";
    });
    return { attribute: attribute, prefix: prefix, tables: tables };
  }

  function blockMaterialTableToken(node, prepared) {
    var key = node.getAttribute(prepared.attribute);
    if (key === null) return null;
    if (!Object.prototype.hasOwnProperty.call(prepared.tables, key)) throw new Error("Missing complete table snapshot");
    return prepared.prefix + key + "END";
  }

  function restoreBlockMaterialTables(markdown, prepared) {
    return markdown.replace(new RegExp(prepared.prefix + "([0-9]+)END", "g"), function(_match, key) {
      if (!Object.prototype.hasOwnProperty.call(prepared.tables, key)) throw new Error("Missing rendered table snapshot");
      return prepared.tables[key];
    });
  }
