  function telexArticleContent(metadata) {
    if (!telexArticlePage()) return null;

    var body = telexArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".single-article__content h1", "article h1", "h1"]) || metadata.title,
      byline: firstText(["[class*='author' i]", "[class*='byline' i]"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".top-section",
          ".top-shr",
          ".article-bottom",
          ".recommendation",
          ".article-hint",
          ".google-box",
          ".support-box__campaign",
          ".support-box__content",
          ".remp-banner",
          "#remp-campaign",
          "#article-endbox-campaign-content",
          "[class*='tooltip' i]",
          "[class*='options' i]",
          "[class*='share' i]",
          "[class*='audio' i]",
          "[class*='weather' i]",
          "[id*='weather' i]",
          "[src^='data:image/svg+xml']"
        ].join(", "));

        root.querySelectorAll("p, div, span, section, aside, li, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(hozzáadva a lejátszási listához|vágólapra másolva|másolás|megosztás)$/i.test(text)) el.remove();
          if (/^állítsd be a telexet megbízható forrásnak!?$/i.test(text)) el.remove();
          if (/^egy könyv, amit bárhová magaddal vihetsz$/i.test(text)) el.remove();
          if (/^kedvenceink$/i.test(text)) el.remove();
        });
      },
      postProcessMarkdown: function(markdown) {
        return markdown.replace(/^\s*(Hozzáadva a lejátszási listához|Vágólapra másolva|Másolás|Megosztás)\s*$/gim, "").trim();
      }
    });
  }

  function telexArticlePage() {
    if (!hostMatches(/(^|\.)telex\.hu$/)) return false;
    if (homepageRootPath()) return false;
    return !!telexArticleBody();
  }

  function telexArticleBody() {
    return document.querySelector(".article-html-content") ||
      document.querySelector(".article-body") ||
      document.querySelector(".article__body") ||
      document.querySelector(".article-text") ||
      document.querySelector("[class~='article_body_']") ||
      document.querySelector("[itemprop='articleBody']") ||
      document.querySelector("#cikk-content .content") ||
      document.querySelector(".single-article__content");
  }

  var telexBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return telexArticleContent(metadata) || telexBaseHostAwareContent(metadata, pageText);
  };
