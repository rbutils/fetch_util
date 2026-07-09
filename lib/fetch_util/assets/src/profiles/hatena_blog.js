  function hatenaBlogContent(metadata) {
    return wordpressArticleContent(metadata, {
      hostPattern: /(^|\.)(hatenablog\.com|hateblo\.jp|hatenablog\.net|hatenadiary\.com)$/i,
      bodySelectors: ["article.entry .entry-content", "article.entry .entry-body", "article .entry-content", ".entry-body", ".entry-content"],
      titleSelectors: ["h1.entry-title", ".entry-title-link", "article.entry h1", "h1"],
      bylineSelectors: [".entry-footer .author a", ".entry-footer .vcard a", ".entry-header .author a"],
      minTextLength: 180,
      removalSelectors: [".hatena-star-container", ".hatena-star-star-container", ".entry-footer", ".entry-footer-section", ".comment-box", ".comment", ".comments", ".pager", ".related-entries", ".google-afc"]
    });
  }

  var hatenaBlogPreviousScientificRecordContent = scientificRecordContent;
  scientificRecordContent = function(metadata) {
    return hatenaBlogContent(metadata) || hatenaBlogPreviousScientificRecordContent(metadata);
  };

  function registerScientificRecordProfiles() {
    registerHostAwareProfile(true, function(metadata, pageText) {
      return scientificRecordContent(metadata, pageText);
    });
  }
