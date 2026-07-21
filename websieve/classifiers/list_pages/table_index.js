  function tableIndexCells(row) {
    return Array.prototype.filter.call(row.children || [], function(cell) {
      return cell.matches && cell.matches("th, td");
    });
  }

  function tableIndexHeaders(table) {
    var rows = Array.prototype.filter.call(table.querySelectorAll("thead tr"), function(row) {
      return !elementVisuallyHidden(row) && tableIndexCells(row).length >= 3;
    });
    if (!rows.length) {
      rows = Array.prototype.filter.call(table.querySelectorAll("tr"), function(row) {
        var cells = tableIndexCells(row);
        return !elementVisuallyHidden(row) && cells.length >= 3 && cells.some(function(cell) { return cell.tagName === "TH"; });
      });
    }
    if (!rows.length) return [];

    var headers = tableIndexCells(rows[rows.length - 1]);
    var labels = headers.filter(function(cell) { return normalizeText(cell.textContent || ""); });
    return labels.length >= 2 ? headers : [];
  }

  function tableIndexPrimaryLink(row, cells) {
    for (var index = 0; index < cells.length; index += 1) {
      var links = Array.prototype.filter.call(cells[index].querySelectorAll("a[href]"), function(link) {
        var href = link.getAttribute("href") || "";
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return href && href[0] !== "#" && !/^(javascript:|mailto:)/i.test(href) && text.length >= minimumListTitleLength(text) && text.length <= 220;
      });
      if (!links.length) continue;
      links.sort(function(a, b) {
        return normalizeText(b.textContent || "").length - normalizeText(a.textContent || "").length;
      });
      var url = absoluteUrl(links[0].getAttribute("href"));
      if (!url || listCanonicalKey(url) === currentListPageUrl()) continue;
      return { cellIndex: index, url: listCanonicalKey(url) };
    }
    return null;
  }

  function linkedTableIndexRoot() {
    if (!document.body) return null;

    var longParagraphs = Array.prototype.map.call(document.querySelectorAll("p"), function(paragraph) {
      return elementVisuallyHidden(paragraph) ? "" : normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 180; });
    if (longParagraphs.length >= 3 && longParagraphs.join(" ").length >= 700) return null;

    return Array.prototype.find.call(document.querySelectorAll("table"), function(table) {
      if (elementVisuallyHidden(table) || table.querySelector("table")) return false;
      var headers = tableIndexHeaders(table);
      if (headers.length < 3) return false;

      var context = normalizeText([
        location.pathname,
        document.title,
        (document.querySelector("h1") || {}).textContent,
        (table.querySelector("caption") || {}).textContent,
        headers.map(function(cell) { return cell.textContent || ""; }).join(" ")
      ].join(" "));
      if (!/(poll|survey|opinion|result|archive|history|tracker|record|ranking|standing|sonda|umfrag|sondag|sondeo|peiling|enqu[eê]te)/i.test(context)) return false;

      var rows = Array.prototype.filter.call(table.querySelectorAll("tr"), function(row) {
        if (row.closest("table") !== table || row.closest("thead, tfoot") || elementVisuallyHidden(row)) return false;
        var cells = tableIndexCells(row);
        var text = normalizeText(row.textContent || "");
        return cells.length === headers.length && !row.querySelector("table") && text.length >= 8 && text.length <= 600;
      });
      if (rows.length < 6) return false;

      var linkedRows = rows.map(function(row) {
        return tableIndexPrimaryLink(row, tableIndexCells(row));
      }).filter(Boolean);
      if (linkedRows.length < 6 || (linkedRows.length / rows.length) < 0.65) return false;

      var distinctUrls = {};
      var linkColumns = {};
      linkedRows.forEach(function(link) {
        distinctUrls[link.url] = true;
        linkColumns[link.cellIndex] = (linkColumns[link.cellIndex] || 0) + 1;
      });
      var distinctCount = Object.keys(distinctUrls).length;
      var strongestColumn = Object.keys(linkColumns).reduce(function(best, key) {
        return Math.max(best, linkColumns[key]);
      }, 0);

      return distinctCount >= 4 && (distinctCount / linkedRows.length) >= 0.6 && (strongestColumn / linkedRows.length) >= 0.75;
    }) || null;
  }

  function linkedTableIndexPage() {
    return !!linkedTableIndexRoot();
  }
