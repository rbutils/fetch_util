  function rootCzArticleContent(metadata) {
    if (!rootCzArticlePage()) return null;

    var body = rootCzArticleBody();
    if (!body) return null;
    if (metadata) metadata.language = "";

    return profileArticleContent(metadata, body, {
      title: firstText([".design-title", "h1"]) || metadata.title,
      byline: firstText([".design-impressum__author", ".design-impressum a[rel='author']", ".design-impressum__content a"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "nav",
          "aside",
          ".comments",
          "[class*='comment' i]",
          "[class*='discussion' i]",
          "[class*='share' i]",
          "[class*='social' i]",
          "[class*='rating' i]",
          "[class*='advert' i]",
          "[class*='ad-detail' i]",
          "[class*='root-ad' i]",
          "[class*='selfpromo' i]",
          "[id*='google_ads' i]",
          "[id*='div-gpt' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, section, ul, li, a, span, h2, h3").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(počet nových komentářů\s*\d+|přidejte názor|líbí se vám článek\?|podpořte redakci|sdílet|sdílejte na facebooku|sdílejte na síti x)$/i.test(text)) el.remove();
          if (/^přidat mezi oblíbené zdroje na googlu$/i.test(text)) el.remove();
          if (/^reklama\b/i.test(text) && text.length < 400) el.remove();
        });
      }
    });
  }

  function rootCzArticlePage() {
    if (!hostMatches(/(^|\.)root\.cz$/)) return false;
    if (!/^\/clanky\//i.test(location.pathname || "")) return false;
    return !!rootCzArticleBody();
  }

  function rootCzArticleBody() {
    return composeProfileArticleRoot({
      leadSelectors: [
        ".mdl-article-perex .design-article__text",
        ".design-article__perex-content",
        ".design-article__perex"
      ],
      bodySelectors: [".detail__article", ".layout-article-content", ".article-text", "#article-content", "div.text", "[itemprop='articleBody']"]
    });
  }

  registerHostAwareProfile(true, rootCzArticleContent);
