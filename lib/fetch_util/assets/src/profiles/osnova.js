  function osnovaArticleContent(metadata) {
    if (!osnovaArticlePage()) return null;

    var body = osnovaArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["h1.content-title", "h1", ".content__title"]) || metadata.title,
      byline: firstText([".content-header-author__name", ".author__name", "[class*='author'] a"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".recommendations",
          ".content-list",
          ".content__aside",
          ".feed",
          "div[data-block='feed']",
          ".andropov-osnova-embed",
          ".block-osnova-embed",
          ".content--embed",
          ".content--short",
          ".booster",
          "[class*='booster']",
          "[data-gtm-click*='recommendations']"
        ].join(", "));

        root.querySelectorAll("a, p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(читать дальше|показать полностью|реклама|спецпроект)$/i.test(text) && text.length < 80) el.remove();
        });
      }
    });
  }

  function osnovaArticlePage() {
    if (!hostMatches(/(^|\.)(?:vc|tjournal|dk)\.ru$/)) return false;
    if (homepageRootPath()) return false;
    return !!osnovaArticleBody();
  }

  function osnovaArticleBody() {
    var candidates = Array.prototype.slice.call(document.querySelectorAll([
      ".entry > .content > .content__body",
      ".content:not(.content--short):not(.content--embed) > .content__body",
      ".entry-content",
      "div.l-island",
      ".layout__content article .content__body"
    ].join(", ")));

    for (var i = 0; i < candidates.length; i += 1) {
      var node = candidates[i];
      if (node.closest(".recommendations, .content-list, .feed, .content__aside, div[data-block='feed']")) continue;
      if (normalizeText(node.textContent || "").length >= 250) return node;
    }

    return null;
  }

  registerHostAwareProfile(true, osnovaArticleContent);