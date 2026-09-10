  function ghostDomDetected() {
    return !!document.querySelector("meta[name='generator'][content^='Ghost'], .gh-head, .gh-canvas, .gh-article, .gh-article-body, article.gh-article");
  }

  function ghostArticleContent(metadata) {
    if (!ghostDomDetected()) return null;

    return wordpressArticleContent(metadata, {
      bodySelectors: [".gh-article", ".gh-article-body", ".post-content", ".article-content"],
      titleSelectors: [".gh-article-title", "h1"],
      minBodyTextLength: 180,
      removalSelectors: [
        ".gh-head",
        ".gh-foot",
        ".gh-article-meta",
        ".gh-post-upgrade-cta",
        ".share",
        "[class*='share' i]",
        "[class*='related' i]",
        "[class*='subscribe' i]",
        "[class*='comment' i]",
        "[class*='newsletter' i]",
        "[class*='advert' i]"
      ]
    });
  }

  registerHostAwareProfile(true, ghostArticleContent);
