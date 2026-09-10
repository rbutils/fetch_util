var nhkArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)nhk\.or\.jp$|(^|\.)web\.nhk$/i,
  pathPattern: /\/news(?:\/html\/\d{8}\/k\d+\.html|web\/(?:sp\/)?na\/na-k\d+(?:\/|$))/i,
  body: function() {
    var title = document.querySelector("main h1");
    var node = title && title.parentElement;

    while (node && node.tagName !== "MAIN") {
      var paragraphCount = node.querySelectorAll("p").length;
      var textLength = normalizeText(node.textContent || "").length;
      if (paragraphCount >= 2 && textLength >= 100) {
        var parent = node.parentElement;
        var hasTopicSibling = parent && parent.tagName !== "MAIN" && Array.prototype.some.call(parent.children, function(child) {
          var heading = child !== node && child.querySelector("h2, h3");
          return normalizeText((heading && heading.textContent) || "") === "注目ワード";
        });
        return hasTopicSibling ? parent : node;
      }
      node = node.parentElement;
    }
    return null;
  },
  titleSelectors: ["h1"],
  minBodyTextLength: 100,
  removalSelectors: ["button", "[class*='share' i]", "[aria-label*='share' i]"],
  extra: function(metadata, root, node, markdown, text) {
    return /…$/.test(text) ? { warningReasons: ["truncated_content"] } : null;
  }
});

registerHostAwareProfile(true, nhkArticleContent);
