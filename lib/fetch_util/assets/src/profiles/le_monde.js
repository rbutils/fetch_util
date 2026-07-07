  function leMondeArticleContent(metadata) {
    if (!hostMatches(/(^|\.)lemonde\.fr$/)) return null;

    var body = leMondeArticleBody();
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    var offered = leMondeOfferedArticle();
    if (offered) {
      normalizePublicArticleAccessSignals(body, metadata, {
        minBodyTextLength: 350,
        minParagraphCount: 3,
        paragraphMinLength: 60,
        removalSelectors: [
          "#js-modal-gifted-url",
          ".article__gift-modal",
          ".paywall",
          ".js-paywall",
          "[class*='paywall' i]",
          "[id*='paywall' i]"
        ],
        textRemovalPattern: /cet article vous est offert|pour lire gratuitement cet article réservé aux abonnés|article réservé aux abonnés|la suite est réservée à nos abonnés/i,
        textRemovalMaxLength: 260
      });
    }

    var root = document.createElement("article");
    var lead = document.querySelector(".article__desc, .article__lead, .article__standfirst");
    if (lead) root.appendChild(safeDeepClone(lead, document));
    root.appendChild(safeDeepClone(body, document));

    return profileArticleContent(metadata, root, {
      title: firstText(["h1.article__title", ".article__title", "h1"]) || metadata.title,
      byline: firstText([".article__author", ".meta__author", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      cloneRoot: false,
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, [
          "#js-modal-gifted-url",
          ".article__gift-modal",
          ".paywall",
          ".js-paywall",
          "[class*='paywall' i]",
          "[id*='paywall' i]",
          ".article__siblings",
          ".article__reactions",
          ".article__share",
          ".meta__social",
          ".services",
          "[data-module*='newsletter' i]",
          "[data-module*='recommend' i]"
        ].join(", "));

        cleanRoot.querySelectorAll("p, div, span, figcaption").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(article réservé aux abonnés|la suite est réservée|il vous reste \d+(?:[,.]\d+)?% de cet article à lire|se connecter|s’abonner|s'abonner)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function leMondeArticleBody() {
    return document.querySelector("article.article__content") ||
      document.querySelector(".article__content") ||
      document.querySelector(".article-content") ||
      document.querySelector("[itemprop='articleBody']");
  }

  function leMondeOfferedArticle() {
    var marker = document.querySelector("#js-modal-gifted-url, .article__gift-modal");
    var text = normalizeText((marker && marker.textContent) || "");
    return /cet article vous est offert/i.test(text);
  }

  registerHostAwareProfile(true, leMondeArticleContent);