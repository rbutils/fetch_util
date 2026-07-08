  var WORDPRESS_DOM_SELECTORS = [
    "link[href*='/wp-content/']",
    "script[src*='/wp-content/']",
    "meta[name='generator'][content*='WordPress' i]",
    ".entry-content",
    ".post-content",
    ".wp-block-post-content",
    "[class*='wp-block-' i]"
  ];

  var WORDPRESS_SITE_PROFILE_CONFIGS = [
    {
      hostPattern: /(^|\.)civil\.ge$/,
      pathPattern: /^\/archives\/\d+\/?$/i,
      homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
      bodySelectors: ["article#the-post .entry-content.entry", "article#the-post .entry-content", "article .entry-content", "article .post-content", "article .content"],
      title: function(metadata) { return firstText(["h1.entry-title", "h1.post-title", "article h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title); },
      removalSelectors: [".post-components", ".post-bottom-meta", ".post-shortlink"],
      minBodyTextLength: 250
    },
    {
      hostPattern: /(^|\.)maroelamedia\.co\.(?:za|tz)$/,
      pathPattern: /^\/(?:nuus|debat)\/(?:[^/]+\/)+[^/]+\/?$/i,
      homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
      bodySelectors: [".entry-content", "article .entry-content", ".post-content", ".article-content", "[itemprop='articleBody']"],
      title: function(metadata) { return normalizeText(((metadata && metadata.title) || document.title || "").replace(/\s*-\s*Maroela Media\s*$/i, "")); },
      removalTextPatterns: [/^o wee, die gesang is uit!/i],
      minBodyTextLength: 250
    },
    {
      hostPattern: /(^|\.)newsit\.gr$/,
      homepagePath: /^\/?$/,
      body: function() {
        return composeProfileArticleRoot({
          leadSelectors: [".article-excerpt"],
          bodySelectors: [
            "article[id^='post-'] .inside-article .entry-content section",
            "article[id^='post-'] .entry-content section",
            "article .entry-content section",
            ".entry-content section"
          ]
        });
      },
      titleSelectors: [".entry-title", "article h1", "h1"],
      removalSelectors: [
        ".advert-block",
        ".share-inside-the-content",
        ".share-menu",
        ".sticky-container",
        "[id*='div-gpt-ad' i]",
        "[class*='newsletter' i]",
        "[class*='google' i]",
        "figure",
        "blockquote.twitter-tweet",
        "[data-twitter-extracted]"
      ],
      minBodyTextLength: 180,
      rewriteRoot: function(root) {
        root.querySelectorAll("p, div, span, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 220) return;
          if (/^(διαφήμιση|ακολουθήστε το newsit\.gr|προσθήκη του newsit\.gr ως προτεινόμενη πηγή στην google)$/i.test(text)) el.remove();
        });

        root.querySelectorAll("a").forEach(function(link) {
          link.replaceWith(document.createTextNode(link.textContent || ""));
        });
      }
    },
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
    },
    {
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
    }
  ];

  var WORDPRESS_DEDICATED_PROFILE_HOSTS = /(^|\.)(daryo\.uz|hatena\.blog|trend\.az)$/;

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
