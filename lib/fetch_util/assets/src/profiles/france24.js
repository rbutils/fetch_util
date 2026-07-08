  var france24ArticleContent = simpleArticleProfile({
    hostPattern: /(?:^|\.)france24\.com$/i,
    pathPattern: /\/\d{8}-/,
    bodySelectors: [".t-content__body"],
    titleSelectors: ["h1"],
    removalSelectors: ["aside", "nav", "[class*='share' i]", "[class*='newsletter' i]", "[class*='ad' i]", "script", "style"],
    minBodyTextLength: 300
  });

  registerHostAwareProfile(true, france24ArticleContent);
