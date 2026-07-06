  function abrilArticleContent(metadata) {
    if (!abrilArticlePage()) return null;

    var body = abrilArticleBody();
    if (!body) return null;
    if (!abrilVisiblePaywall()) abrilRemoveFalsePaywallIndicators();

    return profileArticleContent(metadata, body, {
      title: firstText([".post-header h1", "main h1", "article h1", "h1"]) || metadata.title,
      byline: firstText([".author-name", ".post-header .author", ".post-header [rel='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".accessibility-buttons",
          ".share-box",
          ".salvar-conteudo-materia",
          ".ads",
          ".abrAD",
          ".post-ads",
          ".after-text",
          ".noreadme-audima",
          ".abril-recirculacao-copa",
          "[class*='share' i]",
          "[class*='newsletter' i]",
          "[class*='recirculacao' i]",
          "[data-format='billboard']",
          "[data-ad-unit]"
        ].join(", "));

        abrilRemoveUtilityBlocks(root);
      }
    });
  }

  function abrilArticlePage() {
    if (!hostMatches(/(^|\.)abril\.com\.br$/)) return false;
    if (/^\/?$/i.test(location.pathname || "")) return false;
    return !!abrilArticleBody();
  }

  function abrilArticleBody() {
    return document.querySelector(".article-body") ||
      document.querySelector(".article-content") ||
      document.querySelector(".c-article__content") ||
      document.querySelector("section.content.readme-audima") ||
      document.querySelector("article .content") ||
      document.querySelector("main .content");
  }

  function abrilRemoveUtilityBlocks(root) {
    root.querySelectorAll("h2, h3").forEach(function(heading) {
      var text = normalizeText(heading.textContent || "");
      if (!/^(leia mais|em alta)$/i.test(text)) return;

      var next = heading.nextElementSibling;
      if (next && /^(ul|ol)$/i.test(next.tagName || "")) {
        next.remove();
      }
      heading.remove();
    });

    root.querySelectorAll("p, div, span, li").forEach(function(el) {
      var text = normalizeText(el.textContent || "");
      if (/^(compartilhe essa matéria:?|link copiado!?|continua após a publicidade|publicidade|tudo sobre a copa, em um só lugar|ver cobertura completa)$/i.test(text)) el.remove();
    });
  }

  function abrilRemoveFalsePaywallIndicators() {
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

  function abrilVisiblePaywall() {
    var text = normalizeText(document.body ? (document.body.innerText || document.body.textContent || "") : "").toLowerCase();
    return /conteúdo exclusivo|conteudo exclusivo|exclusivo para assinantes|assine para continuar|continue lendo com|conteúdo para assinantes|conteudo para assinantes/.test(text);
  }

  var abrilBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return abrilArticleContent(metadata) || abrilBaseHostAwareContent(metadata, pageText);
  };
