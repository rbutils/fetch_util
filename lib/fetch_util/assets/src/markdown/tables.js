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

    if (table.querySelector("td[kind='field'][title], th[kind='field'][title]")) {
      var redocLines = bodyRows.map(function(row) {
        var nameCell = row.querySelector("td[kind='field'][title], th[kind='field'][title]");
        var cells = row.querySelectorAll("th, td");
        var detailCell = null;
        for (var i = 0; i < cells.length; i += 1) {
          if (cells[i] !== nameCell) {
            detailCell = cells[i];
            break;
          }
        }
        if (!nameCell || !detailCell) return null;

        var name = normalizeText(nameCell.getAttribute("title") || (nameCell.querySelector(".property-name") || {}).textContent || nameCell.textContent);
        if (!name) return null;

        var required = /\brequired\b/i.test(normalizeText(row.textContent));
        var metaParts = [];
        Array.prototype.forEach.call(detailCell.querySelectorAll(":scope > span, :scope > code, :scope > div, :scope > strong, :scope > em"), function(child) {
          if (child.querySelector("p, ul, ol, table, pre")) return;
          var text = normalizeText(child.textContent);
          if (!text || /^required$/i.test(text)) return;
          metaParts.push(text);
        });

        var description = Array.prototype.map.call(detailCell.querySelectorAll("p, li"), function(node) {
          return normalizeText(node.textContent);
        }).filter(Boolean).join(" ");

        var qualifiers = [];
        if (metaParts.length) qualifiers.push(metaParts.shift());
        metaParts.forEach(function(part) {
          if (/^(Default:|Example:|Enum:)/i.test(part)) qualifiers.push(part);
          else if (!description) description = part;
          else description += " " + part;
        });
        if (required) qualifiers.push("required");

        var line = "- `" + name + "`";
        if (qualifiers.length) line += " (" + qualifiers.join("; ") + ")";
        if (description) line += ": " + description;
        return line;
      }).filter(Boolean);

      return redocLines.length ? redocLines.join("\n") : null;
    }

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

  function tableToMarkdown(table, content) {
    var compact = compactTableMarkdown(table);
    if (compact) return compact;

    if (table.querySelector("table") && !table.querySelector("th, caption")) {
      return String(content || "").trim();
    }

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
