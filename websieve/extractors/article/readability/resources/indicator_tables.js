  function readabilityMappedIndicatorTable(source, clone, sourceClones) {
    var rows = Array.from(source.rows);
    if (!rows.length || rows.length !== clone.rows.length) return false;
    var data = false;
    return rows.every(function(row, index) {
      var retained = clone.rows[index];
      var cells = Array.from(row.cells);
      if (sourceClones.get(row) !== retained || cells.length !== 2 || retained.cells.length !== 2) return false;
      if (index === 0 && cells.every(function(cell) { return cell.localName === "th" && !!normalizeText(cell.textContent); })) return true;
      if (!cells.every(function(cell) { return cell.localName === "td" && cell.rowSpan === 1 && cell.colSpan === 1; }) ||
          !normalizeText(cells[0].textContent) || elementSubtreeHidden(cells[0]) || elementSubtreeHidden(cells[1])) return false;
      if (cells[0].querySelector("table, pre, code, img, picture, svg, button, input, select, textarea, [role='button']")) return false;
      if (!Array.from(cells[0].querySelectorAll("a[href]")).every(function(link) {
        return !!materializedHttpUrl(link.getAttribute("href"));
      })) return false;
      var indicator = tableCellOpaqueIndicator(cells[1]);
      var mapped = tableCellOpaqueIndicator(retained.cells[1]);
      if (!indicator || !mapped || sourceClones.get(indicator) !== mapped || elementSubtreeHidden(indicator) ||
          indicator.attributes.length !== mapped.attributes.length) return false;
      data = true;
      return Array.from(indicator.attributes).every(function(attribute) {
        return mapped.getAttribute(attribute.name) === attribute.value;
      });
    }) && data;
  }

  function readabilityIndicatorTableSnapshots(root, selected, sourceClones) {
    var attribute = "data-fetchutil-reader-indicator-table";
    while (root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var tables = new Map();
    selected.forEach(function(entry) {
      if (!readabilityMappedIndicatorTable(entry.source, entry.clone, sourceClones)) return;
      var key = String(tables.size);
      tables.set(key, entry.clone.outerHTML);
      entry.clone.setAttribute(attribute, key);
    });
    return { attribute: attribute, tables: tables };
  }

  function restoreReadabilityIndicatorTables(html, snapshots) {
    if (!snapshots.tables.size) return html;
    var template = document.createElement("template");
    template.innerHTML = html;
    snapshots.tables.forEach(function(value, key) {
      var matches = template.content.querySelectorAll("table[" + snapshots.attribute + "='" + key + "']");
      if (matches.length !== 1) return;
      var source = document.createElement("template");
      source.innerHTML = value;
      matches[0].replaceWith(source.content);
    });
    template.content.querySelectorAll("[" + snapshots.attribute + "]").forEach(function(node) {
      node.removeAttribute(snapshots.attribute);
    });
    return template.innerHTML;
  }
