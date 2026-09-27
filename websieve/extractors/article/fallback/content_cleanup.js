function fallbackFocalArticleRoot(root) {
  var heading = root && root.querySelector && root.querySelector("h1, h2, [itemprop='headline']");
  var title = normalizeText((heading && heading.textContent) || "");
  var body = root && root.querySelectorAll ? Array.prototype.filter.call(root.querySelectorAll("p, [itemprop='articleBody']"), function(node) {
    return !node.closest("#comments, .comments, .comment-list, [class*='comment' i], [id*='comment' i]");
  }).map(function(node) { return normalizeText(node.textContent); }).join(" ") : "";
  return !!title && body.length >= 40;
}

function prepareFallbackInlineProse(root) {
  root.querySelectorAll("p span, li span, blockquote span, p font, li font, blockquote font").forEach(function(node) {
    if (node.querySelector("p, li, blockquote, div, ul, ol, table, pre")) return;
    node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
  });
}

function cleanupFallbackArticleChrome(root) {
  var chromeSelector = [".comment-thread", "[class*='comment-thread' i]", ".widget",
    "[class^='widget-' i]", "[class*=' widget-' i]", ".views-element-container",
    "[class~='comment']", ".date-header"].join(", ");
  root.querySelectorAll(chromeSelector).forEach(function(node) {
    if (node.matches("figcaption, caption")) return;
    var text = normalizeText(node.textContent || "");
    if (!text || text.length < 100 || !node.querySelector("p, article, section, ul, ol, table")) node.remove();
  });
}
