  function stlMethodSummary(block) {
    if (!block) return null;

    var route = firstRootText(block, [
      "[class*='method-route']",
      "[class*='route-endpoint']",
      "code",
      "pre"
    ]);
    route = normalizeText(route).replace(/\s+/g, "");

    var title = firstRootText(block, [
      "h2",
      "h3",
      "h4",
      "strong",
      "[class*='method-name']",
      "[class*='method-title']",
      "[class*='summary-title']"
    ]);

    var text = normalizeText(block.textContent);
    if (!title) {
      title = text;
      if (route) title = normalizeText(title.replace(route, ""));
      title = title.replace(/\s{2,}/g, " ");
      title = title.split(/(?:(?:GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD)\/)/)[0].trim();
    }

    if (!title) return null;

    var detail = firstRootText(block, [
      "p",
      "[class*='description']",
      "[class*='summary-description']"
    ]);
    if (detail) {
      detail = compactReferenceText(normalizeText(detail));
      if (title && detail.indexOf(title) === 0) detail = normalizeText(detail.slice(title.length));
      if (route && detail.indexOf(route) === 0) detail = normalizeText(detail.slice(route.length));
    }

    var item = { text: title };
    if (route) item.route = route;
    if (detail) item.detail = detail;
    item.groups = stlMethodGroups(block);
    return item;
  }

  function stlSectionSummary(root) {
    var seen = {};
    var items = [];

    root.querySelectorAll("[class*='stldocs-method-summary'], [class*='method-summary']").forEach(function(block) {
      var item = stlMethodSummary(block);
      if (!item) return;

      var key = item.text + "|" + (item.route || "");
      if (seen[key]) return;
      seen[key] = true;
      items.push(item);
    });

    return items;
  }

  function stlMethodsMarkdown(items) {
    return items.map(function(item) {
      var line = "- " + item.text;
      if (item.route) line += " (" + item.route + ")";
      if (item.detail) line += ": " + item.detail;
      if (item.groups && item.groups.length) {
        item.groups.forEach(function(group) {
          line += "\n  - " + group.heading + "\n" + stlFieldsMarkdown(group.fields, "    ");
        });
      }
      return line;
    }).join("\n");
  }
