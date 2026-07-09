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
    normalizePublicArticleAccessSignals(body, metadata, {
      minBodyTextLength: 1200,
      minParagraphCount: 3,
      paragraphMinLength: 70,
      hardPaywallPattern: /(?:solo para suscriptores|contenido exclusivo para suscriptores|suscribite para seguir leyendo|para continuar leyendo|contin[uú]a leyendo con tu suscripci[oó]n)/i,
      removalSelectors: [
        "[data-piano-offer]",
        "[data-paywall]",
        "[class*='paywall' i]",
        "[id*='paywall' i]",
        "[class*='subscribe-wall' i]",
        "[class*='premium-wall' i]"
      ],
      signalRemovalSelectors: [
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
      ]
    });

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

  registerHostAwareProfile(true, clarinArticleContent);