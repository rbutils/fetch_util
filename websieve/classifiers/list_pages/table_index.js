  function tableIndexPrimaryLink(row, cells, minimumLength, onlyColumn, retainUnsafeLink) {
    var firstColumn = onlyColumn === undefined || onlyColumn === null ? 0 : onlyColumn;
    var lastColumn = onlyColumn === undefined || onlyColumn === null ? cells.length : onlyColumn + 1;
    for (var index = firstColumn; index < lastColumn; index += 1) {
      if (!cells[index]) continue;
      var links = Array.prototype.filter.call(cells[index].querySelectorAll("a[href]"), function(link) {
        var href = link.getAttribute("href") || "";
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        var requiredLength = minimumLength || minimumListTitleLength(text);
        return href && href[0] !== "#" && text.length >= requiredLength && text.length <= 220;
      });
      if (!links.length) continue;
      links.sort(function(a, b) {
        var safeDifference = Number(!!materializedHttpUrl(b.getAttribute("href"))) - Number(!!materializedHttpUrl(a.getAttribute("href")));
        return safeDifference || normalizeText(b.textContent || "").length - normalizeText(a.textContent || "").length;
      });
      for (var linkIndex = 0; linkIndex < links.length; linkIndex += 1) {
        var url = materializedHttpUrl(links[linkIndex].getAttribute("href"));
        if (!url && !retainUnsafeLink) continue;
        if (url && listCanonicalKey(url) === currentListPageUrl()) continue;
        return { cellIndex: index, url: url ? listCanonicalKey(url) : null, href: links[linkIndex].getAttribute("href") || "", link: links[linkIndex] };
      }
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
    var rows = tableIndexDataRows(table).filter(function(dataRow) {
      var row = dataRow.row;
      if (row.closest("table") !== table || row.closest("thead, tfoot") || elementVisuallyHidden(row)) return false;
      var text = normalizeText(row.textContent || "");
      return dataRow.cells.length === headers.length &&
        dataRow.cells.filter(function(cell) { return !!cell; }).length === headers.length &&
        !row.querySelector("table") && text.length >= 8 && text.length <= 600;
    });
    if (rows.length < 6) return null;

    var linkColumns = {};
    rows.forEach(function(dataRow) {
      dataRow.cells.forEach(function(cell, column) {
        if (column > 0 && dataRow.cells[column - 1] === cell) return;
        var link = tableIndexPrimaryLink(dataRow.row, dataRow.cells, 2, column);
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
