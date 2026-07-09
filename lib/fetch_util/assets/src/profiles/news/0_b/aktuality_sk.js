  function aktualitySkArticleContent(metadata) {
    if (!hostMatches(/(^|\.)aktuality\.sk$/)) return null;

    var body = document.querySelector("#articleContent[itemprop='articleBody'], [itemprop='articleBody'], .article-body, .entry-content");
    if (!body) return null;

    var root = document.createElement("article");
    var article = document.querySelector("article#article") || body.closest("article") || document;

    ["#article-headline", "article h1", "h1"].some(function(selector) {
      var node = article.querySelector(selector) || document.querySelector(selector);
      if (!node) return false;
      root.appendChild(safeDeepClone(node, document));
      return true;
    });

    ["#perex-id", ".article-perex", "[itemprop='description']"].some(function(selector) {
      var node = article.querySelector(selector) || document.querySelector(selector);
      if (!node || normalizeText(node.textContent || "").length < 40) return false;
      root.appendChild(safeDeepClone(node, document));
      return true;
    });

    root.appendChild(safeDeepClone(body, document));

    return profileArticleContent(metadata, root, {
      title: firstText(["#article-headline", "article h1", "h1"]) || metadata.title,
      byline: firstText([".author-box .author-name", ".author-box [rel='author']", "[itemprop='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(clone) {
        removeAll(clone, [
          "#tp-inline-template",
          ".tp-container-inner",
          "one-page-order",
          "#pay-content-app",
          "iframe[src*='piano.io']",
          "#bw_premium_article",
          ".beyondwords-player",
          "[class*='share' i]",
          "[class*='save-article' i]",
          ".article-object-link",
          ".article-object-list",
          "#recommendation-box-piano",
          ".article-related-box",
          ".cx-flex-module",
          "[class*='related' i]",
          "[class*='discussion' i]"
        ].join(", "));

        clone.querySelectorAll("p, div, span").forEach(function(node) {
          var text = normalizeText(node.textContent || "");
          if (/^(listen to this article|uložiť článok|zdieľať článok|diskusia\s*\/\s*\d*)$/i.test(text)) node.remove();
          if (/^prečítajte si tiež:?$/i.test(text)) node.remove();
        });
      }
    });
  }

  registerHostAwareProfile(true, aktualitySkArticleContent);