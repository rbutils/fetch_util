  var osnovaArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)(?:vc|tjournal|dk)\.ru$/,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: [
      ".entry > .content > .content__body",
      ".content:not(.content--short):not(.content--embed) > .content__body",
      ".entry-content",
      "div.l-island",
      ".layout__content article .content__body"
    ],
    titleSelectors: ["h1.content-title", "h1", ".content__title"],
    bylineSelectors: [".content-header-author__name", ".author__name", "[class*='author'] a"],
    removalSelectors: [
      ".recommendations",
      ".content-list",
      ".content__aside",
      ".feed",
      "div[data-block='feed']",
      ".andropov-osnova-embed",
      ".block-osnova-embed",
      ".content--embed",
      ".content--short",
      ".booster",
      "[class*='booster']",
      "[data-gtm-click*='recommendations']"
    ],
    removalTextPatterns: [/^(читать дальше|показать полностью|реклама|спецпроект)$/i],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, osnovaArticleContent);
