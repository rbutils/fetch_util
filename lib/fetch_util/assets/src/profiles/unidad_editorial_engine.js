  function unidadEditorialEngineArticleContent(metadata, config) {
    config = config || {};
    if (!hostMatches(config.hostPattern)) return null;

    var body = unidadEditorialEngineArticleBody(config);
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    if (unidadEditorialEnginePublicBody(body, config)) unidadEditorialEngineNormalizePaywallSignals();

    var root = document.createElement("article");
    var lead = document.querySelector((config.leadSelectors || unidadEditorialEngineLeadSelectors()).join(", "));
    if (lead) root.appendChild(safeDeepClone(lead, document));
    root.appendChild(safeDeepClone(body, document));

    return profileArticleContent(metadata, root, {
      title: firstText(config.titleSelectors || unidadEditorialEngineTitleSelectors()),
      byline: firstText(config.bylineSelectors || unidadEditorialEngineBylineSelectors()) || metadata.byline,
      minTextLength: config.minTextLength || 250,
      cloneRoot: false,
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, unidadEditorialEngineRemovalSelectors(config).join(", "));
        unidadEditorialEngineRemovePaywallText(cleanRoot);
        if (typeof config.rewriteRoot === "function") config.rewriteRoot(cleanRoot);
      }
    });
  }

  function unidadEditorialEngineArticleBody(config) {
    var selectors = config.bodySelectors || [];
    for (var i = 0; i < selectors.length; i += 1) {
      var body = document.querySelector(selectors[i]);
      if (body) return body;
    }

    if (!config.sportParagraphFallback) return null;

    var sportParagraphs = document.querySelectorAll("article p.ft-text");
    if (!sportParagraphs.length) return null;

    var sportBody = document.createElement("div");
    sportParagraphs.forEach(function(paragraph) {
      sportBody.appendChild(safeDeepClone(paragraph, document));
    });
    return sportBody;
  }

  function unidadEditorialEnginePublicBody(body, config) {
    var text = normalizeText(body.textContent || "");
    var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(p) {
      return normalizeText(p.textContent || "").length >= 80;
    }).length;

    return text.length >= (config.publicMinTextLength || 1200) && paragraphs >= 3 && !unidadEditorialEngineHardPaywallText(text);
  }

  function unidadEditorialEngineHardPaywallText(text) {
    return /(?:para seguir leyendo|contin[uú]a leyendo|lee este art[ií]culo completo|solo para suscriptores|contenido exclusivo para suscriptores)/i.test(text || "");
  }

  function unidadEditorialEngineNormalizePaywallSignals() {
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

  function unidadEditorialEngineRemovalSelectors(config) {
    return [
      ".ue-c-article__share", ".ue-c-social-share", ".sharebar", "[class*='share' i]",
      ".ue-c-ad", "[class*='advert' i]", "[aria-roledescription='Publicidad']",
      ".ue-c-article__comments", "[class*='comment' i]",
      ".ue-c-article__related", "[class*='related' i]", "[class*='recommend' i]",
      ".newsletter", "[class*='newsletter' i]",
      "[class*='paywall' i]", "[id*='paywall' i]", "[data-paywall]"
    ].concat(config.extraRemovalSelectors || []);
  }

  function unidadEditorialEngineRemovePaywallText(cleanRoot) {
    cleanRoot.querySelectorAll("p, div, span, section, aside").forEach(function(el) {
      var text = normalizeText(el.textContent || "");
      if (text.length > 280) return;
      if (/^(suscr[ií]bete|suscr[ií]bete aqu[ií]|contenido exclusivo|solo para suscriptores|inicia sesi[oó]n|hazte premium|premium|publicidad)$/i.test(text)) el.remove();
    });
  }

  function unidadEditorialEngineLeadSelectors() {
    return [".ue-c-article__standfirst", ".ue-c-article__summary", ".article__summary", ".article-intro", ".summary"];
  }

  function unidadEditorialEngineTitleSelectors() {
    return ["h1.ue-c-article__title", "h1.article-title", "h1"];
  }

  function unidadEditorialEngineBylineSelectors() {
    return [".ue-c-article__byline", ".ue-c-article__author", ".article-author", "[rel='author']"];
  }
