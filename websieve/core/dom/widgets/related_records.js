function relatedHeadingRecordRail(block) {
  if (!block || !block.matches || !block.matches("div, section, aside")) return false;
  var directHeadings = Array.from(block.children).filter(function(child) {
    var text = normalizeText(child.textContent || "").replace(/[:：]\s*$/, "");
    return child.matches("h2, h3, h4") && RELATED_SECTION_HEADING_PATTERN.test(text);
  });
  if (directHeadings.length !== 1 || block.firstElementChild !== directHeadings[0]) return false;

  var records = Array.from(block.children).filter(function(child) { return child.matches("article"); });
  if (records.length < 3 || records.length !== block.children.length - 1) return false;
  var titles = new Set();
  return records.every(function(record) {
    if (record.querySelector("a[href], p, blockquote, img, picture, figure, video, audio, iframe, object, embed, ul, ol, dl, table, pre, code, form, input, button")) return false;
    var headings = record.querySelectorAll("h2, h3, h4");
    if (headings.length !== 1) return false;
    var title = normalizeText(headings[0].textContent || "");
    if (title.length < 8 || title.length > 220 || titles.has(title)) return false;
    titles.add(title);

    var remainder = record.cloneNode(true);
    var heading = remainder.querySelector("h2, h3, h4");
    if (heading) heading.remove();
    remainder.querySelectorAll("time").forEach(function(node) { node.remove(); });
    return !normalizeText(remainder.textContent || "");
  });
}
