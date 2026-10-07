function articleCommentCountControl(node) {
  if (!node.matches("a[href]") || node.children.length || codeContentNode(node)) return false;
  if (articleWidgetTokens(node).indexOf("count") === -1 || !/^\d[\d\s,.]*$/.test(normalizeText(node.textContent || ""))) return false;
  var destination;
  try {
    destination = new URL(node.getAttribute("href"), location.href);
  } catch (_error) {
    return false;
  }
  if (!/^https?:$/.test(destination.protocol) || destination.username || destination.password) return false;
  if (!/(?:^|[./#_-])(?:comments?|replies|discussion)(?:[./#_-]|$)/i.test(destination.hostname + destination.pathname + destination.hash)) return false;
  var matches = Array.from(document.querySelectorAll("a[href]")).filter(function(source) {
    return !elementSubtreeHidden(source) && source.getAttribute("href") === node.getAttribute("href") &&
      source.getAttribute("class") === node.getAttribute("class") && normalizeText(source.textContent || "") === normalizeText(node.textContent || "");
  });
  if (matches.length !== 1) return false;
  var source = matches[0];
  if (source.closest("p, li, pre, code, blockquote, table, h1, h2, h3, h4, nav, aside, footer, [itemprop~='comment' i], .comment, .reply")) return false;
  for (var owner = source.parentElement; owner && owner !== document.body; owner = owner.parentElement) {
    var headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) { return !elementSubtreeHidden(heading); });
    if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== normalizeText(document.title || "")) continue;
    if (!sourceRecordBefore(headings[0], source)) return false;
    return Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
      return !elementSubtreeHidden(paragraph) && !sourceOwnershipInChrome(paragraph) &&
        normalizeText(paragraph.textContent || "") && sourceRecordBefore(source, paragraph);
    });
  }
  return false;
}
