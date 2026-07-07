  function tovimaGrArticleContent(metadata) {
    return wordpressArticleContent(metadata, {
      hostPattern: /(^|\.)tovima\.gr$/,
      homepagePath: /^\/?$/,
      bodySelectors: [".post-body.main-content.article-wrapper", ".post-body.main-content", "[itemprop='articleBody']"],
      titleSelectors: ["article h1", "main h1", "h1"],
      removalSelectors: [".google-preferred-source", ".whsk_parent__div", ".wrap_article_banner", "[id^='banner-']", "[id*='banner' i]"],
      removalTextPatterns: [/^κάντε\s+to\s+bhma\s+προτιμώμενη\s+πηγή$/i, /googletag\.cmd\.push|google-preferred-source/i],
      minBodyTextLength: 250,
      rewriteRoot: function(root) {
        root.querySelectorAll("a").forEach(function(link) {
          link.replaceWith(document.createTextNode(" " + (link.textContent || "") + " "));
        });
      }
    });
  }

  registerHostAwareProfile(true, tovimaGrArticleContent);
