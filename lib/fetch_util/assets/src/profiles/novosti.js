  var novostiArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)novosti\.rs$/,
    pathPattern: /\/\d{5,}(?:\/|$)/,
    bodySelectors: [".single-news-content"],
    titleSelectors: [".page-content-wrapper h1", "main h1", "h1"],
    bylineSelectors: [".news-info a[href*='/autori/']", ".news-info"],
    removalSelectors: [
      "script",
      ".bnr",
      "[class*='banner' i]",
      "[class*='share' i]",
      "[class*='social' i]",
      ".recommended-news",
      ".mobile-app",
      ".embed-responsive",
      "iframe"
    ],
    removalTextPatterns: [/^(preporučujemo|pratite nas i putem ios i android aplikacije|dodaj novosti kao svoj google izvor)$/i],
    minBodyTextLength: 250,
    beforeExtract: function(metadata) {
      if (metadata) metadata.language = "";
    },
    rewriteRoot: function(root) {
      root.querySelectorAll("p, div, section, aside, span, li").forEach(function(el) {
        var text = normalizeText(el.textContent || "");
        if (/^foto:/i.test(text) && text.length < 120 && !el.querySelector("img")) el.remove();
      });
    }
  });

  function novostiArticlePage() {
    return !!novostiArticleContent();
  }

  registerHostAwareProfile(true, novostiArticleContent);