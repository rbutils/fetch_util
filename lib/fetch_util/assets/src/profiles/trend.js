  function trendArticleContent(metadata) {
    if (!trendArticlePage()) return null;

    var body = document.querySelector(".article-content.article-paddings") ||
      document.querySelector(".article-content") ||
      document.querySelector(".news-content") ||
      document.querySelector(".content-text") ||
      document.querySelector(".entry-content");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: trendArticleTitle(metadata),
      byline: firstText([".article .author", ".article .author-name", ".article-paddings a[href*='/author/']"]) || (metadata && metadata.byline),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".social-sharing",
          ".share",
          ".tags",
          ".related-news",
          ".recommended",
          ".most-read",
          "[class*='advert' i]",
          "[id*='ad' i]",
          "script",
          "style"
        ].join(", "));
      }
    });
  }

  function trendArticlePage() {
    if (!hostMatches(/(^|\.)trend\.az$/)) return false;
    if (homepageRootPath()) return false;
    if (!/\/\d+\.html$/i.test(location.pathname || "")) return false;
    return !!document.querySelector(".article-content.article-paddings, .article-content, .news-content, .content-text, .entry-content");
  }

  function trendArticleTitle(metadata) {
    return firstText([".article h1", ".article-title", "main h1", "h1"]) ||
      (metadata && metadata.title) ||
      normalizeText(document.title || "");
  }

  var trendBaseSlugKeywords = slugKeywords;
  slugKeywords = function() {
    if (trendArticlePage()) return [];
    return trendBaseSlugKeywords();
  };

  var trendBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return trendArticleContent(metadata) || trendBaseHostAwareContent(metadata, pageText);
  };
