  var telexArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)telex\.hu$/,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: [
      ".article-html-content",
      ".article-body",
      ".article__body",
      ".article-text",
      "[class~='article_body_']",
      "[itemprop='articleBody']",
      "#cikk-content .content",
      ".single-article__content"
    ],
    titleSelectors: [".single-article__content h1", "article h1", "h1"],
    bylineSelectors: ["[class*='author' i]", "[class*='byline' i]"],
    removalSelectors: [
      ".top-section",
      ".top-shr",
      ".article-bottom",
      ".recommendation",
      ".article-hint",
      ".google-box",
      ".support-box__campaign",
      ".support-box__content",
      ".remp-banner",
      "#remp-campaign",
      "#article-endbox-campaign-content",
      "[class*='tooltip' i]",
      "[class*='options' i]",
      "[class*='share' i]",
      "[class*='audio' i]",
      "[class*='weather' i]",
      "[id*='weather' i]",
      "[src^='data:image/svg+xml']"
    ],
    removalTextPatterns: [
      /^(hozzáadva a lejátszási listához|vágólapra másolva|másolás|megosztás)$/i,
      /^állítsd be a telexet megbízható forrásnak!?$/i,
      /^egy könyv, amit bárhová magaddal vihetsz$/i,
      /^kedvenceink$/i
    ],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, telexArticleContent);
