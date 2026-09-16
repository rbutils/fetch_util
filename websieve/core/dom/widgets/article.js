function articleWidgetTokens(node) {
  var signature = [
    node.getAttribute("id"),
    node.getAttribute("class"),
    node.getAttribute("data-component"),
    node.getAttribute("data-testid"),
    node.getAttribute("data-role"),
    node.getAttribute("role"),
    node.getAttribute("aria-label")
  ].filter(Boolean).join(" ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();

  return signature.split(/[^a-z0-9]+/).filter(Boolean);
}

function articleAudioControlNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;

  var tokens = articleWidgetTokens(node);
  if (tokens.indexOf("audio") === -1) return false;
  var controls = tokens.some(function(token) {
    return /^(?:control|controls|player|toolbar)$/.test(token);
  }) || (tokens.indexOf("label") !== -1 && tokens.indexOf("bar") !== -1);
  if (!controls) return false;

  if (String(node.localName || "").indexOf("-") !== -1) return false;
  var materialSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, a[href], ul, ol, dl, table, blockquote, figure, figcaption, pre, code, kbd, samp, label, details, summary, address, cite, time, [itemprop~='duration' i], img, picture, video, audio, iframe, object, embed, svg, canvas, math";
  if (node.matches(materialSelector) || node.querySelector(materialSelector)) return false;
  var controlTags = { b: true, br: true, button: true, div: true, em: true, i: true, small: true, span: true, strong: true };
  var hasStructuredContent = Array.from(node.querySelectorAll("*")).some(function(child) {
    return !controlTags[String(child.localName || "").toLowerCase()];
  });
  if (hasStructuredContent) return false;

  var text = normalizeText([node.textContent, node.getAttribute("aria-label")].filter(Boolean).join(" "));
  if (!text || text.length > 160) return false;
  return /(?:^|[^\d:])(?:\d{1,2}:[0-5]\d:[0-5]\d|\d{1,3}:[0-5]\d)(?![\d:])/.test(text);
}

function stripArticleWidgets(root) {
  var contentSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, blockquote, pre, table, figure";
  root.querySelectorAll("[class*='audio' i], [id*='audio' i], [data-component*='audio' i], [data-testid*='audio' i], [data-role*='audio' i], [role*='audio' i], [aria-label*='audio' i]").forEach(function(node) {
    if (articleAudioControlNode(node)) node.remove();
  });

  root.querySelectorAll(".article-call-to-action, .article-cta, [data-role='article-call-to-action']").forEach(function(node) {
    if (!node.closest("article") || codeContentNode(node)) return;
    if (textLength(node) >= 600 || node.querySelector(contentSelector)) return;
    if (node.querySelector("a[href], button")) node.remove();
  });

  root.querySelectorAll(".loader, .main-loader, [role='status'][aria-busy='true']").forEach(function(node) {
    if (codeContentNode(node)) return;
    if (textLength(node) >= 300 || node.querySelector(contentSelector + ", a[href], time, img, picture, video, audio, [itemprop='author'], [itemprop='comment'], .author, .byline, .comment-body, .reply-body")) return;
    var owner = node.parentElement;
    while (owner) {
      var signature = [owner.id, owner.getAttribute("class"), owner.getAttribute("data-role")].filter(Boolean).join(" ");
      if (/(?:^|[\s_-])(?:comments?|recommendations?|related|read-more)(?:$|[\s_-])/i.test(signature)) {
        node.remove();
        return;
      }
      if (owner === root || owner.tagName === "ARTICLE") break;
      owner = owner.parentElement;
    }
  });
  return root;
}
