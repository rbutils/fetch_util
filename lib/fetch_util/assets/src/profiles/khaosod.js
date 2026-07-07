  function khaosodArticleContent(metadata) {
    return wordpressArticleContent(metadata, {
      hostPattern: /(^|\.)khaosod\.co\.th$/,
      homepagePath: /^\/?$/,
      pathPattern: /\/news_\d+\/?$/i,
      bodySelectors: [
        ".article-content",
        ".news-content",
        "div.news-detail",
        ".story-body",
        ".entry-content",
        "[itemprop='articleBody']"
      ],
      restFallback: {
        postIdPattern: /news_(\d+)\/?$/i,
        minTextLength: 250
      },
      title: firstText([".udsg__main-title", ".title-news", "article h1", "main h1", "h1"]) || (metadata && metadata.title),
      minVisibleBodyTextLength: 250,
      minTextLength: 250,
      removalSelectors: [".ads_position_wrapper", ".udgal-desc", ".trc_related_container", ".tbl-explore-more-overlay", ".social", "[id*='taboola' i]"]
    });
  }

  registerHostAwareProfile(true, khaosodArticleContent);
