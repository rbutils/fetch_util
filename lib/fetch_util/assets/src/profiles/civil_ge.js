  function civilGeArticleContent(metadata) {
    if (!civilGeArticlePage()) return null;

    var body = document.querySelector("article#the-post .entry-content.entry") ||
      document.querySelector("article#the-post .entry-content") ||
      document.querySelector("article .entry-content") ||
      document.querySelector("article .post-content") ||
      document.querySelector("article .content");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: civilGeArticleTitle(metadata),
      byline: firstText([".meta-author", ".post-meta .author", "[rel='author']"]) || (metadata && metadata.byline),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".post-components",
          ".post-bottom-meta",
          ".post-shortlink",
          ".share-links",
          ".share-buttons",
          ".related-posts",
          ".yarpp-related",
          "[class*='related' i]",
          "[class*='share' i]",
          "[class*='advert' i]",
          "[id*='ad-' i]",
          "script",
          "style"
        ].join(", "));
      }
    });
  }

  function civilGeArticlePage() {
    if (!hostMatches(/(^|\.)civil\.ge$/)) return false;
    if (homepageRootPath()) return false;
    return /^\/archives\/\d+\/?$/i.test(location.pathname || "") &&
      !!document.querySelector("article#the-post .entry-content, article .entry-content, article .post-content, article .content");
  }

  function civilGeArticleTitle(metadata) {
    return firstText(["h1.entry-title", "h1.post-title", "article h1", "h1"]) ||
      normalizeText((metadata && metadata.title) || document.title);
  }

  var civilGeBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return civilGeArticleContent(metadata) || civilGeBaseHostAwareContent(metadata, pageText);
  };
