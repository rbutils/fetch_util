  function twentyFourUrArticleContent(metadata) {
    if (!twentyFourUrArticlePage()) return null;
    if (metadata) metadata.language = "";

    var body = document.querySelector("#article-body") ||
      document.querySelector(".article-body") ||
      document.querySelector(".story-body") ||
      document.querySelector("div.article-content") ||
      document.querySelector(".content-body");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: twentyFourUrArticleTitle(metadata),
      byline: metadata.byline || firstText(["[rel='author']", ".author", ".article-author"]),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[class*='share' i]",
          "[class*='related' i]",
          "[class*='advert' i]",
          "[class*='banner' i]",
          "[id*='ad-' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, span, section").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(za ogled potrebujemo tvojo privolitev za vstavljanje vsebin družbenih omrežij in tretjih ponudnikov\.?|omogoči piškotke)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function twentyFourUrArticlePage() {
    if (!hostMatches(/(^|\.)24ur\.com$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector("#article-body, .article-body, .story-body, div.article-content, .content-body");
  }

  function twentyFourUrArticleTitle(metadata) {
    return firstText(["h1.article-title", ".article-title", "article h1", "h1.title", "h1"]) ||
      normalizeText((metadata && metadata.title) || document.title).replace(/\s*\|\s*24ur\.com\s*$/i, "");
  }

  var twentyFourUrBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return twentyFourUrArticleContent(metadata) || twentyFourUrBaseHostAwareContent(metadata, pageText);
  };
