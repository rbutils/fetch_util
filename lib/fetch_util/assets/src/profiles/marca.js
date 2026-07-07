  function marcaArticleContent(metadata) {
    if (!hostMatches(/(^|\.)marca\.com$/)) return null;

    var body = marcaArticleBody();
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    if (marcaPublicBody(body)) marcaNormalizePaywallSignals();

    var root = document.createElement("article");
    var lead = document.querySelector(".ue-c-article__standfirst, .article-intro, .summary, .article__summary");
    if (lead) root.appendChild(safeDeepClone(lead, document));
    root.appendChild(safeDeepClone(body, document));

    return profileArticleContent(metadata, root, {
      title: firstText(["h1.ue-c-article__title", "h1.article-title", "h1"]),
      byline: firstText([".ue-c-article__byline", ".ue-c-article__author", ".article-author", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      cloneRoot: false,
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, [
          ".ue-c-article__share", ".ue-c-social-share", ".sharebar", "[class*='share' i]",
          ".ue-c-ad", "[class*='advert' i]", "[aria-roledescription='Publicidad']",
          ".ue-c-article__comments", "[class*='comment' i]",
          ".ue-c-article__related", "[class*='related' i]", "[class*='recommend' i]",
          ".ue-c-players-ranking-widget", "[class*='ranking-widget' i]", "[class*='scoreboard' i]",
          ".newsletter", "[class*='newsletter' i]",
          "[class*='paywall' i]", "[id*='paywall' i]", "[data-paywall]"
        ].join(", "));

        cleanRoot.querySelectorAll("p, div, span, section, aside").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (text.length > 280) return;
          if (/^(suscr[ií]bete|suscr[ií]bete aqu[ií]|contenido exclusivo|solo para suscriptores|inicia sesi[oó]n|hazte premium|premium|publicidad)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function marcaArticleBody() {
    return document.querySelector(".ue-c-article__body") ||
      document.querySelector("[data-section='articleBody']") ||
      document.querySelector(".article-body") ||
      document.querySelector("div.vcm-content") ||
      document.querySelector(".content-article") ||
      document.querySelector(".article-content") ||
      document.querySelector("div[itemprop='articleBody']") ||
      document.querySelector("[itemprop='articleBody']");
  }

  function marcaPublicBody(body) {
    var text = normalizeText(body.textContent || "");
    var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(p) {
      return normalizeText(p.textContent || "").length >= 80;
    }).length;

    return text.length >= 900 && paragraphs >= 3 && !marcaHardPaywallText(text);
  }

  function marcaHardPaywallText(text) {
    return /(?:para seguir leyendo|contin[uú]a leyendo|lee este art[ií]culo completo|solo para suscriptores|contenido exclusivo para suscriptores)/i.test(text || "");
  }

  function marcaNormalizePaywallSignals() {
    removeAll(document, [
      "[class*='paywall' i]", "[id*='paywall' i]", "[data-paywall]",
      "[data-piano-offer]", "[class*='premium-wall' i]", "[class*='subscribe-wall' i]"
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

  var marcaBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return marcaArticleContent(metadata) || marcaBaseHostAwareContent(metadata, pageText);
  };
