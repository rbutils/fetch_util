  var daryoArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)daryo\.uz$/,
    bodySelectors: [".news-section-main-content .post-content.entry-content", ".news-section-main-content .post-content", ".post-content.entry-content", ".article-content, .news-body, [itemprop='articleBody']"],
    titleSelectors: [".news-section-main-content__title", "h1"],
    removalSelectors: [".source", ".figcaption-1", ".tags-likes-content", ".comments-content", ".back-share-container", "[class*='share' i]", "[class*='comment' i]", "[class*='tag' i]"],
    removalTextPatterns: [/^(manba:\s*|izohlar|izoh qoldirish|telegram|facebook|vkontakte|copy link)$/i],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, daryoArticleContent);
