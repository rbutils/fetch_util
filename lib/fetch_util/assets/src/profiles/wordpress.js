  var WORDPRESS_DOM_SELECTORS = [
    "link[href*='/wp-content/']",
    "script[src*='/wp-content/']",
    "meta[name='generator'][content*='WordPress' i]",
    ".entry-content",
    ".post-content",
    ".wp-block-post-content",
    "[class*='wp-block-' i]"
  ];

  var WORDPRESS_DEDICATED_PROFILE_HOSTS = /(^|\.)(civil\.ge|daryo\.uz|hatena\.blog|khaosod\.co\.th|maroelamedia\.co\.(?:za|tz)|newsit\.gr|tovima\.gr|trend\.az)$/;

  function wordpressDomDetected() {
    if (document.querySelector(WORDPRESS_DOM_SELECTORS.join(", "))) return true;

    var nodes = document.querySelectorAll("[class]");
    for (var i = 0; i < nodes.length; i += 1) {
      var className = nodes[i].getAttribute("class") || "";
      if (/\bwp-[\w-]+\b/i.test(className)) return true;
    }

    return false;
  }

  function wordpressContent(metadata) {
    if (hostMatches(WORDPRESS_DEDICATED_PROFILE_HOSTS)) return null;
    if (!wordpressDomDetected()) return null;

    return wordpressArticleContent(metadata, {
      bodySelectors: [
        "article .wp-block-post-content",
        ".wp-block-post-content",
        "article[id^='post-'] .entry-content",
        "article[id^='post-'] .post-content",
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
        ".entry-header",
        ".post-header",
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
          el.remove();
        });
      }
    });
  }

  registerHostAwareProfile(true, wordpressContent);
