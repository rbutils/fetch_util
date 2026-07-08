  var LEGAL_PROVISION_TITLE_PATTERN = /(?:constitution|constitutional|constitui[cç]?[aã]o|c[oó]digo|codigo|code|statute|act|law|regulation|ordinance|decree|treaty|convention)/i;
  var LEGAL_PROVISION_OFFICIAL_TITLE_PATTERN = /\b(?:civil|criminal|commercial|tax|labou?r|procedure|family|public|administrative)?\s*(?:code|statute|act|law|regulation|ordinance)\b/i;
  var LEGAL_PROVISION_MARKER_PATTERN = /(?:^|\s)(?:Art\.?|Article|Section|Sec\.?|§)\s*(?:\d+[ºª]?|[IVXLCDM]+)/gi;
  var LEGAL_PROVISION_STRUCTURAL_PATTERN = /\b(?:title|chapter|part|book|t[ií]tulo|cap[ií]tulo|se[cç][aã]o)\s+(?:[IVXLCDM]+|\d+)/gi;
  var LEGAL_PROVISION_TERMS_PATTERN = /(?:federal republic|rep[úu]blica federativa|republica federativa|civil rights|fundamental rights|legal provisions?|official gazette|promulgat|enacted|amended|paragraph|par[áa]grafo|paragrafo|inciso|subsection)/i;
  var LEGAL_PROVISION_OFFICIAL_TEXT_PATTERN = /\b(?:legal provisions?|federal law gazette|official gazette|version information|translation includes? the amendment|current status of the .* version|conditions governing use of this translation)\b/i;
  var LEGAL_PROVISION_PROFILE_OFFICIAL_TEXT_PATTERN = /\b(?:version information|translation provided by|translations? may not be updated|full citation|federal law gazette|table of contents)\b/i;
  var LEGAL_PROVISION_TRANSLATION_PATTERN = /\b(?:translation provided by|translated by|translation includes?|translations? may not be updated|updated by|revised and updated by)\b/i;
  var LEGAL_PROVISION_SECTION_MARKER_PATTERN = /(?:^|\s)(?:§|Section|Sec\.?|Article)\s*\d+/i;
  var LEGAL_PROVISION_BODY_START_PATTERN = /(?:^|\s)(?:Art\.?|Article|Section|Sec\.?|§)\s*(?:1|I)\b/i;

  function legalProvisionContext(options) {
    options = options || {};
    var root = options.root || null;
    var text = normalizeText(options.text || (root && root.textContent) || "");
    var title = normalizeText(options.title || document.title || "");
    var path = safeDecodeURI(options.path || (location && location.pathname) || "").toLowerCase();
    var titleContext = normalizeText([title, path].join(" ")).toLowerCase();
    var context = normalizeText([titleContext, text.slice(0, options.contextLimit || 4000)].join(" ")).toLowerCase();

    return {
      text: text,
      titleContext: titleContext,
      context: context,
      legalTitle: LEGAL_PROVISION_TITLE_PATTERN.test(context),
      officialStatuteTitle: LEGAL_PROVISION_OFFICIAL_TITLE_PATTERN.test(titleContext),
      officialTextSignals: LEGAL_PROVISION_OFFICIAL_TEXT_PATTERN.test(context),
      profileOfficialTextSignals: LEGAL_PROVISION_PROFILE_OFFICIAL_TEXT_PATTERN.test(text),
      translationAttribution: LEGAL_PROVISION_TRANSLATION_PATTERN.test(context),
      provisionMarkers: (text.match(LEGAL_PROVISION_MARKER_PATTERN) || []).length,
      structuralMarkers: (text.match(LEGAL_PROVISION_STRUCTURAL_PATTERN) || []).length,
      legalTerms: LEGAL_PROVISION_TERMS_PATTERN.test(text),
      numberedClauses: (text.match(/(?:^|\s)\(\d+\)|(?:^|\s)\([a-z]\)/gi) || []).length,
      sectionOrArticleMarker: LEGAL_PROVISION_SECTION_MARKER_PATTERN.test(text),
      bodyStartMatch: text.match(LEGAL_PROVISION_BODY_START_PATTERN)
    };
  }

  function scoreNode(node) {
    if (!node || cookieChromeNode(node)) return -Infinity;

    if (node.matches("[id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true']")) return -Infinity;

    var privacyTitle = node.querySelector("#ot-pc-title, #ot-pc-desc, [id^='ot-pc-' i], [class*='ot-pc' i], [class*='ot-accordion' i], [id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [id*='privacy' i], [class*='privacy' i], [id*='cookie' i], [class*='cookie' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true']");
    var privacyText = normalizeText((privacyTitle && privacyTitle.textContent) || node.textContent || "").slice(0, 500);
    if (privacyTitle && (cookieNoticeText(privacyText) || utilityHeadingText(privacyText))) return -Infinity;

    var text = textLength(node);
    if (text < 280) return -Infinity;

    if (typeof window !== "undefined" && window.getComputedStyle) {
      try {
        var style = window.getComputedStyle(node);
        if (style && (style.display === "none" || style.visibility === "hidden")) return -Infinity;
      } catch (e) {}
    }

    var paragraphs = node.querySelectorAll("p").length;
    var headings = node.querySelectorAll("h1, h2, h3").length;
    var proseNodes = node.querySelectorAll("p, li, blockquote, figure, table").length;
    var links = Array.prototype.reduce.call(node.querySelectorAll("a"), function(total, link) {
      return total + textLength(link);
    }, 0);
    var density = text > 0 ? links / text : 0;
    var utilityNodes = node.querySelectorAll("nav, aside, footer, [role='navigation'], [role='complementary'], [class*='comment' i], [id*='comment' i], [class*='related' i], [id*='related' i], [class*='recommend' i], [id*='recommend' i], [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i], [class*='share' i], [id*='share' i]").length;
    var normalizedText = normalizeText(node.textContent || "");
    var hint = ((node.className || "") + " " + (node.id || "")).toLowerCase();
    var bonus = 0;
    var strongArticleStructure = text >= 500 && (paragraphs >= 2 || headings >= 4 || proseNodes >= 4);
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);
    var textToLinkRatio = text / Math.max(links, 1);
    var ratioBonus = Math.min(300, Math.round(textToLinkRatio / 4));
    var utilityPenalty = utilityNodes > proseNodes ? Math.min(900, (utilityNodes - proseNodes) * 90) : 0;
    var densityPenalty = Math.round(density * (proseNodes >= 4 ? 240 : 400));

    if (/(article|content|entry|main|post|story|body|definition|meaning|sense|glossary|lexicon|pronunciation|answer)/.test(hint)) bonus += 180;
    if (/(comment|footer|nav|share|promo|related|sidebar|browse|translation|numerology|citation|quiz|cookie|privacy|subscription)/.test(hint)) bonus -= 220;
    if (!strongArticleStructure && promotionalRailNode(node, normalizedText, density)) bonus -= 4200;
    if (!strongArticleStructure && mixedArticleRailWrapper(node, normalizedText)) bonus -= 9000;
    if (!weatherPage && text < 1800 && weatherWidgetText(normalizedText)) return -Infinity;
    if (text < 1800 && legalFooterText(normalizedText) && (paragraphs < 4 || headings < 3)) return -Infinity;
    if (text < 2200 && /(discover more|newspapers|tourist destinations|travel guides?|travelogues)/i.test(normalizedText) && (paragraphs < 5 || headings < 4)) return -Infinity;

    return text + (paragraphs * 70) + (headings * 30) + bonus + ratioBonus - densityPenalty - utilityPenalty;
  }

  function genericArticleSelectors() {
    return [
      "main[role='main']",
      "article[role='main']",
      "[itemprop='articleBody']",
      "[class*='article-content' i]",
      "[class*='article-body' i]",
      "[class*='article-main' i]",
      "[class*='article__body' i]",
      "[class*='article__content' i]",
      "[class*='content-body' i]",
      "[class*='main-article' i]",
      "[class*='post-content' i]",
      "[class*='post-description' i]",
      "[class*='entry-content' i]",
      "[class*='story-content' i]",
      "[class*='news-content' i]",
      "[class*='wysiwyg' i]",
      "[class*='rich-text' i]",
      "main",
      "article",
      ".article-content",
      ".t-content",
      ".t-content--article",
      ".main-content",
      ".post-content",
      ".entry-content",
      ".story-body",
      ".news-content",
      ".article-body",
      "[data-article-body]",
      ".content-body",
      ".article__body",
      ".article",
      ".post",
      ".entry",
      ".content",
      ".main",
      "section",
      "div"
    ];
  }

  function cleanupGenericArticleRoot(root) {
    if (!root || !root.querySelectorAll) return root;

    removeAll(root, "#comments, #respond, .comments-area, .comment-list, .comments-section, .post-comments, .disqus-comment-count, [class*='comment-respond'], .sharedaddy, .share, .share-links, .share-buttons, .social-sharing, .social-buttons, [class*='share' i], [id*='share' i], [class*='related' i], [id*='related' i], [class*='recommend' i], [id*='recommend' i], [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i], [class*='advert' i], [id*='advert' i], [class*='promo' i], [id*='promo' i], [class*='adslot' i], [id*='adslot' i], [data-ad], [data-ads]");
    stripNavigationLeaks(root);
    stripRelatedSectionsByHeading(root);

    return root;
  }

  function fallbackContent() {
    var legalProvision = legalProvisionContent();
    if (legalProvision) return legalProvision;

    var selectors = genericArticleSelectors();
    var candidates = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        candidates.push(node);
      });
    });

    var best = candidates.reduce(function(current, node) {
      var scoringNode = cleanClone(node);
      cleanupGenericArticleRoot(scoringNode);
      var score = scoreNode(scoringNode);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    var node = best && best.score > -Infinity ? best.node : document.body;
    var clone = cleanClone(node);
    cleanupGenericArticleRoot(clone);
    var text = normalizeText(clone.textContent);

    return {
      title: document.title,
      byline: null,
      excerpt: text.slice(0, 280) || null,
      siteName: location.hostname,
      publishedTime: null,
      html: clone.innerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article"
    };
  }

  function legalProvisionContent() {
    var structuredRoot = structuredLegalTextRoot();
    var provisionRoot = document.querySelector("#viewLegSnippet, .viewLegSnippet, .LegislationSection, .legislation-section, [class*='LegislationSection' i], #viewLegContents, .viewLegContents") || structuredRoot;
    if (!provisionRoot) return null;

    var pageText = normalizeText(document.body && document.body.textContent || "");
    var provisionText = normalizeText(provisionRoot.textContent || "");
    var legalContext = legalProvisionContext({ root: provisionRoot, text: provisionText });
    var structuralContext = document.querySelector("#changesOverTime, #legNav, #breadCrumb, .legContent, [id*='legislation' i], [class*='legislation' i]");
    var legislationChrome = /\b(what version|changes to legislation|timeline of changes|plain view|print options|opening options)\b/i.test(pageText);

    if (provisionText.length < 250) return null;
    if (!structuredRoot && !structuralContext && !legislationChrome) return null;
    if (legalContext.numberedClauses < 2 && !/\b(section|article|regulation|schedule)\s+\d+\b/i.test(provisionText)) return null;

    var clone = cleanClone(provisionRoot);
    var title = document.querySelector("#pageTitle, h1") || null;
    var heading = clone.querySelector("h1, h2, h3") || null;
    var text = normalizeText(clone.textContent || "");

    return {
      title: normalizeText((title && title.textContent) || document.title),
      byline: null,
      excerpt: text.slice(0, 280) || null,
      siteName: location.hostname,
      publishedTime: null,
      html: (heading ? "" : title ? title.outerHTML : "") + clone.innerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article",
      legalProvision: true
    };
  }

  function structuredLegalTextRoot() {
    var root = document.querySelector("text .text .section, text .section, [class~='text'] > .section");
    if (!root) return null;

    var text = normalizeText(root.textContent || "");
    var hasLegalNotes = !!document.querySelector("notes, [id*='notes' i], [class*='notes' i]");
    var legalContext = legalProvisionContext({ text: text, title: document.title || "" });
    var hasStatutoryMarkers = /\b(?:U\.S\.\s+Code|Code|Statute|Act|Section|§)\b/i.test(document.title || "") || legalContext.sectionOrArticleMarker;

    if (text.length < 250 || !hasLegalNotes || !hasStatutoryMarkers || legalContext.numberedClauses < 2) return null;
    return root;
  }

  function weatherWidgetText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (!/(ve[ðd]ursp[áa]|weather forecast|forecast for the next|forecast for)/i.test(normalized)) return false;

    var weatherHits = normalized.match(/\b(ve[ðd]ursp[áa]|hiti|[úu]rkoma|vindur|frost|rigning|sk[ýy]ja[ðd]|temperature|precipitation|wind|rain|snow|storm)\b/ig) || [];
    return weatherHits.length >= 4;
  }

  function preferFallbackContent(primary, fallback) {
    if (!primary) return fallback;
    if (!fallback || !primary.readerMode) return primary;

    var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    var primaryText = normalizeText(primary.markdown || primary.textContent || "");
    if (mediaWikiLike && primaryText.length >= 800) return primary;

    var fallbackText = normalizeText(fallback.markdown || fallback.textContent || "");
    var primaryRoot = document.createElement("div");
    var fallbackRoot = document.createElement("div");
    primaryRoot.innerHTML = primary.html || "";
    fallbackRoot.innerHTML = fallback.html || "";
    var primaryParagraphs = primaryRoot.querySelectorAll("p, li").length;
    var fallbackParagraphs = fallbackRoot.querySelectorAll("p, li").length;
    var fallbackLinkText = Array.prototype.reduce.call(fallbackRoot.querySelectorAll("a[href]"), function(total, link) {
      return total + textLength(link);
    }, 0);
    var fallbackLinkDensity = fallbackText.length > 0 ? fallbackLinkText / fallbackText.length : 0;
    var adLikePrimary = /\b(oglas|advertisement|sponsored|ad)\b/i.test(primaryText.slice(0, 160));
    var footerLikePrimary = legalFooterText(primaryText);
    var weatherLikePrimary = weatherWidgetText(primaryText);
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);

    if (!fallbackText) return primary;
    if (fallback.legalProvision) return fallback;
    if (primaryText.length < 4000 &&
        fallbackText.length >= Math.max(1800, primaryText.length * 3) &&
        fallbackParagraphs >= Math.max(8, primaryParagraphs + 5) &&
        fallbackLinkDensity < 0.28) {
      return fallback;
    }
    if (substantialArticleContent(primary)) return primary;

    if (weatherLikePrimary && !weatherPage && fallbackText.length >= Math.max(900, primaryText.length * 2)) {
      return fallback;
    }

    if (promotionalRailContent(primary) && substantialArticleContent(fallback) && fallbackText.length >= 1200 && fallbackLinkDensity < 0.25) {
      return fallback;
    }

    if (footerLikePrimary && fallbackText.length >= Math.max(1000, primaryText.length * 2)) {
      return fallback;
    }

    if (substantialArticleContent(fallback) &&
        (primaryText.length < 240 || adLikePrimary) &&
        fallbackText.length >= Math.max(600, primaryText.length * 3)) {
      return fallback;
    }

    return primary;
  }

  function promotionalRailNode(node, text, linkDensity) {
    var hint = ((node.className || "") + " " + (node.id || "")).toLowerCase();
    if (!/(sidebar|rail|aside|promo|cta|recent|popular|related)/.test(hint) && !/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.querySelectorAll("p").length >= 8 && linkDensity < 0.18 && !/(sidebar|rail|aside)/.test(hint)) return false;
    return linkDensity >= 0.18 || node.querySelectorAll("a[href]").length >= 4;
  }

  function mixedArticleRailWrapper(node, text) {
    if (!/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.matches && node.matches("article, [itemprop='articleBody']")) return false;

    return Array.prototype.some.call(node.querySelectorAll("article, [itemprop='articleBody'], [class*='article' i], [class*='content' i], [class*='post' i]"), function(child) {
      if (child === node || child.querySelectorAll("a[href]").length >= 4) return false;
      return textLength(child) >= 1200 && child.querySelectorAll("p").length >= 5;
    });
  }

  function promotionalRailContent(content) {
    if (!content || content.contentType !== "article") return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;

    return promotionalRailNode(root, text, linkDensity);
  }

  function recipeStructuredDataContent(metadata) {
    var recipe = structuredDataNode(["Recipe"]);
    if (!recipe) return null;

    var ingredients = asArray(recipe.recipeIngredient).map(function(item) {
      return typeof item === "string" ? normalizeText(item) : entityText(item);
    }).filter(Boolean);
    var instructions = [];

    function collectInstructions(value) {
      if (!value) return;
      if (Array.isArray(value)) {
        value.forEach(collectInstructions);
        return;
      }
      if (typeof value === "string") {
        var text = normalizeText(value);
        if (text) instructions.push(text);
        return;
      }
      if (typeof value !== "object") return;

      if (value.itemListElement) {
        collectInstructions(value.itemListElement);
        return;
      }

      var text = entityText(value);
      if (text) instructions.push(text);
    }

    collectInstructions(recipe.recipeInstructions);

    if (ingredients.length + instructions.length < 3) return null;

    var details = [
      recipe.recipeYield ? "Yield: " + entityText(recipe.recipeYield) : null,
      recipe.prepTime ? "Prep: " + normalizeText(recipe.prepTime) : null,
      recipe.cookTime ? "Cook: " + normalizeText(recipe.cookTime) : null,
      recipe.totalTime ? "Total: " + normalizeText(recipe.totalTime) : null
    ].filter(Boolean);
    var sections = [];
    var title = entityName(recipe.name || recipe.headline) || metadata.title || document.title;
    var description = entityText(recipe.description) || metadata.excerpt;

    if (title) sections.push("# " + title);
    if (details.length) sections.push(details.map(function(item) {
      return "- " + item;
    }).join("\n"));
    if (description) sections.push(description);
    if (ingredients.length) {
      sections.push("## Ingredients\n\n" + ingredients.slice(0, 25).map(function(item) {
        return "- " + item;
      }).join("\n"));
    }
    if (instructions.length) {
      sections.push("## Instructions\n\n" + instructions.slice(0, 20).map(function(item, index) {
        return (index + 1) + ". " + item;
      }).join("\n"));
    }

    var markdown = sections.join("\n\n").trim();

    return {
      title: title,
      byline: entityName(recipe.author) || null,
      excerpt: description || null,
      siteName: metadata.siteName || location.hostname,
      publishedTime: recipe.datePublished || metadata.publishedTime || null,
      html: "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article"
    };
  }

  function readabilityContent() {
    if (typeof Readability !== "function") return null;

    try {
      var clone = safeReadableDocumentClone();
      cleanupCookieChrome(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      var article = new Readability(clone).parse();
      if (!article || !article.content) return null;

      return {
        title: article.title || document.title,
        byline: article.byline || null,
        excerpt: article.excerpt || null,
        siteName: article.siteName || location.hostname,
        publishedTime: article.publishedTime || null,
        html: article.content,
        textContent: article.textContent || "",
        readerMode: true,
        contentType: "article"
      };
    } catch (_error) {
      // Fall through to the shared article/list heuristics instead of aborting.
      return null;
    }
  }
