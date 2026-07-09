  function folhaArticleContent(metadata) {
    if (!folhaArticlePage()) return null;

    var body = folhaArticleBody();
    if (!body) return null;
    normalizePublicArticleAccessSignals(body, metadata, {
      minBodyTextLength: 900,
      minParagraphCount: 3,
      paragraphMinLength: 70,
      hardPaywallPattern: /(?:conte[uú]do exclusivo|exclusivo para assinantes|assine para continuar|continue lendo com|conte[uú]do para assinantes)/i,
      removalSelectors: PUBLIC_ARTICLE_PAYWALL_SELECTORS.concat(["[data-piano-offer]"]),
      structuredDataMode: "remove"
    });

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

  registerHostAwareProfile(true, folhaArticleContent);