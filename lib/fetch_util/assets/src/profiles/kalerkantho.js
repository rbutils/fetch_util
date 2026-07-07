  var kalerKanthoArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)kalerkantho\.com$/,
    homepagePath: /^\/?$/,
    body: kalerKanthoArticleBody,
    titleSelectors: ["main h1", "h1", ".news-title", ".title"],
    bylineSelectors: ["main h1 + div span", "[class*='author' i]", "[class*='byline' i]"],
    publishedTime: function(metadata) { return metadata && metadata.publishedTime; },
    removalSelectors: [
      ".google-auto-placed",
      ".ads",
      ".advertisement",
      "ains",
      "ins",
      "iframe",
      "[id^='aswift_']",
      "[class*='share' i]",
      "[class*='social' i]",
      "[class*='related' i]",
      "[class*='moreAtticle' i] [data-id]"
    ],
    minBodyTextLength: 450,
    extra: { docsLike: true },
    rewriteRoot: function(root) {
      root.querySelectorAll("p, div, span, a, li").forEach(function(el) {
        var text = normalizeText(el.textContent || "");
        if (!text || text.length > 180) return;
        if (/^(আরও দেখুন|আরো পড়ুন|বাকি অংশ পড়ুন|ই-পেপার|সর্বশেষ|ট্রেন্ডিং)$/i.test(text)) el.remove();
      });
    }
  });

  function kalerKanthoArticlePage() {
    return !!kalerKanthoArticleContent();
  }

  function kalerKanthoArticleBody() {
    var primaryArea = document.querySelector(".col-12[class*='articleArea']") ||
      document.querySelector("[class*='articleArea']");
    if (kalerKanthoUsefulArticleNode(primaryArea)) return primaryArea;

    var selectors = [
      ".news-content",
      ".article-body",
      ".post-content",
      ".details-content",
      "article.news-details-content",
      "[itemprop='articleBody']"
    ];

    for (var i = 0; i < selectors.length; i++) {
      var node = document.querySelector(selectors[i]);
      if (kalerKanthoUsefulArticleNode(node)) return node;
    }

    return null;
  }

  function kalerKanthoUsefulArticleNode(node) {
    if (!node) return false;
    if (node.closest("header, nav, footer, aside")) return false;
    var text = normalizeText(node.innerText || node.textContent || "");
    if (text.length < 450) return false;
    return node.querySelectorAll("p").length >= 3 || node.querySelectorAll("article").length >= 2;
  }

  registerHostAwareProfile(true, kalerKanthoArticleContent);