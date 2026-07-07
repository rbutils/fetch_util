  function geoTvArticleContent(metadata) {
    if (location.hostname !== "geo.tv" && !/\.geo\.tv$/i.test(location.hostname || "")) return null;
    if (!/^\/amp\/\d+(?:[/?#]|$)/i.test(location.pathname || "")) return null;

    var node = document.querySelector(".content_amp") || document.querySelector(".story-area") || document.querySelector(".content-area");
    if (!node) return null;

    return profileArticleContent(metadata, node, {
      titleSelectors: [".heading_H h1", "h1"],
      publishedTime: function(articleMetadata) {
        if (articleMetadata) articleMetadata.publishedTime = null;
        return null;
      },
      minTextLength: 300,
      rewriteRoot: function(root) {
        removeAll(root, ".share-btns, .share-buttons, .social-share, .related-article-inside-body, .article-body-ad, amp-ad, iframe, script, style, button");
      }
    });
  }

  registerHostAwareProfile(true, geoTvArticleContent);
