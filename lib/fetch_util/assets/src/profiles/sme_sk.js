  var smeSkArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)sme\.sk$/,
    homepagePath: /^\/?$/,
    bodySelectors: [".article-body.js-article-body", ".article-body", "[itemprop='articleBody']"],
    titleSelectors: [".article-head h1", ".heading--article", "article h1", "h1"],
    byline: function(metadata) {
      return (metadata && metadata.byline) || firstText([".author-tile__name", "[rel='author']", ".article-author"]);
    },
    removalSelectors: [
      ".ad-position",
      ".sme-banner",
      ".js-article-share",
      ".js-audio-player",
      ".article-audio",
      ".article-list",
      ".article-tile",
      ".pb_holder",
      ".discussion",
      ".js-discussion",
      "[class*='discussion' i]",
      "[class*='related' i]",
      "[class*='newsletter' i]",
      "[class*='banner' i]",
      "[class*='ad-' i]",
      "script",
      "style"
    ],
    removalTextPatterns: [/^(sme audio|playlist|vypočuť článok|zdieľať|diskusia|reklama|súvisiace články)$/i],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, smeSkArticleContent);