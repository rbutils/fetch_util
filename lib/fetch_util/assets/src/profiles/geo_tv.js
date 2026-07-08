  simpleArticleProfileRegistration({
    hostPattern: /(?:^|\.)geo\.tv$/i,
    pathPattern: /^\/amp\/\d+(?:[/?#]|$)/i,
    bodySelectors: [".content_amp", ".story-area", ".content-area"],
    titleSelectors: [".heading_H h1", "h1"],
    removalSelectors: [".share-btns", ".share-buttons", ".social-share", ".related-article-inside-body", ".article-body-ad", "amp-ad", "iframe", "script", "style", "button"],
    minBodyTextLength: 300
  });
