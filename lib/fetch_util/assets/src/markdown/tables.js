  function escapeTableCell(text) {
    return normalizeText(text).replace(/\|/g, "\\|");
  }

  function compactTableMarkdown(table) {
    var headers = Array.prototype.map.call(table.querySelectorAll("thead th, thead td"), function(cell) {
      return normalizeText(cell.textContent).toLowerCase();
    });
    var caption = normalizeText((table.querySelector("caption") || {}).textContent).toLowerCase();
    var bodyRows = Array.prototype.slice.call(table.querySelectorAll("tbody tr"));

    if (!bodyRows.length) return null;

    if ((headers.length === 1 && /name, type, description/.test(headers[0])) || /parameter/.test(caption)) {
      var lines = bodyRows.map(function(row) {
        return compactParameterCell(row.querySelector("td, th"));
      }).filter(Boolean);
      return lines.length ? lines.join("\n") : null;
    }

    if (headers.length >= 2 && /status code/.test(headers[0]) && /description/.test(headers[1])) {
      var statusLines = bodyRows.map(function(row) {
        var cells = row.querySelectorAll("th, td");
        if (cells.length < 2) return null;
        var code = normalizeText(cells[0].textContent);
        var description = compactReferenceText(cells[1].textContent);
        if (!code || !description) return null;
        return "- `" + code + "`: " + description;
      }).filter(Boolean);
      return statusLines.length ? statusLines.join("\n") : null;
    }

    return null;
  }

  function tableToMarkdown(table) {
    var compact = compactTableMarkdown(table);
    if (compact) return compact;

    var rows = Array.prototype.map.call(table.querySelectorAll("tr"), function(row) {
      return Array.prototype.map.call(row.querySelectorAll("th, td"), function(cell) {
        return escapeTableCell(cell.textContent);
      });
    }).filter(function(row) {
      return row.length > 0;
    });

    if (!rows.length) return "";

    var width = rows.reduce(function(max, row) {
      return Math.max(max, row.length);
    }, 0);

    rows = rows.map(function(row) {
      while (row.length < width) row.push("");
      return row;
    });

    var header = rows[0];
    var separator = header.map(function() { return "---"; });
    var body = rows.slice(1);
    var markdownRows = [header, separator].concat(body).map(function(row) {
      return "| " + row.join(" | ") + " |";
    });

    return markdownRows.join("\n");
  }
