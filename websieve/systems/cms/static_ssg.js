  var STATIC_SSG_DOM_SELECTORS = [
    "meta[name='generator'][content*='Hugo' i]",
    "meta[name='generator'][content*='Jekyll' i]",
    "[class*='hugo-' i]",
    "link[href*='/hugo-theme']",
    "script[src*='/hugo-theme']",
    "body[class*='post-template']"
  ];

  function staticSsgDomDetected() {
    return !!document.querySelector(STATIC_SSG_DOM_SELECTORS.join(", "));
  }

  function staticSsgContent(metadata) {
    if (!staticSsgDomDetected()) return null;

    return wordpressArticleContent(metadata, {
      bodySelectors: [
        ".post-content",
        ".article-content",
        "article .content",
        ".prose",
        "main article",
        "article"
      ],
      titleSelectors: [".post-title", ".article-title", "h1"],
      minBodyTextLength: 180,
      removalSelectors: [
        ".comments",
        ".comment",
        ".comments-area",
        ".comment-area",
        ".comment-list",
        ".share",
        ".sharedaddy",
        ".related",
        ".post-navigation",
        ".sidebar",
        "[class*='comment' i]",
        "[class*='sidebar' i]",
        "[class*='share' i]",
        "[class*='related' i]",
        "[class*='nav' i]",
        "[class*='toc' i]",
        "[class*='breadcrumb' i]",
        "[class*='newsletter' i]",
        "[class*='subscribe' i]",
        "[class*='advert' i]",
        "[class*='promo' i]"
      ]
    });
  }

  registerHostAwareProfile(true, staticSsgContent);
