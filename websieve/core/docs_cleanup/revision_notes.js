function authoredRevisionNoteContext(node) {
  if (!node.closest("main, article, [role='main']") ||
      node.closest("table, blockquote, details:not([open])")) return false;
  for (var current = node; current; current = current.parentElement) {
    if (current.matches("form, nav, header, aside, button, input, select, textarea") ||
        current.hasAttribute("tabindex") || current.hasAttribute("contenteditable")) return false;
    var role = (current.getAttribute("role") || "").toLowerCase();
    if (role && !/^(main|article|document|note|presentation|none)$/.test(role)) return false;
    if (Array.from(current.attributes).some(function(attribute) { return /^on/i.test(attribute.name); })) return false;
  }
  return !elementSubtreeHidden(node);
}

function authoredRevisionNoteInline(node, root) {
  if (node.nodeType === 3 || node.nodeType === 8) return true;
  if (node.nodeType !== 1 || node.namespaceURI !== "http://www.w3.org/1999/xhtml" ||
      elementSubtreeHidden(node)) return false;
  if (node !== root && !node.matches("span, a, br, strong, b, em, i, u, s, del, small, sub, sup, " +
      "abbr, mark, q, cite, time, data, code, kbd, samp")) return false;
  if (!authoredRevisionNoteContext(node)) return false;
  if (node.matches("a[href]") && !materializedHttpUrl(node.getAttribute("href"))) return false;
  return Array.from(node.childNodes).every(function(child) { return authoredRevisionNoteInline(child, root); });
}

function authoredRevisionNoteMarkdowns() {
  var candidates = Array.from(document.querySelectorAll("main p, main div, main span, article p, article div, article span, " +
    "[role='main'] p, [role='main'] div, [role='main'] span")).filter(function(node) {
    return /^last modified\s+(?:[a-z]+\s+\d{1,2},\s+\d{4}|\d{4}-\d{2}-\d{2})\b/i.test(normalizeText(node.textContent || "")) &&
      !node.closest("pre, code, kbd, samp") &&
      authoredRevisionNoteContext(node) && authoredRevisionNoteInline(node, node);
  });
  // Nested wrappers describe one physical note, not another equal occurrence.
  return candidates.filter(function(node) {
    return !candidates.some(function(other) { return other !== node && other.contains(node); });
  }).map(function(node) {
    return markdownFor(node.outerHTML, false, false, true).trim();
  }).filter(Boolean);
}

function authoredRevisionNoteMatches(node, markdowns) {
  return markdowns.indexOf(markdownFor(node.outerHTML, false, false, true).trim()) >= 0;
}

function authoredRevisionMarkdownCleanup(markdown) {
  var pattern = /^[ \t]*Last modified\s+\w+\s+\d{1,2},\s+\d{4}[^\n]*$/gmi;
  if (!pattern.test(markdown)) return markdown;
  pattern.lastIndex = 0;
  var remaining = [];
  authoredRevisionNoteMarkdowns().forEach(function(note) {
    note.split("\n").forEach(function(line) { remaining.push(line.trim()); });
  });
  return markdown.replace(pattern, function(line) {
    var index = remaining.indexOf(line.trim());
    if (index < 0) return "";
    remaining.splice(index, 1);
    return line;
  });
}
