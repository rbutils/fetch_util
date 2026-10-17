  function prepareDataTableMarkdown(root) {
    var attribute = "data-fetch-util-table";
    while ((root.hasAttribute && root.hasAttribute(attribute)) || root.querySelector("[" + attribute + "]")) {
      attribute += "-owned";
    }
    var tables = [];
    root.querySelectorAll("table").forEach(function(table) {
      // Nested tables can depend on converted child content or on the still
      // complete inner DOM. Leave both parent and child on their existing path.
      if (table.querySelector("table") || table.closest("pre, code")) return;
      if (table.parentElement && table.parentElement.closest("table")) return;
      var markdown = tableToMarkdown(table, "");
      table.setAttribute(attribute, String(tables.length));
      tables.push(markdown);
      // The existing TABLE rule owns every formatted row and reference. Its
      // discarded child conversion needs only a nonblank token, not every cell.
      table.textContent = "x";
    });
    return { attribute: attribute, tables: tables };
  }

  function preparedDataTableMarkdown(node, prepared) {
    if (!prepared) return null;
    var key = node.getAttribute(prepared.attribute);
    if (key === null || !Object.prototype.hasOwnProperty.call(prepared.tables, key)) return null;
    return prepared.tables[key];
  }
