  function daryoArticleContent(metadata) {
    if (!hostMatches(/(^|\.)daryo\.uz$/)) return null;

    var body = document.querySelector(".news-section-main-content .post-content.entry-content") ||
      document.querySelector(".news-section-main-content .post-content") ||
      document.querySelector(".post-content.entry-content") ||
      document.querySelector(".article-content, .news-body, [itemprop='articleBody']");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".news-section-main-content__title", "h1"]) || metadata.title,
      byline: firstText([".news-author-info__title", "[class*='author' i]"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".source",
          ".figcaption-1",
          ".tags-likes-content",
          ".comments-content",
          ".back-share-container",
          "[class*='share' i]",
          "[class*='comment' i]",
          "[class*='tag' i]"
        ].join(", "));

        removeNodesByText(root, "p, div, span, a, button, h2", /^(manba:\s*|izohlar|izoh qoldirish|telegram|facebook|vkontakte|copy link)$/i);
      }
    });
  }

  var daryoBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return daryoArticleContent(metadata) || daryoBaseHostAwareContent(metadata, pageText);
  };
