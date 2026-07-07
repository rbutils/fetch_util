  var b92ArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)b92\.net$/,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: [".single-news-content"],
    title: function(metadata) { var pageTitle = normalizeText((document.title || "").replace(/\s+-\s+B92\s*$/i, "")); return pageTitle || (metadata && metadata.title) || firstText([".single-news-title", "article h1", "h1"]); },
    byline: function(metadata) { return (metadata && metadata.byline) || firstText([".single-news-source", "[class*='author' i]", "[rel='author']"]); },
    removalSelectors: [".single-top-news", ".single-news-share", ".single-news-tags", ".single-news-comments", ".single-related-news", ".news-box", ".news-item", ".banner", ".teads-adCall", ".embed-responsive", "[id*='ad-' i]", "[id*='adocean' i]", "[id*='MarketGid' i]", "script", "style"],
    removalTextPatterns: [/^(možda vas zanima|povezane vesti|tagovi|podeli:?|komentari|pogledaj komentare|pošalji komentar|oglas)$/i],
    minBodyTextLength: 250,
    beforeExtract: function(metadata) { if (metadata) metadata.language = ""; }
  });

  var b92BaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return b92ArticleContent(metadata) || b92BaseHostAwareContent(metadata, pageText);
  };
