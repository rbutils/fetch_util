  var civilGeArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)civil\.ge$/,
    pathPattern: /^\/archives\/\d+\/?$/i,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: ["article#the-post .entry-content.entry", "article#the-post .entry-content", "article .entry-content", "article .post-content", "article .content"],
    title: function(metadata) { return firstText(["h1.entry-title", "h1.post-title", "article h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title); },
    removalSelectors: [".post-components", ".post-bottom-meta", ".post-shortlink", ".share-links", ".share-buttons", ".related-posts", ".yarpp-related", "[class*='related' i]", "[class*='share' i]", "[class*='advert' i]", "[id*='ad-' i]", "script", "style"],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, civilGeArticleContent);
