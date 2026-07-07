  var twentyFourUrArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)24ur\.com$/,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: ["#article-body", ".article-body", ".story-body", "div.article-content", ".content-body"],
    title: function(metadata) { return firstText(["h1.article-title", ".article-title", "article h1", "h1.title", "h1"]) || normalizeText((metadata && metadata.title) || document.title).replace(/\s*\|\s*24ur\.com\s*$/i, ""); },
    byline: function(metadata) { return (metadata && metadata.byline) || firstText(["[rel='author']", ".author", ".article-author"]); },
    removalSelectors: ["[class*='share' i]", "[class*='related' i]", "[class*='advert' i]", "[class*='banner' i]", "[id*='ad-' i]", "script", "style"],
    minBodyTextLength: 250
  });

  var twentyFourUrBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return twentyFourUrArticleContent(metadata) || twentyFourUrBaseHostAwareContent(metadata, pageText);
  };
