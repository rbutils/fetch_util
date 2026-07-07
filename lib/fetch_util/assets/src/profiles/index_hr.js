  function indexHrArticleContent(metadata) {
    if (!indexHrArticlePage()) return null;

    var body = indexHrArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["h1", ".title"]) || metadata.title,
      publishedTime: null,
      minTextLength: 180,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".share",
          ".social",
          ".related",
          ".comments",
          ".comment",
          "#comments-container",
          "[class*='comment' i]",
          "[class*='advert' i]",
          "[class*='promo' i]",
          "[class*='banner' i]",
          "iframe",
          "script",
          "style"
        ].join(", "));
      }
    });
  }

  function indexHrArticlePage() {
    if (!hostMatches(/(^|\.)index\.hr$/)) return false;
    return /\/clanak\//i.test(location.pathname || "");
  }

  function indexHrArticleBody() {
    return document.querySelector("section[aria-label='Tekst članka']") ||
      document.querySelector(".article-body") ||
      document.querySelector(".article-content") ||
      document.querySelector(".post-content") ||
      document.querySelector("article [itemprop='articleBody']") ||
      document.querySelector("article");
  }

  registerHostAwareProfile(true, indexHrArticleContent);
