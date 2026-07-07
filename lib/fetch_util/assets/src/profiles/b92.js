  function b92ArticleContent(metadata) {
    if (!b92ArticlePage()) return null;
    if (metadata) metadata.language = "";

    var body = document.querySelector(".single-news-content");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: b92ArticleTitle(metadata),
      byline: metadata.byline || firstText([".single-news-source", "[class*='author' i]", "[rel='author']"]),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".single-top-news",
          ".single-news-share",
          ".single-news-tags",
          ".single-news-comments",
          ".single-related-news",
          ".news-box",
          ".news-item",
          ".banner",
          ".teads-adCall",
          ".embed-responsive",
          "[id*='ad-' i]",
          "[id*='adocean' i]",
          "[id*='MarketGid' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, span, h3, h4").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(možda vas zanima|povezane vesti|tagovi|podeli:?|komentari|pogledaj komentare|pošalji komentar|oglas)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function b92ArticlePage() {
    if (!hostMatches(/(^|\.)b92\.net$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector(".single-news-content");
  }

  function b92ArticleTitle(metadata) {
    var pageTitle = normalizeText((document.title || "").replace(/\s+-\s+B92\s*$/i, ""));
    return pageTitle || (metadata && metadata.title) || firstText([".single-news-title", "article h1", "h1"]);
  }

  var b92BaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return b92ArticleContent(metadata) || b92BaseHostAwareContent(metadata, pageText);
  };
