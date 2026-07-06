  function folhaArticleContent(metadata) {
    if (!folhaArticlePage()) return null;

    var body = folhaArticleBody();
    if (!body) return null;
    folhaRemovePaywallIndicators();

    return profileArticleContent(metadata, body, {
      title: firstText(["main h1", "article h1", "h1"]) || metadata.title,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".c-more-options",
          ".c-newsletter",
          ".gallery-widget",
          ".js-gallery-widget",
          ".gallery-widget-share-container",
          ".c-loading",
          ".ads",
          ".advertising",
          "[class*='advertising']",
          "[class*='newsletter']",
          "[class*='share']",
          "[data-ad-unit]"
        ].join(", "));

        root.querySelectorAll("p, div, span, li").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(carregando|compartilhe|voltar|ver novamente|copiar link|ícone (facebook|whatsapp|x|linkedin|de envelope|de link))$/i.test(text)) el.remove();
        });
      }
    });
  }

  function folhaArticlePage() {
    if (!hostMatches(/(^|\.)folha\.uol\.com\.br$/)) return false;
    if (!/\.shtml(?:$|[?#])/i.test(location.pathname || "")) return false;
    return !!folhaArticleBody();
  }

  function folhaArticleBody() {
    return document.querySelector(".c-news__body") ||
      document.querySelector(".article-content") ||
      document.querySelector("[itemprop='articleBody']") ||
      document.querySelector("div[data-tda][data-news-content-text]");
  }

  function folhaRemovePaywallIndicators() {
    removeAll(document, [
      "meta[property='article:content_tier']",
      "meta[name='article:content_tier']",
      "[data-piano-offer]",
      "[data-paywall]",
      "[class*='paywall' i]",
      "[id*='paywall' i]",
      "[class*='subscribe-wall' i]",
      "[class*='premium-wall' i]",
      "[class*='piano-offer' i]"
    ].join(", "));

    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      if (/isAccessibleForFree/i.test(script.textContent || "")) script.remove();
    });
  }

  var folhaBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return folhaArticleContent(metadata) || folhaBaseHostAwareContent(metadata, pageText);
  };
