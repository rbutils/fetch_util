  var tovimaGrArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)tovima\.gr$/,
    homepagePath: /^\/?$/,
    bodySelectors: [".post-body.main-content.article-wrapper", ".post-body.main-content", "[itemprop='articleBody']"],
    titleSelectors: ["article h1", "main h1", "h1"],
    byline: function(metadata) {
      return (metadata && metadata.byline) || firstText(["[rel='author']", ".author", ".post-author"]);
    },
    removalSelectors: [
      ".google-preferred-source",
      ".whsk_parent__div",
      ".wrap_article_banner",
      "[id^='banner-']",
      "[id*='banner' i]",
      "[id*='ad-' i]",
      "[class*='advert' i]",
      "[class*='related' i]",
      "[class*='share' i]",
      "script",
      "style"
    ],
    removalTextPatterns: [/^κάντε\s+to\s+bhma\s+προτιμώμενη\s+πηγή$/i, /googletag\.cmd\.push|google-preferred-source/i],
    minBodyTextLength: 250,
    beforeExtract: function(metadata) {
      if (metadata) metadata.language = "";
    },
    rewriteRoot: function(root) {
      root.querySelectorAll("a").forEach(function(link) {
        link.replaceWith(document.createTextNode(" " + (link.textContent || "") + " "));
      });
    }
  });

  var tovimaGrBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return tovimaGrArticleContent(metadata) || tovimaGrBaseHostAwareContent(metadata, pageText);
  };
