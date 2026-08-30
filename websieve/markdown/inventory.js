function browsableInventory(title, entries) {
  var seen = new Set();
  var lines = [];

  (entries || []).forEach(function(entry) {
    var url = materializedHttpUrl(entry && entry.url);
    var label = normalizeText(entry && entry.label);
    if (!url || !label || seen.has(url)) return;

    seen.add(url);
    var line = "- " + markdownLink(label, url);
    var detail = normalizeText(entry && entry.detail);
    if (detail) line += ": " + detail;
    lines.push(line);
  });

  return lines.length ? "## " + normalizeText(title) + "\n\n" + lines.join("\n") : "";
}
