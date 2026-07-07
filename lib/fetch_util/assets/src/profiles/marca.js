  function marcaArticleContent(metadata) {
    return unidadEditorialEngineArticleContent(metadata, {
      hostPattern: /(^|\.)marca\.com$/,
      bodySelectors: [
        ".ue-c-article__body",
        "[data-section='articleBody']",
        ".article-body",
        "div.vcm-content",
        ".content-article",
        ".article-content",
        "div[itemprop='articleBody']",
        "[itemprop='articleBody']"
      ],
      leadSelectors: [".ue-c-article__standfirst", ".article-intro", ".summary", ".article__summary"],
      publicMinTextLength: 900,
      extraRemovalSelectors: [".ue-c-players-ranking-widget", "[class*='ranking-widget' i]", "[class*='scoreboard' i]"]
    });
  }

  var marcaBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return marcaArticleContent(metadata) || marcaBaseHostAwareContent(metadata, pageText);
  };
