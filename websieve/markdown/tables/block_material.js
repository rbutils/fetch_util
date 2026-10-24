  function tableRequiresBlockMaterial(table) {
    return Array.from(table.querySelectorAll("th, td")).some(function(cell) {
      if (cell.matches("[rowspan], [colspan]")) return true;
      if (cell.querySelector("ul, ol, dl, blockquote, pre, table, h1, h2, h3, h4, h5, h6, hr, details, figure, br")) return true;
      return cell.querySelectorAll("p").length > 1;
    });
  }

  function blockMaterialTableHtml(table) {
    var clone = table.cloneNode(true);
    var walker = document.createTreeWalker(clone, NodeFilter.SHOW_COMMENT);
    var comments = [];
    var comment;
    while ((comment = walker.nextNode())) comments.push(comment);
    // Serialized comment markup must never become active table material later.
    comments.forEach(function(node) { node.remove(); });
    return singleBlockMaterializedHtml(sanitizedHtml(clone.outerHTML));
  }

  function prepareBlockMaterialTables(root) {
    var attribute = "data-fetch-util-table-block";
    while (root.hasAttribute(attribute) || root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var prefix = "FETCHUTILTABLEBLOCK";
    while (root.innerHTML.indexOf(prefix) !== -1) prefix += "OWNED";
    var tables = [];
    root.querySelectorAll("table").forEach(function(table) {
      if (table.parentElement && table.parentElement.closest("table, pre, code")) return;
      if (!tableRequiresBlockMaterial(table)) return;
      tables.push(blockMaterialTableHtml(table));
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
