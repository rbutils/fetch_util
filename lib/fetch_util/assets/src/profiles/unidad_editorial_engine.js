  function unidadEditorialEngineArticleContent(metadata, config) {
    config = config || {};
    if (!hostMatches(config.hostPattern)) return null;

    var body = unidadEditorialEngineArticleBody(config);
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    normalizePublicArticleAccessSignals(body, metadata, {
      minBodyTextLength: config.publicMinTextLength || 1200,
      minParagraphCount: 3,
      paragraphMinLength: 80,
      hardPaywallPattern: /(?:para seguir leyendo|contin[uú]a leyendo|lee este art[ií]culo completo|solo para suscriptores|contenido exclusivo para suscriptores)/i,
      removalSelectors: [
        "[class*='paywall' i]", "[id*='paywall' i]", "[data-paywall]",
        "[data-piano-offer]", "[class*='premium-wall' i]", "[class*='subscribe-wall' i]"
      ]
    });

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
