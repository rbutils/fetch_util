  function smeSkArticleContent(metadata) {
    if (!smeSkArticlePage()) return null;
    if (metadata) metadata.language = "";

    var body = document.querySelector(".article-body.js-article-body") ||
      document.querySelector(".article-body") ||
      document.querySelector("[itemprop='articleBody']");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: smeSkArticleTitle(metadata),
      byline: metadata.byline || firstText([".author-tile__name", "[rel='author']", ".article-author"]),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".ad-position",
          ".sme-banner",
          ".js-article-share",
          ".js-audio-player",
          ".article-audio",
          ".article-list",
          ".article-tile",
          ".pb_holder",
          ".discussion",
          ".js-discussion",
          "[class*='discussion' i]",
          "[class*='related' i]",
          "[class*='newsletter' i]",
          "[class*='banner' i]",
          "[class*='ad-' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, span, h2, h3, h4").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(sme audio|playlist|vypočuť článok|zdieľať|diskusia|reklama|súvisiace články)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function smeSkArticlePage() {
    if (!hostMatches(/(^|\.)sme\.sk$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector(".article-body.js-article-body, .article-body, [itemprop='articleBody']");
  }

  function smeSkArticleTitle(metadata) {
    return firstText([".article-head h1", ".heading--article", "article h1", "h1"]) ||
      normalizeText((metadata && metadata.title) || document.title);
  }

  var smeSkBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return smeSkArticleContent(metadata) || smeSkBaseHostAwareContent(metadata, pageText);
  };
