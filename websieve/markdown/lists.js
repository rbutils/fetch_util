function listMarkdown(items) {
  return items.map(function(item) {
    var line = item.url ? "- [" + item.text + "](" + item.url + ")" : "- " + item.text;
    var context = [item.category, item.summary, item.time, item.image, item.caption].filter(Boolean).join(" - ");
    if (context) line += " - " + context;
    else if (item.detail) line += " - " + item.detail;
    return line;
  }).join("\n");
}
