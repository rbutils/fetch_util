  function indexHrArticleContent(metadata) {
    if (!indexHrArticlePage()) return null;

    var body = indexHrArticleBody();
    if (!body) return null;

    indexHrSuppressStalePublication(metadata);

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

  function indexHrSuppressStalePublication(metadata) {
    if (!metadata) return;

    var publishedTime = metadata.publishedTime;
    if (!publishedTime) return;

    var publishedDate = Date.parse(publishedTime);
    if (isNaN(publishedDate)) return;

    var ageDays = (Date.now() - publishedDate) / (1000 * 60 * 60 * 24);
    if (ageDays > 30) metadata.publishedTime = null;
  }

  registerHostAwareProfile(true, indexHrArticleContent);
