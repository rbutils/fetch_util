  function tableIndexCells(row) {
    return Array.prototype.filter.call(row.children || [], function(cell) {
      return cell.matches && cell.matches("th, td");
    });
  }

  function tableIndexSpan(cell, propertyName, attributeName) {
    var value = parseInt(cell[propertyName] || cell.getAttribute(attributeName) || "1", 10);
    return value > 0 ? value : 1;
  }

  function tableIndexCellWidth(cells) {
    return cells.reduce(function(total, cell) {
      return total + tableIndexSpan(cell, "colSpan", "colspan");
    }, 0);
  }

  function tableIndexHeaders(table) {
    var rows = Array.prototype.filter.call(table.querySelectorAll("thead tr"), function(row) {
      var cells = tableIndexCells(row);
      return !elementVisuallyHidden(row) && cells.some(function(cell) { return cell.tagName === "TH"; });
    });
    if (!rows.length) {
      rows = Array.prototype.filter.call(table.querySelectorAll("tr"), function(row) {
        var cells = tableIndexCells(row);
        return !elementVisuallyHidden(row) && cells.length && cells.every(function(cell) { return cell.tagName === "TH"; });
      });
    }
    if (!rows.length) return [];

    var grid = [];
    rows.forEach(function(row, rowIndex) {
      if (!grid[rowIndex]) grid[rowIndex] = [];
      var columnIndex = 0;
      tableIndexCells(row).forEach(function(cell) {
        while (grid[rowIndex][columnIndex]) columnIndex += 1;
        var colSpan = tableIndexSpan(cell, "colSpan", "colspan");
        var rowSpan = tableIndexSpan(cell, "rowSpan", "rowspan");
        for (var gridRow = rowIndex; gridRow < rowIndex + rowSpan; gridRow += 1) {
          if (!grid[gridRow]) grid[gridRow] = [];
          for (var gridColumn = columnIndex; gridColumn < columnIndex + colSpan; gridColumn += 1) {
            grid[gridRow][gridColumn] = cell;
          }
        }
        columnIndex += colSpan;
      });
    });

    var width = grid.reduce(function(maximum, row) { return Math.max(maximum, row.length); }, 0);
    var labels = [];
    for (var column = 0; column < width; column += 1) {
      var parts = [];
      rows.forEach(function(_row, rowIndex) {
        var label = normalizeText(((grid[rowIndex] || [])[column] || {}).textContent || "");
        if (label && parts[parts.length - 1] !== label) parts.push(label);
      });
      labels.push(parts.join(" / "));
    }
    return labels.filter(Boolean).length >= 2 ? labels : [];
  }

  function tableIndexPrimaryLink(row, cells, minimumLength, onlyColumn) {
    var firstColumn = onlyColumn === undefined || onlyColumn === null ? 0 : onlyColumn;
    var lastColumn = onlyColumn === undefined || onlyColumn === null ? cells.length : onlyColumn + 1;
    for (var index = firstColumn; index < lastColumn; index += 1) {
      if (!cells[index]) continue;
      var links = Array.prototype.filter.call(cells[index].querySelectorAll("a[href]"), function(link) {
        var href = link.getAttribute("href") || "";
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        var requiredLength = minimumLength || minimumListTitleLength(text);
        return href && href[0] !== "#" && !/^(javascript:|mailto:)/i.test(href) && text.length >= requiredLength && text.length <= 220;
      });
      if (!links.length) continue;
      links.sort(function(a, b) {
        return normalizeText(b.textContent || "").length - normalizeText(a.textContent || "").length;
      });
      var url = absoluteUrl(links[0].getAttribute("href"));
      if (!url || listCanonicalKey(url) === currentListPageUrl()) continue;
      return { cellIndex: index, url: listCanonicalKey(url), link: links[0] };
    }
    return null;
  }

  function tableIndexColumnRole(label) {
    label = normalizeText(label || "").toLowerCase();
    if (/\b(?:actions?|controls?|logs?|status|state|details?|downloads?|view|open|edit|delete)\b/.test(label)) return 0;
    if (/\b(?:id|name|title|package|target|chroot|record|pollster|research|reference|entry|item|case|candidate|team|source)\b/.test(label)) return 2;
    return 1;
  }

  function tableIndexEvidence(table, headers) {
    var rows = Array.prototype.filter.call(table.querySelectorAll("tr"), function(row) {
      if (row.closest("table") !== table || row.closest("thead, tfoot") || elementVisuallyHidden(row)) return false;
      var cells = tableIndexCells(row);
      var text = normalizeText(row.textContent || "");
      return tableIndexCellWidth(cells) === headers.length && !row.querySelector("table") && text.length >= 8 && text.length <= 600;
    });
    if (rows.length < 6) return null;

    var linkColumns = {};
    rows.forEach(function(row) {
      var cells = tableIndexCells(row);
      cells.forEach(function(_cell, column) {
        var link = tableIndexPrimaryLink(row, cells, 2, column);
        if (!link) return;
        if (!linkColumns[column]) linkColumns[column] = [];
        linkColumns[column].push(link);
      });
    });

    var candidates = Object.keys(linkColumns).map(function(key) {
      var column = parseInt(key, 10);
      var links = linkColumns[key];
      var distinctUrls = {};
      links.forEach(function(link) { distinctUrls[link.url] = true; });
      return {
        column: column,
        count: links.length,
        distinctCount: Object.keys(distinctUrls).length,
        role: tableIndexColumnRole(headers[column])
      };
    }).filter(function(candidate) {
      return candidate.count >= 6 && (candidate.count / rows.length) >= 0.65 &&
        candidate.distinctCount >= 4 && (candidate.distinctCount / candidate.count) >= 0.6;
    }).sort(function(a, b) {
      return b.role - a.role || b.count - a.count || b.distinctCount - a.distinctCount || a.column - b.column;
    });

    return candidates.length && candidates[0].role > 0 ? { primaryColumn: candidates[0].column } : null;
  }

  function tableIndexPrimaryColumn(table) {
    if (!table) return null;
    var headers = tableIndexHeaders(table);
    var evidence = headers.length >= 3 ? tableIndexEvidence(table, headers) : null;
    return evidence && evidence.primaryColumn;
  }

  function tableIndexProseDominates(table) {
    var root = table.closest("article, main, [role='main']") || document.body;
    var paragraphs = Array.prototype.map.call(root.querySelectorAll("p"), function(paragraph) {
      return elementVisuallyHidden(paragraph) ? "" : normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 120; });
    if (paragraphs.length < 2) return false;

    var proseLength = paragraphs.join(" ").length;
    if (proseLength < 400) return false;
    if (root.tagName === "ARTICLE") return true;

    var tableLength = normalizeText(table.textContent || "").length;
    return proseLength >= 500 && proseLength >= tableLength * 0.75;
  }

  function linkedTableIndexRoot() {
    if (!document.body) return null;

    var longParagraphs = Array.prototype.map.call(document.querySelectorAll("p"), function(paragraph) {
      return elementVisuallyHidden(paragraph) ? "" : normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 180; });
    if (longParagraphs.length >= 3 && longParagraphs.join(" ").length >= 700) return null;

    return Array.prototype.find.call(document.querySelectorAll("table"), function(table) {
      if (elementVisuallyHidden(table) || table.querySelector("table")) return false;
      if (tableIndexProseDominates(table)) return false;

      var headers = tableIndexHeaders(table);
      if (headers.length < 3) return false;

      var pageContext = normalizeText([
        location.pathname,
        document.title,
        (document.querySelector("h1") || {}).textContent,
        (table.querySelector("caption") || {}).textContent
      ].join(" "));
      var headerContext = normalizeText(headers.join(" "));
      var context = normalizeText(pageContext + " " + headerContext);
      var indexContext = /(poll|survey|opinion|result|archive|history|tracker|record|ranking|standing|sonda|umfrag|sondag|sondeo|peiling|enqu[eê]te)/i.test(context);
      var buildContext = /\bbuilds?\b/i.test(pageContext) && /\b(?:builds?|status|state|chroots?|packages?|versions?|submitted|targets?|architectures?|platforms?|logs?)\b/i.test(headerContext);
      var monitorContext = /\bmonitor(?:ing)?\b/i.test(pageContext) && /\b(?:packages?|status|state|builds?|targets?|architectures?|chroots?|versions?|releases?|platforms?)\b/i.test(headerContext);
      var operationalContext = buildContext || monitorContext;
      if (!indexContext && !operationalContext) return false;

      return !!tableIndexEvidence(table, headers);
    }) || null;
  }

  function linkedTableIndexPage() {
    return !!linkedTableIndexRoot();
  }
