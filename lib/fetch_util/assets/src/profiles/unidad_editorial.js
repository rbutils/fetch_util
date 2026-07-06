  function unidadEditorialArticleContent(metadata) {
    if (!hostMatches(/(^|\.)(?:elmundo|expansion)\.es$/)) return null;

    var body = unidadEditorialArticleBody();
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    if (unidadEditorialPublicBody(body)) unidadEditorialNormalizePaywallSignals();

    var root = document.createElement("article");
    var lead = document.querySelector(".ue-c-article__standfirst, .ue-c-article__summary, .article__summary, .article-intro, .summary");
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
          ".newsletter", "[class*='newsletter' i]",
          "[class*='paywall' i]", "[id*='paywall' i]", "[data-paywall]"
        ].join(", "));

        cleanRoot.querySelectorAll("p, div, span, section, aside").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (text.length > 280) return;
          if (/^(suscr[ií]bete|suscr[ií]bete aqu[ií]|contenido exclusivo|solo para suscriptores|inicia sesi[oó]n|hazte premium|premium)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function unidadEditorialArticleBody() {
    return document.querySelector(".ue-c-article__body[data-section='articleBody']") ||
      document.querySelector(".ue-c-article__body") ||
      document.querySelector(".article-body") ||
      document.querySelector("#article-body") ||
      document.querySelector("div[itemprop='articleBody']") ||
      document.querySelector("[itemprop='articleBody']");
  }

  function unidadEditorialPublicBody(body) {
    var text = normalizeText(body.textContent || "");
    var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(p) {
      return normalizeText(p.textContent || "").length >= 80;
    }).length;

    return text.length >= 1200 && paragraphs >= 3 && !unidadEditorialHardPaywallText(text);
  }

  function unidadEditorialHardPaywallText(text) {
    return /(?:para seguir leyendo|contin[uú]a leyendo|lee este art[ií]culo completo|solo para suscriptores|contenido exclusivo para suscriptores)/i.test(text || "");
  }

  function unidadEditorialNormalizePaywallSignals() {
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

  function unidadEditorialHomepageContent(metadata) {
    if (!hostMatches(/(^|\.)(?:elmundo|expansion)\.es$/)) return null;
    if (!homepageRootPath()) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll(".ue-c-cover-content, article, section").forEach(function(card) {
      if (items.length >= 18) return;
      if (card.closest("header, nav, footer, aside, [class*='comment' i]")) return;

      var link = card.querySelector(".ue-c-cover-content__link[href], h1 a[href], h2 a[href], h3 a[href]");
      if (!link || link.closest("[class*='comment' i], .ue-c-cover-content__comments")) return;

      var href = link.getAttribute("href") || "";
      if (!/\/(?:\d{4}\/\d{2}\/\d{2}\/|[a-f0-9]{24}\.html|\d{2}_\d{4}_\d{8}_)/i.test(href)) return;

      var title = normalizeText(((link.querySelector(".ue-c-cover-content__headline, h1, h2, h3") || {}).textContent) || link.textContent || "");
      var url = absoluteUrl(href);
      if (!title || title.length < 18 || title.length > 220 || !url || seen[url]) return;
      if (/^(comentarios?|ver comentarios?|opinar|participa)$/i.test(title)) return;

      seen[url] = true;
      items.push({ text: title, url: url, detail: searchItemDetail(card, title) });
    });

    if (items.length < 4) return null;

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: items
    });
  }

  var unidadEditorialBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return unidadEditorialArticleContent(metadata) ||
      unidadEditorialHomepageContent(metadata) ||
      unidadEditorialBaseHostAwareContent(metadata, pageText);
  };
