  function agoraWyborczaContent(metadata) {
    if (!agoraWyborczaHost()) return null;

    var body = agoraWyborczaArticleBody();
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    agoraWyborczaMarkPaywall();

    var root = document.createElement("article");
    var header = document.querySelector(".article--header, .article_header, header.metadata--article");
    if (header) root.appendChild(safeDeepClone(header, document));
    root.appendChild(safeDeepClone(body, document));

    return profileArticleContent(metadata, root, {
      title: firstText(["h1.metadata--title", ".article_title", ".title", "h1"]) || metadata.title,
      byline: firstText([".metadata--author", ".article--author", "[class*='author' i]", "[rel='author']"]) || metadata.byline,
      minTextLength: 220,
      cloneRoot: false,
      extra: function() {
        return { packagePage: agoraWyborczaPaywallVisible() };
      },
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, [
          "#message",
          "#info-adblock",
          "#info-ups",
          "script",
          "style",
          "svg",
          ".msg-container",
          ".article--social-top",
          ".social",
          ".tags",
          ".article-audio",
          ".article--precontent",
          ".article--underlead",
          ".article--comments",
          ".comments",
          ".comment",
          ".newsletter",
          "[class*='newsletter' i]",
          "[class*='recommend' i]",
          "[class*='related' i]",
          "[class*='advert' i]",
          "[id*='advert' i]"
        ].join(", "));

        cleanRoot.querySelectorAll("p, div, span, a, h1, h2").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(wyłącz adblocka\/ublocka|aby czytać nasze artykuły wyłącz adblocka|ups!|nieznany błąd|posłuchaj|sprawdź ofertę|zaloguj się)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function agoraWyborczaHost() {
    return hostMatches(/(^|\.)wyborcza\.pl$/) ||
      hostMatches(/(^|\.)gazeta\.pl$/);
  }

  function agoraWyborczaArticleBody() {
    return document.querySelector(".mrf-article-body") ||
      document.querySelector(".article_body") ||
      document.querySelector("div.articleBody") ||
      document.querySelector(".art_content") ||
      document.querySelector(".article-inner") ||
      document.querySelector("section.article") ||
      document.querySelector("[itemprop='articleBody']");
  }

  function agoraWyborczaMarkPaywall() {
    if (!agoraWyborczaPaywallVisible()) return;
    if (document.querySelector("[data-paywall='agora-wyborcza']")) return;

    var paywall = document.createElement("div");
    paywall.setAttribute("data-paywall", "agora-wyborcza");
    paywall.hidden = true;
    paywall.textContent = "Wybierz prenumeratę, by czytać to, co Cię ciekawi";
    document.body.appendChild(paywall);
  }

  function agoraWyborczaPaywallVisible() {
    var found = false;
    document.querySelectorAll(".cap-message, .article--content-fadeout, [class*='paid' i], [class*='subscription' i]").forEach(function(marker) {
      var text = normalizeText(marker && marker.textContent);
      if (/wybierz prenumeratę|sprawdź ofertę|prenumerata|paid:\s*'false'|pozostało.*artykuł/i.test(text)) found = true;
    });
    return found;
  }

  var agoraWyborczaBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return agoraWyborczaContent(metadata) || agoraWyborczaBaseHostAwareContent(metadata, pageText);
  };
