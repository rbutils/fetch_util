  simpleArticleProfileRegistration({
    condition: /(^|\.)opais\.co\.mz$/,
    hostPattern: /(^|\.)opais\.co\.mz$/,
    pathPattern: /\/[^/?#]+\/?$/i,
    bodySelectors: [
      ".elementor-widget-theme-post-content .elementor-widget-container",
      ".elementor-widget-theme-post-content"
    ],
    titleSelectors: [
      ".elementor-widget-theme-post-title h1",
      "h1"
    ],
    minBodyTextLength: 200,
    removalSelectors: [
      ".elementor-share-buttons",
      ".sharedaddy",
      ".post-nav-links",
      "script",
      "style"
    ]
  });
