  function btaBgArticleContent(metadata) {
    if (!btaBgArticlePage()) return null;
    if (metadata) metadata.language = "bg";

    var body = document.querySelector(".post__content");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: btaBgArticleTitle(metadata),
      byline: firstText([".post__author", ".post .author", "[rel='author']"]) || (metadata && metadata.byline),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".post__footer",
          ".news-card",
          ".share",
          ".social",
          ".banner",
          "[class*='advert' i]",
          "[id*='ad-' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("a[href]").forEach(function(link) {
          link.removeAttribute("href");
        });
      }
    });
  }

  function btaBgArticlePage() {
    if (!hostMatches(/(^|\.)bta\.bg$/)) return false;
    if (homepageRootPath()) return false;
    return /^\/bg\/news\//.test(location.pathname || "") && !!document.querySelector(".post__content");
  }

  function btaBgArticleTitle(metadata) {
    if (metadata && metadata.title) return metadata.title;
    return firstText([".post h1", "main h1", "h1"]) || normalizeText(document.title || "");
  }

  var btaBgBaseBodyMatchesLanguage = bodyMatchesLanguage;
  bodyMatchesLanguage = function(langCode, body) {
    if (langCode === "bg" && btaBgArticlePage()) return true;
    return btaBgBaseBodyMatchesLanguage(langCode, body);
  };

  var btaBgBaseSlugKeywords = slugKeywords;
  slugKeywords = function() {
    if (btaBgArticlePage()) return [];
    return btaBgBaseSlugKeywords();
  };

  var btaBgBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return btaBgArticleContent(metadata) || btaBgBaseHostAwareContent(metadata, pageText);
  };
