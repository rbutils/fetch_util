  function structuredListTables(root) {
    return Array.from(root.querySelectorAll("table")).filter(function(table) {
      if (table.querySelector("table") || elementVisuallyHidden(table) || table.closest("nav, aside, [role='navigation']")) return false;
      var headers = tableIndexHeaders(table);
      return headers.length >= 3 && !!tableIndexEvidence(table, headers);
    });
  }

  function structuredListTableItems(table) {
    var primaryColumn = tableIndexPrimaryColumn(table);
    return tableIndexDataRows(table).map(function(dataRow) {
      var row = dataRow.row;
      if (row.closest("table") !== table || row.closest("thead, tfoot") || elementVisuallyHidden(row)) return null;
      var primary = tableIndexPrimaryLink(row, dataRow.cells, 2, primaryColumn, true);
      if (!primary) return null;
      var text = normalizeText(primary.link.textContent || primary.link.getAttribute("aria-label") || "");
      var detail = listTableRowDetail(row, text, dataRow.cells);
      var key = primary.url || "unlinked:" + text.toLowerCase() + "|href:" + primary.href;
      return {
        text: text, url: primary.url, detail: detail,
        rankScore: text.length + detail.length, card: row, sourceNode: row,
        tableCells: dataRow.cells, canonicalKey: key,
        dedupeKey: key + "|row:" + normalizeText(detail).toLowerCase()
      };
    }).filter(Boolean);
  }
