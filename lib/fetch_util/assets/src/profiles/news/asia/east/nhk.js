var nhkArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)nhk\.or\.jp$|(^|\.)web\.nhk$/i,
  pathPattern: /\/news(?:\/html\/\d{8}\/k\d+\.html|web\/(?:sp\/)?na\/na-k\d+(?:\/|$))/i,
  body: function() {
    return document.querySelector("main > div > div > div > div");
  },
  titleSelectors: ["h1"],
  minBodyTextLength: 100,
  removalSelectors: ["button", "[class*='share' i]", "[aria-label*='share' i]"],
  rewriteRoot: function(root) {
    Array.prototype.slice.call(root.children).forEach(function(child, index) {
      if (index >= 3) child.remove();
    });
  }
});

registerHostAwareProfile(true, nhkArticleContent);
