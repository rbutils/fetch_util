  function trendArticleContent(metadata) {
    return wordpressArticleContent(metadata, {
      hostPattern: /(^|\.)trend\.az$/,
      homepagePath: /^\/?$/,
      pathPattern: /\/\d+\.html$/i,
      bodySelectors: [".article-content.article-paddings", ".article-content", ".news-content", ".content-text", ".entry-content"],
      titleSelectors: [".article h1", ".article-title", "main h1", "h1"],
      removalSelectors: [".tags", ".related-news", ".most-read"],
      minBodyTextLength: 250
    });
  }

  function trendArticlePage() {
    return !!trendArticleContent();
  }

  var trendBaseSlugKeywords = slugKeywords;
  slugKeywords = function() {
    if (trendArticlePage()) return [];
    return trendBaseSlugKeywords();
  };

  registerHostAwareProfile(true, trendArticleContent);
