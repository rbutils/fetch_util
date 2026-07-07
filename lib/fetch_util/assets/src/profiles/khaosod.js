  function khaosodArticleContent(metadata) {
    if (!khaosodArticlePage()) return null;

    var body = khaosodVisibleArticleBody() || khaosodRestArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".udsg__main-title", ".title-news", "article h1", "main h1", "h1"]) || (metadata && metadata.title),
      byline: firstText([".author", ".byline", "[rel='author']"]) || (metadata && metadata.byline),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".ads_position_wrapper",
          ".udgal-desc",
          ".trc_related_container",
          ".tbl-explore-more-overlay",
          ".share",
          ".social",
          "[class*='advert' i]",
          "[class*='sponsor' i]",
          "[id*='taboola' i]",
          "[id*='ad-' i]"
        ].join(", "));
      }
    });
  }

  function khaosodArticlePage() {
    if (!hostMatches(/(^|\.)khaosod\.co\.th$/)) return false;
    if (homepageRootPath()) return false;
    return /\/news_\d+\/?$/i.test(location.pathname || "");
  }

  function khaosodVisibleArticleBody() {
    var selectors = [
      ".article-content",
      ".news-content",
      "div.news-detail",
      ".story-body",
      ".entry-content",
      "[itemprop='articleBody']"
    ];

    for (var i = 0; i < selectors.length; i++) {
      var node = document.querySelector(selectors[i]);
      if (node && normalizeText(node.textContent || "").length >= 250) return node;
    }
    return null;
  }

  function khaosodRestArticleBody() {
    var match = (location.pathname || "").match(/news_(\d+)\/?$/i);
    if (!match) return null;

    var payload = khaosodRestPost(match[1]);
    var html = payload && payload.content && payload.content.rendered;
    if (!html) return null;

    var root = document.createElement("div");
    root.innerHTML = html;
    if (normalizeText(root.textContent || "").length < 250) return null;
    return root;
  }

  function khaosodRestPost(postId) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", "/wp-json/wp/v2/posts/" + postId, false);
      xhr.send(null);
      if (xhr.status < 200 || xhr.status >= 300 || !xhr.responseText) return null;
      return JSON.parse(xhr.responseText);
    } catch (e) {
      return null;
    }
  }

  registerHostAwareProfile(true, khaosodArticleContent);