  function hatenaBlogContent(metadata) {
    if (!hostMatches(/(^|\.)(hatenablog\.com|hateblo\.jp|hatenablog\.net|hatenadiary\.com)$/i)) return null;

    var article = document.querySelector("article.entry") ||
      document.querySelector("article .entry-content") ||
      document.querySelector(".entry-body") ||
      document.querySelector(".entry-content");
    if (!article) return null;

    var body = article.matches(".entry-content, .entry-body") ? article :
      (article.querySelector(".entry-content") || article.querySelector(".entry-body"));
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["h1.entry-title", ".entry-title-link", "article.entry h1", "h1"]) || metadata.title,
      byline: firstText([".entry-footer .author a", ".entry-footer .vcard a", ".entry-header .author a"]) || metadata.byline,
      minTextLength: 180,
      rewriteRoot: function(root) {
        root.querySelectorAll(".hatena-star-container, .hatena-star-star-container, .social-buttons, .share-button, .entry-footer, .entry-footer-section, .comment-box, .comment, .comments, .pager, .related-entries, .adsbygoogle, .google-afc").forEach(function(el) {
          el.remove();
        });
      }
    });
  }

  var hatenaBlogPreviousScientificRecordContent = scientificRecordContent;
  scientificRecordContent = function(metadata) {
    return hatenaBlogContent(metadata) || hatenaBlogPreviousScientificRecordContent(metadata);
  };
