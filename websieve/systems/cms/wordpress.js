  var WORDPRESS_DOM_SELECTORS = [
    "link[href*='/wp-content/']",
    "script[src*='/wp-content/']",
    "meta[name='generator'][content*='WordPress' i]",
    ".wp-block-post-content",
    "[class*='wp-block-' i]"
  ];

  var WORDPRESS_SITE_PROFILE_CONFIGS = [
    {
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
      title: function(metadata) { return firstText([".udsg__main-title", ".title-news", "article h1", "main h1", "h1"]) || (metadata && metadata.title); },
      minVisibleBodyTextLength: 250,
      minTextLength: 250,
      removalSelectors: [".ads_position_wrapper", ".udgal-desc", ".trc_related_container", ".tbl-explore-more-overlay", ".social", "[id*='taboola' i]"]
    }
  ];

  var WORDPRESS_DEDICATED_PROFILE_HOSTS = /(^|\.)(daryo\.uz|hatena\.blog)$/;

  function wordpressSiteProfileConfig() {
    var host = location.hostname || "";
    for (var i = 0; i < WORDPRESS_SITE_PROFILE_CONFIGS.length; i += 1) {
      var config = WORDPRESS_SITE_PROFILE_CONFIGS[i];
      if (simpleArticlePatternMatches(config.hostPattern, host)) return config;
    }
    return null;
  }

  function wordpressDomDetected() {
    if (document.querySelector(WORDPRESS_DOM_SELECTORS.join(", "))) return true;
    var headings = Array.from(document.querySelectorAll("article h1.entry-title")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    if (headings.length === 1) {
      var article = headings[0].closest("article");
      var bodies = Array.from(article.querySelectorAll(".entry-content")).filter(function(node) {
        return node.closest("article") === article && !elementSubtreeHidden(node) &&
          (headings[0].compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) &&
          Array.from(node.querySelectorAll("p")).some(function(paragraph) {
            return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "");
          });
      });
      if (bodies.length === 1) return true;
    }

    var nodes = document.querySelectorAll("[class]");
    for (var i = 0; i < nodes.length; i += 1) {
      var className = nodes[i].getAttribute("class") || "";
      if (/\bwp-[\w-]+\b/i.test(className)) return true;
    }

    return false;
  }

  function wordpressContent(metadata) {
    var siteProfileConfig = wordpressSiteProfileConfig();
    if (siteProfileConfig) return wordpressArticleContent(metadata, siteProfileConfig);
    if (hostMatches(WORDPRESS_DEDICATED_PROFILE_HOSTS)) return null;
    if (!wordpressDomDetected()) return null;

    return wordpressArticleContent(metadata, {
      includeHeaderContext: true,
      bodySelectors: [
        "article .wp-block-post-content",
        ".wp-block-post-content",
        "article[id^='post-'] .entry-content",
        "article[id^='post-'] .post-content",
        "article .post-description",
        ".post-description",
        "article .entry-content",
        "article .post-content",
        ".entry-content",
        ".post-content",
        "[itemprop='articleBody']"
      ],
      titleSelectors: ["h1.entry-title", ".entry-title", "article h1", "main h1", "h1"],
      bylineSelectors: ["[rel='author']", ".author", ".byline", ".post-author", ".wp-block-post-author", "[class*='author' i]"],
      minBodyTextLength: 180,
      removalSelectors: [
        ".entry-header:not(h1)",
        ".post-header:not(h1)",
        ".entry-meta",
        ".post-meta",
        ".author-bio",
        ".author-box",
        ".post-author",
        ".wp-block-comments",
        ".wp-block-comment-template",
        ".wp-block-post-author",
        ".wp-block-post-comments",
        ".wp-block-latest-comments",
        ".share",
        "[class*='share' i]",
        "[class*='newsletter' i]",
        "[class*='subscribe' i]",
        "[class*='related' i]",
        "[class*='promo' i]",
        "[class*='sponsor' i]",
        "[class*='advert' i]",
        "[class*='ad-' i]"
      ],
      rewriteRoot: function(root) {
        root.querySelectorAll("header, time").forEach(function(el) {
          if (!el.closest("[data-fetchutil-wordpress-header]")) el.remove();
        });
      }
    });
  }

  registerHostAwareProfile(true, wordpressContent);
