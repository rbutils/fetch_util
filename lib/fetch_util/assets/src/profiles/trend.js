  var trendArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)trend\.az$/,
    homepagePath: /^\/?$/,
    pathPattern: /\/\d+\.html$/i,
    bodySelectors: [".article-content.article-paddings", ".article-content", ".news-content", ".content-text", ".entry-content"],
    titleSelectors: [".article h1", ".article-title", "main h1", "h1"],
    bylineSelectors: [".article .author", ".article .author-name", ".article-paddings a[href*='/author/']"],
    removalSelectors: [
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
    ],
    minBodyTextLength: 250
  });

  function trendArticlePage() {
    return !!trendArticleContent();
  }

  var trendBaseSlugKeywords = slugKeywords;
  slugKeywords = function() {
    if (trendArticlePage()) return [];
    return trendBaseSlugKeywords();
  };

  registerHostAwareProfile(true, trendArticleContent);