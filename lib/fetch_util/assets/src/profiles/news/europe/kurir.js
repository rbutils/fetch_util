  var kurirArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)kurir\.rs$/,
    pathPattern: /\/\d+\/[a-z0-9-]+(?:\/)?$/i,
    bodySelectors: ["article"],
    title: function(metadata) {
      return normalizeText((metadata && metadata.title) || firstText([".article-title", "article h1", "h1"]) || document.title);
    },
    byline: function(metadata) {
      return (metadata && metadata.byline) || firstText([".article-header-author-prefix", ".article-header-date-published", "[rel='author']"]);
    },
    removalSelectors: [
      ".article-header",
      ".article-big-image",
      ".article-divider",
      ".card-engagement-bar-wrap",
      ".card-share-wrap",
      ".audioStory__label-bar",
      ".inText-banner-wrapper",
      "[class*='related-news' i]",
      "[class*='midasWidget' i]",
      "[class*='share' i]",
      "[class*='comment' i]",
      "script",
      "style"
    ],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, kurirArticleContent);
