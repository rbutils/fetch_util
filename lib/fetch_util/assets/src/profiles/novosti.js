  function novostiArticleContent(metadata) {
    if (!novostiArticlePage()) return null;

    var body = document.querySelector(".single-news-content");
    if (!body) return null;
    if (metadata) metadata.language = "";

    return profileArticleContent(metadata, body, {
      title: firstText([".page-content-wrapper h1", "main h1", "h1"]) || metadata.title,
      byline: firstText([".news-info a[href*='/autori/']", ".news-info"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "script",
          ".bnr",
          "[class*='banner' i]",
          "[class*='share' i]",
          "[class*='social' i]",
          ".recommended-news",
          ".mobile-app",
          ".embed-responsive",
          "iframe"
        ].join(", "));

        root.querySelectorAll("p, div, section, aside, span, li").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(preporučujemo|pratite nas i putem ios i android aplikacije|dodaj novosti kao svoj google izvor)$/i.test(text)) el.remove();
          if (/^foto:/i.test(text) && text.length < 120 && !el.querySelector("img")) el.remove();
        });
      }
    });
  }

  function novostiArticlePage() {
    if (!hostMatches(/(^|\.)novosti\.rs$/)) return false;
    if (!/\/\d{5,}(?:\/|$)/.test(location.pathname || "")) return false;
    return !!document.querySelector(".single-news-content");
  }

  var novostiBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return novostiArticleContent(metadata) || novostiBaseHostAwareContent(metadata, pageText);
  };
