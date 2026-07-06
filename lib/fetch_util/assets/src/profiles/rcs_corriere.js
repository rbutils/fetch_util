  function rcsCorriereArticleContent(metadata) {
    if (!rcsCorriereArticlePage()) return null;

    var body = rcsCorriereArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: rcsCorriereArticleTitle(metadata, body),
      byline: firstText([
        ".author-art .writer",
        ".author-art",
        ".byline",
        "[rel='author']",
        "[itemprop='author']"
      ]) || metadata.byline,
      minTextLength: 300,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".widget-audio-article",
          ".box-audio",
          ".article-audio",
          ".sharebar",
          ".share-bar",
          ".social-share",
          ".article-share",
          ".adv",
          ".adv__content",
          ".advertising",
          ".banner",
          ".newsletter",
          ".paywall",
          ".piano",
          ".trc_rbox",
          ".taboola",
          ".comment",
          ".comments",
          ".discussion",
          ".scoreboard",
          "[class*='scoreboard' i]",
          "[class*='share' i]",
          "[id*='share' i]",
          "[data-mrf-recirculation]",
          "[data-testid*='share' i]"
        ].join(", "));

        root.querySelectorAll("p, div, span, button").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 220) return;
          if (/^(ascolta l'articolo|\d+\s*min|new|condividi|leggi anche|continua a leggere|pubblicit[àa]|abbonati|scegli corriere come fonte preferita)/i.test(text)) el.remove();
          if (/^(i\s*)?questo audio è generato in automatico/i.test(text)) el.remove();
          if (/^(portogallo|spagna)\d/i.test(text)) el.remove();
        });
      }
    });
  }

  function rcsCorriereArticlePage() {
    if (!rcsCorriereHost()) return false;
    if (homepageRootPath()) return false;
    return !!rcsCorriereArticleBody();
  }

  function rcsCorriereHost() {
    return hostMatches(/(^|\.)corriere\.it$/) ||
      hostMatches(/(^|\.)gazzetta\.it$/) ||
      hostMatches(/(^|\.)lastampa\.it$/);
  }

  function rcsCorriereArticleTitle(metadata, body) {
    var articleRoot = body.closest("section.body-article, article") || document;
    var titleNode = articleRoot.querySelector(".rs-article-title, .title-art-hp, .article-title, h1");
    return normalizeText((titleNode && titleNode.textContent) || (metadata && metadata.title));
  }

  function rcsCorriereArticleBody() {
    return document.querySelector(".rs-article-body") ||
      document.querySelector("#article-body") ||
      document.querySelector(".article-content") ||
      document.querySelector("div[itemprop='articleBody']") ||
      document.querySelector("[itemprop='articleBody']") ||
      document.querySelector("#content-to-read") ||
      document.querySelector("section.body-article") ||
      document.querySelector("article .body-article") ||
      document.querySelector("article");
  }

  var rcsCorriereBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return rcsCorriereArticleContent(metadata) || rcsCorriereBaseHostAwareContent(metadata, pageText);
  };
