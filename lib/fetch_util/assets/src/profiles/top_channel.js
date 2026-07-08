  simpleArticleProfileRegistration({
    hostPattern: /(^|\.)top-channel\.tv$/,
    pathPattern: /^\/\d{4}\/\d{2}\/\d{2}\//,
    bodySelectors: [".contentWrapper .siteWidthContainer"],
    titleSelectors: [".titleInner h1", "h1"],
    bylineSelectors: [".titleInner .date", ".date"],
    removalSelectors: ["article:first-of-type", ".adGroupWrapper", ".featuredPoll", "script", "style"],
    minBodyTextLength: 500
  });
