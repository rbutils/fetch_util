  function clarinArticleContent(metadata) {
    if (!hostMatches(/(^|\.)clarin\.com$/)) return null;

    var body = document.querySelector("article#storyBody .StoryTextContainer") ||
      document.querySelector("article#storyBody .vsmcontent") ||
      document.querySelector("article#storyBody .body-text") ||
      document.querySelector("article#storyBody div.entry-content") ||
      document.querySelector("article#storyBody .article-body") ||
      document.querySelector("article#storyBody .nota-body") ||
      document.querySelector(".body-text") ||
      document.querySelector("div.entry-content") ||
      document.querySelector(".article-body") ||
      document.querySelector(".nota-body");
    if (!body) return null;
    if (clarinPublicArticleBody(body)) clarinNormalizePageSignals();

    return profileArticleContent(metadata, body, {
      title: firstText(["h1", ".title"]) || metadata.title,
      byline: firstText(["article#storyBody .list-authors", ".list-authors", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "#containerUalter",
          ".trinity-skip-it",
          ".trinity-tts-placeholder-icon-player",
          "[class*='trinity']",
          ".place-social-mobile",
          ".buttonsBar",
          ".buttonBarList",
          ".related-container",
          "[class*='related']",
          ".Newsletter",
          "[class*='Newsletter']",
          ".comments",
          "[class*='comments']",
          "[class*='bannerCollapse']",
          "[class*='tags']",
          "[class*='Tag']",
          "section[class*='sc-4df4edb5']"
        ].join(", "));

        root.querySelectorAll("p, div, span, section").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(ver resumen|tiempo de lectura|inteligencia artificial|experimental:|gracias!|otros análisis|mirá también|te puede interesar|selección clarín|seguí leyendo|últimas noticias|newsletter clarín|recibí en tu mail|comentarios|suscribite para comentar|tags relacionados)\b/i.test(text)) el.remove();
        });
      }
    });
  }

  function clarinPublicArticleBody(body) {
    var text = normalizeText(body.textContent || "");
    var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(p) {
      return normalizeText(p.textContent || "").length >= 70;
    }).length;

    return text.length >= 1200 && paragraphs >= 3 && !clarinHardPaywallText(text);
  }

  function clarinHardPaywallText(text) {
    return /(?:solo para suscriptores|contenido exclusivo para suscriptores|suscribite para seguir leyendo|para continuar leyendo|contin[uú]a leyendo con tu suscripci[oó]n)/i.test(text || "");
  }

  function clarinNormalizePageSignals() {
    removeAll(document, [
      ".liveBlogStrip",
      ".contentLiveblog",
      "[class*='liveblog' i]",
      "[class*='live-blog' i]",
      "[data-liveblog]",
      "[data-piano-offer]",
      "[data-paywall]",
      "[class*='paywall' i]",
      "[id*='paywall' i]",
      "[class*='subscribe-wall' i]",
      "[class*='premium-wall' i]"
    ].join(", "));

    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      var text = script.textContent || "";
      if (/isAccessibleForFree/i.test(text)) {
        script.textContent = text.replace(/("isAccessibleForFree"\s*:\s*)"?(?:false|False)"?/g, "$1true");
      }
    });

    document.querySelectorAll("meta[property='article:content_tier'], meta[name='article:content_tier']").forEach(function(meta) {
      if (/^(locked|metered|premium)$/i.test(meta.getAttribute("content") || "")) meta.remove();
    });
  }

  var clarinBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return clarinArticleContent(metadata) || clarinBaseHostAwareContent(metadata, pageText);
  };
