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

function articleAudioFallbackNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;

  var componentMarker = [
    node.getAttribute("id"),
    node.getAttribute("class"),
    node.getAttribute("data-component"),
    node.getAttribute("data-testid"),
    node.getAttribute("data-role"),
    node.getAttribute("role")
  ].filter(Boolean).some(function(value) {
    return String(value).split(/\s+/).some(function(part) {
      var normalized = part.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean).join(" ");
      return normalized === "audio player" || normalized === "article audio player";
    });
  });
  if (!componentMarker) return false;
  if (String(node.localName || "").indexOf("-") !== -1) return false;

  var materialSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, a[href], ul, ol, dl, table, blockquote, figure, figcaption, pre, code, kbd, samp, label, details, summary, address, cite, time, [itemprop], img, picture, video, audio, iframe, object, embed, svg, canvas, math, button, input, select, textarea, output";
  if (node.matches(materialSelector) || node.querySelector(materialSelector)) return false;

  var text = normalizeText(node.textContent);
  if (!text || text.length > 240 || node.children.length) return false;
  var englishFallback = /^(?:(?:your|this|the|our)\s+)?browser\s+(?:does\s+not|doesn['’]t|cannot|can['’]t|is\s+unable\s+to)\s+(?:support|play|reproduce)(?:\s+(?:the\s+)?(?:audio|sound|media)(?:\s+(?:element|file|playback|content|document))?)?[.!]?$/i;
  var germanFallback = /^(?:(?:ihr|dieser|der|ein|mein|dein)\s+)?browser\s+(?:(?:kann|k[oö]nnen)\s+(?:dieses?\s+)?(?:audio|tondokument|audiodokument|medium)?\s*(?:nicht|kein(?:e|en)?)\s+(?:wiedergeben|abspielen|unterst[uü]tzen)|unterst[uü]tzt\s+(?:die\s+)?(?:audio|tondokument|wiedergabe)\s+(?:nicht|kein(?:e|en)?))[.!]?$/i;
  return englishFallback.test(text) || germanFallback.test(text);
}

function articleAudioPromptNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;
  if (!node.matches("[class~='audio-player' i], [id='audio-player' i], [data-component='audio-player' i], [data-testid='audio-player' i], [data-role='audio-player' i]")) return false;
  if (String(node.localName || "").indexOf("-") !== -1 || node.children.length !== 1) return false;

  var title = node.firstElementChild;
  if (!title || !title.matches("[class~='audio-player--title' i], [data-role='audio-player-title' i]") || title.children.length) return false;
  var text = normalizeText(title.textContent || "");
  if (!text || text.length > 80) return false;
  return /^(?:(?:listen(?:\s+to)?|play|slu[sš]aj)\s+(?:(?:this|the)\s+)?(?:article|story|news|report|vest)|read\s+(?:(?:(?:this|the)\s+)?(?:article|story|news|report|vest)\s+aloud|(?:it\s+)?aloud\s+(?:(?:this|the)\s+)?(?:article|story|news|report|vest)))[.!]?$/i.test(text);
}

function stripArticleWidgets(root) {
  var contentSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, blockquote, pre, table, figure";
  root.querySelectorAll("[class*='audio' i], [id*='audio' i], [data-component*='audio' i], [data-testid*='audio' i], [data-role*='audio' i], [role*='audio' i], [aria-label*='audio' i]").forEach(function(node) {
    if (articleAudioControlNode(node) || articleAudioFallbackNode(node) || articleAudioPromptNode(node)) node.remove();
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
