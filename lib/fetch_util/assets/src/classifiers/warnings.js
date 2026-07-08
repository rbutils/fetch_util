  // Strip combining diacritical marks so "rząd" → "rzad", "ğöü" → "gou", etc.
  function stripDiacritics(str) {
    if (typeof str.normalize === "function") return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    // Manual fallback for environments without normalize (legacy)
    return str.replace(/[àáâãäåæ]/g, "a").replace(/[èéêë]/g, "e").replace(/[ìíîï]/g, "i")
      .replace(/[òóôõöø]/g, "o").replace(/[ùúûü]/g, "u").replace(/[ýÿ]/g, "y")
      .replace(/[ñ]/g, "n").replace(/[çć]/g, "c").replace(/[šś]/g, "s").replace(/[žźż]/g, "z")
      .replace(/[đ]/g, "d").replace(/[łĺ]/g, "l").replace(/[ř]/g, "r").replace(/[ťț]/g, "t")
      .replace(/[ğ]/g, "g").replace(/[ąă]/g, "a").replace(/[ęě]/g, "e").replace(/[ıİ]/g, "i")
      .replace(/[ůű]/g, "u").replace(/[őö]/g, "o").replace(/[ń]/g, "n");
  }

  function containsNonLatinScript(text) {
    return /[\u0370-\u03FF\u0400-\u04FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\u0900-\u097F\u0980-\u09FF\u0E00-\u0E7F\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]/.test(text || "");
  }

  function slugKeywords() {
    var text = stripDiacritics(safeDecodeURI(location.pathname || "").toLowerCase()).replace(/[^a-z0-9]+/g, " ");
    return text.split(/\s+/).filter(function(token) {
      return token.length >= 3 && !/^(questions|question|about|docs|wiki|html|index|start|journey|get|your|with|from|the|and|for|dictionary|definition|definitions|browse|category|recipes|recipe|english|search|translate|translation|pronunciation|thesaurus)$/.test(token) && !/^\d+$/.test(token);
    });
  }

  function patentPublicationIds(text) {
    var source = safeDecodeURI(text || "").toUpperCase();
    var matches = source.match(/\b(?:WO|US|EP|JP|CN|KR|CA|AU)\s*\/?\s*\d{4}\s*\/?\s*\d{3,7}\s*[A-Z]?\d?\b/g) || [];
    return matches.map(function(match) {
      return match.replace(/[^A-Z0-9]/g, "");
    }).filter(function(value, index, all) {
      return value.length >= 8 && all.indexOf(value) === index;
    });
  }

  function patentPublicationIdMatchesContent(text) {
    var urlText = [location.href || "", location.pathname || "", location.search || ""].join(" ");
    var urlIds = patentPublicationIds(urlText);
    if (!urlIds.length) return false;

    var contentIds = patentPublicationIds(text || "");
    return urlIds.some(function(id) { return contentIds.indexOf(id) !== -1; });
  }

  // Detect language indicated by URL path segments like /de/, /fr/, /es/
  function urlLanguageHint() {
    var match = (location.pathname || "").match(/^\/([a-z]{2})(?:\/|$)/);
    if (!match) match = (location.pathname || "").match(/\/([a-z]{2})(?:\/|$)/);
    if (!match) return null;
    var code = match[1];
    // Only return recognized language codes, not generic path segments
    if (/^(de|fr|es|pt|pl|it|nl|sv|da|nb|no|fi|cs|sk|hu|ro|bg|hr|sr|sl|uk|el|tr|ja|ko|zh|ar|he|th|vi|id|ms)$/.test(code)) return code;
    return null;
  }

  function parseMismatchUrl(value) {
    try { return new URL(value || location.href, location.href); } catch (_error) { return null; }
  }

  function normalizedUrlHost(url) {
    return (url && url.hostname || "").replace(/^www\./i, "").toLowerCase();
  }

  function normalizedUrlPathSegments(url) {
    if (!url) return [];
    return safeDecodeURI(url.pathname || "").split("/").filter(Boolean).map(function(segment) {
      return segment.replace(/\.(?:html?|shtml|php|aspx?)$/i, "").toLowerCase();
    });
  }

  function normalizedSlugText(value) {
    return stripDiacritics(normalizeText(safeDecodeURI(value || ""))).toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
  }

  function normalizedArticleSlugMatchesTitle(metadata, content, title) {
    var normalizedTitle = title || (document && document.title) || (content && content.title) || (metadata && metadata.title) || "";
    if (!normalizeText(normalizedTitle)) return false;

    var pathUrl = parseMismatchUrl(location.href);
    var canonicalUrl = parseMismatchUrl(metadata.canonicalUrl);
    var pathSegments = normalizedUrlPathSegments(pathUrl);
    var canonicalSegments = normalizedUrlPathSegments(canonicalUrl);
    var pathSlugSegment = pathSegments[pathSegments.length - 1] || "";
    var canonicalSlugSegment = canonicalSegments[canonicalSegments.length - 1] || "";
    function articleSlugSegment(segment) {
      return !!segment && segment.length >= 4 && !/^\d+$/.test(segment);
    }

    if (!articleSlugSegment(pathSlugSegment) && !articleSlugSegment(canonicalSlugSegment)) return false;

    var pathSlug = normalizedSlugText(pathSegments[pathSegments.length - 1] || "");
    var titleSlug = normalizedSlugText(normalizedTitle);

    if (!pathSlug || !titleSlug) return false;
    if (pathSlug === titleSlug) return true;

    return pathSlug.indexOf(titleSlug) !== -1 || titleSlug.indexOf(pathSlug) !== -1;
  }

  function slugLikePathSegment(segment) {
    if (!segment || segment.length < 10) return false;
    if (/^\d+$/.test(segment)) return false;
    if (/^[a-z0-9]{10,}$/i.test(segment) && segment.indexOf("-") === -1 && segment.indexOf("_") === -1 && !/[^\x00-\x7F]/.test(segment)) return false;
    return /[-_]/.test(segment) || /[^\x00-\x7F]/.test(segment);
  }

  function articlePathHasSlugOnlyStructure(segments) {
    if (!segments || !segments.length) return false;
    var slugSegments = segments.filter(slugLikePathSegment);
    if (slugSegments.length !== 1) return false;

    return segments.every(function(segment) {
      return slugLikePathSegment(segment) || segment.length <= 24 || /^\d+$/.test(segment) || /^[a-z]{2}$/i.test(segment) || /^[a-z0-9]{6,}$/i.test(segment);
    });
  }

  function urlsDifferOnlyByQueryOrSlug(metadata) {
    var finalUrl = parseMismatchUrl(location.href);
    var canonicalUrl = parseMismatchUrl(metadata && metadata.canonicalUrl);
    if (!finalUrl || !canonicalUrl) return false;
    if (normalizedUrlHost(finalUrl) !== normalizedUrlHost(canonicalUrl)) return false;

    var finalSegments = normalizedUrlPathSegments(finalUrl);
    var canonicalSegments = normalizedUrlPathSegments(canonicalUrl);
    if (finalSegments.join("/") === canonicalSegments.join("/")) return articlePathHasSlugOnlyStructure(finalSegments);
    if (finalSegments.length !== canonicalSegments.length) return false;

    var differences = 0;
    for (var i = 0; i < finalSegments.length; i += 1) {
      if (finalSegments[i] === canonicalSegments[i]) continue;
      differences += 1;
      if (!slugLikePathSegment(finalSegments[i]) || !slugLikePathSegment(canonicalSegments[i])) return false;
    }

    return differences === 1;
  }

  function localizedSlugArticleGuard(metadata, content, body, markdown) {
    if (!metadata || !normalizeText(metadata.title || "")) return false;
    var substantialArticle = (content && content.contentType === "article") || body.length > 800 || ((markdown || "").match(/\n\s*\n/g) || []).length >= 4;
    if (!substantialArticle) return false;

    var path = safeDecodeURI(location.pathname || "");
    var pathSegments = normalizedUrlPathSegments(parseMismatchUrl(location.href));
    var slugTokens = slugKeywords();
    var normalizedCombined = stripDiacritics([metadata.title, (content && content.title) || "", body.slice(0, 4000), markdown || ""].join(" ")).toLowerCase();
    var normalizedTitle = stripDiacritics(normalizeText((content && content.title) || metadata.title || "")).toLowerCase();
    var articleTextSample = [metadata.title, (content && content.title) || "", body.slice(0, 4000), markdown || ""].join(" ");
    var slugOverlapThreshold = slugTokens.length >= 5 ? 0.2 : 0.15;
    var combinedOverlap = slugTokens.filter(function(token) { return normalizedCombined.indexOf(token) !== -1; }).length;
    var titleOverlap = slugTokens.filter(function(token) { return normalizedTitle.indexOf(token) !== -1; }).length;
    var strongSlugMatch = articlePathHasSlugOnlyStructure(pathSegments) && slugTokens.length >= 2 && (combinedOverlap >= 1 || titleOverlap >= 1 || (combinedOverlap / slugTokens.length) >= slugOverlapThreshold || (titleOverlap / slugTokens.length) >= slugOverlapThreshold);

    return (urlsDifferOnlyByQueryOrSlug(metadata) && containsNonLatinScript(articleTextSample)) || containsNonLatinScript(path) || (containsNonLatinScript(articleTextSample) && articlePathHasSlugOnlyStructure(pathSegments)) || strongSlugMatch;
  }

  // Language stopword sets for content language detection
  var langStopwords = {
    de: /\b(und|die|der|das|ist|von|zu|mit|den|ein|eine|für|auf|als|auch|nicht|sich|werden|nach|bei|aus|wie|oder|noch|nur|dem|des|über)\b/gi,
    fr: /\b(les|des|une|est|dans|pour|sur|par|pas|qui|que|avec|son|sont|plus|ses|mais|cette|ont|tout|nous|vous|aux|leur)\b/gi,
    es: /\b(los|las|una|del|por|con|para|que|más|son|sus|pero|como|esta|todo|nos|hay|fue|muy|han|sin|sobre|tiene)\b/gi,
    pt: /\b(dos|das|uma|por|com|para|que|mais|são|mas|como|esta|seu|sua|tem|nos|foi|pode|muito|seus|sobre|também)\b/gi,
    pl: /\b(nie|jest|są|się|jak|czy|ale|lub|oraz|tak|ich|jego|już|pod|przy|bez|dla|gdy|gdzie|między|tylko|może|który|która|które|których|którym|którego|którą|ten|ta|tej|tego|tym|tych|przez|dnia|roku|wobec|nadto|ponadto|został|została|był|była|było|były)\b/gi,
    it: /\b(gli|una|del|per|con|che|sono|più|dalla|della|delle|dei|anche|come|questa|tutto|suo|sua|suoi|nelle|alla)\b/gi,
    nl: /\b(een|het|van|zijn|met|dat|voor|maar|niet|ook|als|nog|wel|hun|uit|bij|kan|zou|meer|alle|dit|wordt)\b/gi,
    da: /\b(den|det|til|med|har|som|kan|vil|blev|efter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|blev|over|under)\b/gi,
    sv: /\b(den|det|att|som|har|med|för|kan|och|var|till|från|inte|ska|alla|hon|han|efter|över|under|denna|också|eller|blev)\b/gi,
    no: /\b(den|det|til|med|har|som|kan|vil|ble|etter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|over|under)\b/gi,
    nb: /\b(den|det|til|med|har|som|kan|vil|ble|etter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|over|under)\b/gi,
    fi: /\b(sen|oli|kun|tai|niin|mutta|ovat|joka|myös|kuin|siitä|tämä|hänen|tämän|vain|olla|sillä|sekä|ovat|vielä|nyt|yli|alle)\b/gi,
    tr: /\b(bir|için|ile|olan|olarak|gibi|daha|kadar|ancak|ayrıca|sonra|yapılan|ise|olan|üzerinde|tarafından|büyük|yeni|sonra)\b/gi,
    lv: /\b(par|kas|bet|arī|lai|jau|gan|nav|tad|vai|kur|šis|tās|kā|pie|pēc|tiek|var|būt|kad|vēl|viņa|visi|tikko|savs|kurš)\b/gi,
    lt: /\b(tai|yra|kad|bet|jau|dar|tik|bus|nuo|per|bei|iki|dėl|kas|čia|jis|jos|kur|buvo|labai|arba|dabar|turi|savo|apie)\b/gi,
    ro: /\b(este|sunt|fost|care|dar|sau|mai|pentru|într|cea|cel|acest|după|când|cum|prin|din|lor|avea|fost|toate|poate|doar)\b/gi,
    hr: /\b(koji|koja|koje|biti|nije|kao|ali|ako|više|samo|mogu|nakon|između|tada|sve|još|prije|već|prema|sada|njegov|ovaj)\b/gi,
    sr: /\b(који|која|које|бити|није|као|али|ако|више|само|могу|након|између|тада|све|још|пре|већ|према|сада|његов|овај)\b/gi,
    uk: /\b(що|але|як|або|вже|для|при|без|між|під|над|після|тому|який|яка|яке|його|його|цей|ще|також|може|були|буде)\b/gi,
    bg: /(?:^|\s)(и|в|на|за|с|от|до|е|са|се|че|но|като|през|които|която|което|след|това|също|повече|само|между|тези|всички|може|имат|обаче|когато|върху|срещу)(?=\s|$)/gi,
    el: /\b(και|που|από|στο|στα|στη|στις|στον|στους|για|με|της|του|των|ότι|αυτό|ήταν|είναι|αλλά|μετά|πριν|ακόμα|μπορεί)\b/gi,
    sk: /\b(ktorý|ktorá|ktoré|alebo|jeho|jeho|tento|tiež|môže|boli|bude|keď|pred|všetky|len|ešte|však|medzi|zatiaľ)\b/gi,
    sl: /\b(vendar|ampak|lahko|tudi|pred|vsak|bolj|že|prav|toda|niso|bili|bila|bilo|bodo|oziroma|čeprav|vedno|takoj)\b/gi,
    hu: /\b(hogy|mint|amikor|pedig|csak|volt|lesz|még|vagy|máig|után|előtt|mivel|összes|fogja|ehhez|tehát|viszont|minden)\b/gi,
    cs: /\b(který|která|které|jako|jeho|tento|také|může|byli|bude|když|před|všechny|ještě|pouze|však|mezi|zatím|proto)\b/gi
  };

  function bodyMatchesLanguage(langCode, body) {
    var pattern = langStopwords[langCode];
    if (!pattern) return true; // Unknown language, assume match
    var matches = body.match(pattern) || [];
    var words = body.split(/\s+/).length;
    var threshold = langCode === "pl" ? 0.025 : 0.03;
    // Expect a small but language-specific share of words to be stopwords.
    return words < 40 || (matches.length / words) >= threshold;
  }

  function consentWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var cookiePattern = consentKeywordPattern("i");
    if (!cookiePattern.test(normalized)) return false;

    if (consentKeywordLeadPattern("i").test(normalized)) return true;

    var hits = normalized.match(consentKeywordPattern("gi")) || [];
    if (normalized.length < 5000 && hits.length >= 3) return true;
    // For longer text, check if consent keywords dominate: >= 0.4 hits per 500 chars
    if (hits.length >= 8 && (hits.length / (normalized.length / 500)) >= 0.4) return true;
    return false;
  }

  function shortConsentPrivacyFragment(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized || normalized.length > 220) return false;

    return /^(?:do not sell(?: or share)? my personal information|do not sell(?: or share)?|privacy policy|cookie policy|cookies? policy|terms of (?:service|use)|manage (?:privacy|cookie|consent) preferences|privacy choices|your privacy choices)$/i.test(normalized) ||
      /(?:do not sell(?: or share)? my personal information|privacy policy|cookie policy|terms of (?:service|use)|privacy choices|your privacy choices)/i.test(normalized);
  }

  function subscriptionWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var pattern = /subscribe to continue|subscription required|sign in to continue reading|log in to continue reading|subscriber-only|purchase short-term access|institutional access|access through your institution|read with a subscription/g;
    if (pattern.test(normalized.slice(0, 600))) return true;

    var hits = normalized.match(pattern) || [];
    return normalized.length < 3000 && hits.length >= 1;
  }

  // Detect structured data paywall signals (isAccessibleForFree, content_tier meta)
  function paywallSignals() {
    // Check structured data: isAccessibleForFree
    var article = structuredDataNode(["NewsArticle", "Article", "BlogPosting", "WebPage", "LiveBlogPosting", "ReportageNewsArticle"]);
    var sdPaywall = article && (article.isAccessibleForFree === false || article.isAccessibleForFree === "False" || article.isAccessibleForFree === "false");

    // Check meta tags: article:content_tier
    var contentTier = metadataValue("article:content_tier", "property") || metadataValue("article:content_tier", "name");
    var metaPaywall = contentTier && /^(locked|metered|premium)$/i.test(normalizeText(contentTier));

    // Check common paywall DOM indicators
    var domPaywall = !!document.querySelector(
      "[data-piano-offer], [data-paywall], [class*='paywall' i], [id*='paywall' i], " +
      "[class*='subscribe-wall' i], [class*='premium-wall' i], [class*='piano-offer' i], " +
      "[data-testid*='paywall' i], [class*='metered' i][class*='banner' i]"
    );

    // Detect paywall text patterns in body
    var bodySnippet = normalizeText((document.body && document.body.innerText) || "").slice(0, 6000).toLowerCase();
    var textPaywall = /(for abonnenter|unlock full access|contenu réservé aux abonnés|solo para suscriptores|nur für abonnenten|alleen voor abonnees|solo per abbonati|dostępne dla subskrybentów|только для подписчиков|лише для передплатників|přístupné pouze pro předplatitele|csak előfizetőknek|exklusivt för prenumeranter|kun for abonnenter|vain tilaajille|tik prenumeratoriams|tikai abonentiem|nur für abonnent|nur für abonnenten|contenido exclusivo para suscriptores|réservé aux abonnés|subscriber exclusive|subscribers only|premium content|members only|členský obsah|premium-inhalt)/.test(bodySnippet);

    if (!sdPaywall && !metaPaywall && !domPaywall && !textPaywall) return null;

    return {
      source: sdPaywall ? "structured_data" : metaPaywall ? "meta_tag" : domPaywall ? "dom_element" : "text_pattern",
      contentTier: contentTier ? normalizeText(contentTier).toLowerCase() : (sdPaywall ? "locked" : null)
    };
  }

  function evergreenScienceOrDataPage(metadata, content, title, body) {
    if (!content || content.contentType !== "article" || body.length < 500) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();

    var context = normalizeText([
      title,
      (content && content.title) || "",
      metadata && metadata.title,
      metadata && metadata.siteName,
      metadata && metadata.excerpt,
      metadataValue("article:section", "property"),
      location.hostname || "",
      path
    ].join(" ")).toLowerCase();

    if (/\b(news|breaking|opinion|press release|live updates?)\b/.test(context)) return false;

    var evergreenContext = /\b(science|research|data|statistics|charts?|emissions?|climate|mission|observatory|telescope|reference|facts?|explorer|dataset|indicators?)\b/.test(context);
    var evergreenBody = /\b(key facts|data explorer|all charts|research & writing|introduction|overview|mission overview|science themes|methodology|download data|sources? and methods?)\b/i.test(body);
    var evergreenPath = /\/(?:mission|missions|data|statistics|charts?|topics?|explorers?)(?:\/[^/.]+)?\/?$/.test(path) || /\b(?:emissions|greenhouse-gas|climate|dataset|data-explorer)\b/.test(path);
    var sectionCount = (body.match(/^##\s+/gm) || []).length;

    return evergreenContext && ((evergreenPath && body.length >= 500) || (body.length >= 1500 && (evergreenBody || sectionCount >= 4)));
  }

  function legalInstrumentContext(title, body) {
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var context = normalizeText([title, path, body.slice(0, 5000)].join(" ")).toLowerCase();

    if (/\/(?:instruments?|treat(?:y|ies)|charters?|covenants?|conventions?|protocols?|resolutions?|publication\/unts)\b/.test(path)) return true;
    if (/\b(?:international\s+)?(?:covenant|convention|charter|treaty|protocol|optional protocol|general assembly resolution|united nations treaty collection|states parties to the present|entry into force|ratification status)\b/.test(context)) return true;
    if (/\barticle\s+\d+\b/.test(context) && /\b(states parties|entry into force|ratification|depositary|secretary-general|united nations)\b/.test(context)) return true;
    if (officialStatuteOrCodeContext(title, body, path, context)) return true;

    return false;
  }

  function officialStatuteOrCodeContext(title, body, path, context) {
    var legalContext = legalProvisionContext({ text: body, title: title, path: path, contextLimit: 5000 });
    var structuralSignals = (/\b(?:book|part|division|chapter|title|article|section)\s+\d+[a-z]?\b/g.test(body) || /(?:^|\s)§\s*\d+/.test(body));

    return legalContext.officialStatuteTitle && legalContext.officialTextSignals && (structuralSignals || legalContext.translationAttribution || /\/englisch_[a-z0-9_-]+\//.test(path));
  }

  function legalCaseContext(title, body) {
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var context = normalizeText([title, path, body.slice(0, 8000), metadataValue("citation", "name"), metadataValue("DC.title", "name")].join(" ")).toLowerCase();
    var courtNumberPath = courtNumberCasePath(path);
    var caseCitation = /\[\d{4}\]\s*(?:ukhl|uksc|ewca|ewhc|ukpc|ukut|ukftt|ac|wlr|all\s+er|ecli)\b/i.test(context);
    var judgmentLanguage = /\b(?:judgment|judgement|opinion(?:s)? of the lords|court of appeal|high court|supreme court|house of lords|lordships|appellant|respondent|claimant|defendant|neutral citation|cite as)\b/i.test(context);
    var caseTitle = /\b(?:v\.?|versus)\b/i.test(title || context) && /\b(?:appellant|respondent|claimant|defendant|secretary of state|commissioner|director of public prosecutions)\b/i.test(context);

    return (courtNumberPath && (caseCitation || judgmentLanguage || caseTitle)) || (caseCitation && judgmentLanguage && caseTitle);
  }

  function courtNumberCasePath(path) {
    return /\/(?:cases?|judgments?|judg?ments?)\/[^/]+\/\d{4}\/\d+(?:\.html?)?$/i.test(path) ||
      /\/(?:uksc|ukhl|ewca|ewhc|ukpc|ukut|ukftt|scotcs|niehc|nifam|ecj|echr|ecli)\/\d{4}\/\d+(?:\.html?)?$/i.test(path);
  }

  function retrospectiveOrHistoricalContext(metadata, content, title, body) {
    if (!content || content.contentType !== "article" || body.length < 500) return false;

    var context = normalizeText([
      title,
      (content && content.title) || "",
      metadata && metadata.title,
      metadata && metadata.siteName,
      metadata && metadata.excerpt,
      metadataValue("article:section", "property"),
      location.pathname || "",
      body.slice(0, 4000)
    ].join(" ")).toLowerCase();

    return /\b(today in history|on this day|this day in history|from the archives|retrospective|look back|looking back|revisit(?:ed|ing)?|recall(?:s|ed|ing)?|remember(?:s|ed|ing)?|anniversary|archived|back then|then and now|historical|ajaloos|ajalugu|tagasivaade|meenut(?:a|ab|as)?)\b/.test(context) ||
      /(?:振り返る|回顧|回想|当時|歴史|記念)/.test(context);
  }

  function staleContentApplies(metadata, content, title, body) { if (!content || content.contentType !== "article" || content.docsLike) return false; if (hostMatches(/(^|\.)siol\.net$/)) return false; if (evergreenScienceOrDataPage(metadata, content, title, body)) return false; if (retrospectiveOrHistoricalContext(metadata, content, title, body)) return false; var newsArticle = structuredDataNode(["NewsArticle", "ReportageNewsArticle", "LiveBlogPosting", "AnalysisNewsArticle", "OpinionNewsArticle"]); if (newsArticle) return true; var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase(); if (ogType && ogType !== "article") return false; if (document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output")) return false; var context = normalizeText([ title, metadata && metadata.siteName, metadata && metadata.excerpt, metadataValue("article:section", "property"), location.pathname || "" ].join(" ")).toLowerCase(); if (/\b(docs?|documentation|reference|encyclopedia|wiki|manual|api|guide|tutorial|learn|legal|charter|terms|privacy|about us)\b/.test(context)) return false; if (/\b(news|breaking|politics|business|markets?|economy|world|national|local|analysis|opinion|investigation|report)\b/.test(context)) return true; return body.length < 5000 && /\b(updated|published|reported)\b/.test(context); }

  function syndicatedRepostApplies(title, body, page) {
    var text = normalizeText(body + " " + page).toLowerCase();
    if (!text) return false;

    if (legalInstrumentContext(title, body) || legalCaseContext(title, body)) return false;

    var wirePattern = /\b(ein presswire|business wire|pr newswire|prnewswire|globe newswire|globenewswire|cision|marketwired|pr\.com|accesswire)\b|\/prnewswire\//i;
    var hits = text.match(/\b(ein presswire|business wire|pr newswire|prnewswire|globe newswire|globenewswire|cision|marketwired|pr\.com|accesswire)\b|\/prnewswire\//gi) || [];
    if (!hits.length) return false;

    var boilerplate = /\b(this press release was (?:issued|distributed)|press release (?:distributed|provided|issued) by|distributed by (?:ein presswire|business wire|pr newswire|prnewswire|globe newswire|globenewswire|cision|marketwired|accesswire)|provided by (?:ein presswire|business wire|pr newswire|prnewswire|globe newswire|globenewswire|cision|marketwired|accesswire))\b/i;
    if (boilerplate.test(text)) return true;

    var lead = text.slice(0, 1600);
    if (wirePattern.test(lead) && /\b(press release|announces?|launches?|reports?|new york|london|toronto|singapore|--|\(business wire\))\b/i.test(lead)) return true;

    var headingContext = normalizeText(title + " " + page.slice(0, 800)).toLowerCase();
    if (wirePattern.test(headingContext) && /\b(press release|announces?|launches?)\b/.test(headingContext)) return true;

    return hits.length >= 3 && /\b(press release|announces?|launches?|distributed|provided)\b/i.test(text.slice(0, 4000));
  }

  function strongSingleTopicPage(metadata, content, markdown, body) {
    if (!content || content.contentType !== "article" || content.docsLike || body.length < 1500) return false;
    var view = multiTopicExtractionView(content, markdown);
    var root = view.root || document;
    var cleanedMarkdown = view.markdown || markdown || "";
    if (content.singleTopicPage) return true;

    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var site = normalizeText((metadata && metadata.siteName) || "").toLowerCase();
    var hasHeading = !!(content.html && /<h1\b/i.test(content.html)) || title.length > 20;
    if (!hasHeading) return false;

    var paragraphCount = ((cleanedMarkdown || "").match(/\n\s*\n/g) || []).length;
    var headingCount = ((cleanedMarkdown || "").match(/^#{1,6}\s+/gm) || []).length;
    var articleLikeRoot = !!root.querySelector("article, main, [itemprop='articleBody'], #mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    if (articleLikeRoot && paragraphCount >= 4 && headingCount <= paragraphCount * 3 && body.length >= 3000) return true;
    if (paragraphCount >= 10 && body.length >= 2500 && headingCount <= paragraphCount * 2) return true;

    var scholarlyContext = /\b(abstract|references|methods|results|discussion|data availability|journal|protein|genome|doi)\b/i.test(body) || /\/(articles?|doi)\//.test(path);
    if (body.length > 8000 && scholarlyContext) return true;

    var overviewContext = /\/(?:what-we-do|what_we_do|our-work|our_work|about|mission|programmes?|programs?)\b/.test(path) || /\b(institution|agency|united nations|ngo|foundation|what we do|our work|mission)\b/.test(title + " " + site);
    if (overviewContext && /\b(what we focus on|we work|our work|mission|protect|provide|advocate|countries and territories|programmes?|programs?)\b/i.test(body)) return true;

    return false;
  }

  function scientificRecordContext(metadata, content, markdown, body) {
    if (!content || body.length < 800) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var site = normalizeText((metadata && metadata.siteName) || "").toLowerCase();
    var domText = normalizeText((document.body && document.body.innerText) || "");
    var context = normalizeText([title, site, path, body.slice(0, 12000), domText.slice(0, 12000)].join(" ")).toLowerCase();
    var sectionCount = (markdown || "").match(/^#{2,4}\s+/gm) || [];

    var recordRoute = /\/(?:compound|substance|protein|gene|genome|pathway|assay|bioassay|dataset|datasets|article\/dataset|articles\/dataset|record|entry)\//.test(path);
    var recordIdentifiers = context.match(/\b(?:cid|cas|inchikey|inchi|canonical smiles|molecular formula|molecular weight|uniprot|ensembl|refseq|gene id|taxonomy id|doi|dataset|accession|chembl|pubchem|protein|proteomics|metabolomics|transcriptomics)\b/g) || [];
    var tableLikeDom = document.querySelectorAll("table, dl, [class*='record' i], [class*='identifier' i], [class*='metadata' i], [data-testid*='metadata' i]").length >= 2;
    var structuredDataset = !!structuredDataNode(["Dataset", "DataCatalog"]);

    return (recordRoute || structuredDataset || /\b(?:database|data repository|scientific resource|life science resource)\b/.test(site)) &&
      recordIdentifiers.length >= 3 && (sectionCount.length >= 4 || tableLikeDom || body.length >= 5000);
  }

  function scientificDatasetRecordUrl(metadata, content, body) {
    if (!content || body.length < 500) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    if (!/\/(?:articles?\/)?(?:dataset|datasets|figure|record|entry)\//.test(path)) return false;

    var context = normalizeText([
      (content && content.title) || "",
      metadata && metadata.title,
      metadata && metadata.siteName,
      body.slice(0, 5000)
    ].join(" ")).toLowerCase();

    return /\b(?:dataset|posted on|authored by|doi|figure|data|repository|supplementary|apoptosis|protein|gene|assay|study)\b/.test(context) &&
      (/\b\d{3,}\b/.test(path) || /\/[_-]\//.test(path));
  }

  function detailRecordPath(path) {
    if (!path || /\/(?:search|browse|category|categories|tags?|topics?|collections?)\b/.test(path)) return false;

    return /\/(?:drugs?|compounds?|substances?|proteins?|genes?|genomes?|pathways?|assays?|bioassays?|datasets?|records?|entries?|items?|products?|publications?|papers?|articles?|cases?|opinions?|decisions?)\/[a-z0-9_.-]*\d[a-z0-9_.-]*(?:\/|$)/i.test(path);
  }

  function shortNavOnlyMarkdown(markdown) {
    var mdText = normalizeText(markdown || "");
    if (!mdText) return false;

    var linkCount = (mdText.match(/\[([^\]]*)\]\([^)]+\)/g) || []).length;
    var bulletLinkLines = (markdown || "").split(/\n+/).filter(function(line) {
      return /^\s*[-*]\s+\[[^\]]+\]\([^)]+\)\s*$/.test(line);
    }).length;
    var proseWords = mdText.replace(/\[([^\]]*)\]\([^)]+\)/g, "").split(/\s+/).filter(function(w) { return w.length >= 3; }).length;

    return linkCount >= 2 && bulletLinkLines >= 2 && proseWords < linkCount * 2;
  }

  function primaryBodyContainerText(selectors) {
    var parts = [];
    selectors.forEach(function(selector) {
      Array.prototype.slice.call(document.querySelectorAll(selector)).forEach(function(node) {
        var text = normalizeText(node.textContent || "");
        if (text.length >= 80 && parts.indexOf(text) === -1) parts.push(text);
      });
    });
    return normalizeText(parts.join("\n\n"));
  }

  function missingPrimaryContent(metadata, content, markdown, body) {
    if (!content || content.contentType !== "article" || content.docsLike) return false;
    if (clearArticleStructure(content, markdown, body)) return false;

    var context = normalizeText([
      location.pathname || "",
      (content && content.title) || "",
      metadata && metadata.title || ""
    ].join(" ")).toLowerCase();
    var html = String((content && content.html) || "").toLowerCase();

    if (/\blyrics?\b/.test(context)) {
      var lyricsText = primaryBodyContainerText(["[data-lyrics-container]", ".lyrics", "[class*='Lyrics__Container']"]);
      if (lyricsText.length < 300) return false;
      if (/data-lyrics-container|lyrics__container|class=["'][^"']*\blyrics\b/i.test(content.html || "")) return false;
      if (/\[(?:verse|chorus|bridge|outro|intro|hook|refrain|pre-chorus|instrumental)\b/i.test(body)) return false;
      if (/\b(song bio|annotation|contributors?|written by|produced by)\b/i.test(body) || body.length < lyricsText.length * 0.75) return true;
    }

    if (/\bpoems?\b/.test(context)) {
      var poemText = primaryBodyContainerText(["[data-poem]", ".poem", "[class*='poem' i]"]);
      if (poemText.length >= 300 && !/data-poem|class=["'][^"']*poem/i.test(content.html || "") && body.length < poemText.length * 0.75) return true;
    }

    return false;
  }

  function clearArticleStructure(content, markdown, body) { if (!content || content.contentType !== "article" || content.docsLike || body.length < 100) return false; var html = String(content.html || ""); var context = normalizeText([content.title || "", body.slice(0, 1000)].join(" ")).toLowerCase(); if (/\blyrics?\b/.test(context) || /\bpoems?\b/.test(context)) return false; var paragraphCount = ((markdown || "").match(/\n\s*\n/g) || []).length; var headingCount = ((markdown || "").match(/^#{1,6}\s+/gm) || []).length; var sentenceCount = (body.match(/[.!?]+/g) || []).length; if (hostMatches(/(^|\.)lenta\.ru$/) && /^\/news\/\d{4}\/\d{2}\/\d{2}\//i.test(location.pathname || "")) return (paragraphCount >= 1 || headingCount >= 1) && sentenceCount >= 2; if (body.length < 800 && substantialArticleContent(content)) return true; if (body.length >= 700) return false; if (!/<article\b/i.test(html) && !/<main\b/i.test(html)) return false; return (paragraphCount >= 1 || headingCount >= 1) && sentenceCount >= 2; } function multiTopicIgnoredContainerSelector() {
    return [
      "aside", "nav", "footer", "[role='complementary']", "[role='navigation']",
      "[aria-label*='related' i]", "[aria-label*='recommended' i]", "[aria-label*='latest' i]",
      "[class*='related' i]", "[class*='recommend' i]", "[class*='recirculat' i]",
      "[class*='liveblog' i]", "[class*='live-blog' i]",
      "[class*='sidebar' i]", "[class*='side-bar' i]", "[class*='widget' i]",
      "[class*='comment' i]", "[class*='discussion' i]", "[class*='community' i]",
      "[class*='popular' i]", "[class*='trending' i]", "[class*='suggest' i]",
      "[class*='teaser' i]", "[class*='also-read' i]", "[class*='read-more' i]",
      "[class*='more-news' i]", "[class*='more-stories' i]", "[class*='more-from' i]", "[class*='front-page' i]",
      "[class*='article-list' i]", "[class*='content-list' i]", "[class*='story-list' i]",
      "[class*='news-list' i]", "[class*='headline-list' i]", "[class*='feed' i]",
      "[class*='story-card' i]", "[class*='storycard' i]", "[class*='article-related-content' i]",
      "[id*='related' i]", "[id*='recommend' i]", "[id*='comment' i]", "[id*='sidebar' i]", "[id*='widget' i]",
      "[data-component*='article-list' i]", "[data-component*='related' i]",
      "[data-testid*='related' i]", "[data-testid*='recommend' i]", "[data-testid*='comment' i]"
    ].join(", ");
  }

  function multiTopicExtractionView(content, markdown) {
    var root = document.createElement("div");
    root.innerHTML = content && content.html ? content.html : "";
    if (!root.innerHTML) return { root: null, markdown: markdown };

    Array.prototype.forEach.call(root.querySelectorAll(multiTopicIgnoredContainerSelector()), function(node) {
      node.parentNode.removeChild(node);
    });

    var filteredMarkdown = markdown;
    if (typeof markdownFor === "function") filteredMarkdown = markdownFor(root.innerHTML || "");
    return { root: root, markdown: filteredMarkdown || "" };
  }

  // Detect liveblog / multi-topic / briefing content format
  function detectContentFormat(metadata, content, markdown) {
    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var pathname = (location.pathname || "").toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();

    // 1. Structured data: LiveBlogPosting
    var liveblog = structuredDataNode(["LiveBlogPosting"]);
    if (liveblog) return "liveblog";

    // 2. DOM signals for liveblog
    var liveblogDOM = (multiTopicExtractionView(content, markdown).root || document).querySelector(
      "[data-liveblog], [class*='liveblog' i], [class*='live-blog' i], [id*='liveblog' i], " +
      "[class*='live-ticker' i], [class*='liveticker' i], [id*='live-ticker' i], " +
      "[class*='live-feed' i], [class*='live-updates' i], [class*='live-entries' i]"
    );
    if (liveblogDOM) return "liveblog";

    // 3. Title/URL patterns for liveblog
    if (/\b(liveblog|live.blog|live.ticker|liveticker|live updates?|live.updates?)\b/.test(title) ||
        /\b(liveblog|live-blog|liveticker|live-ticker|live-updates)\b/.test(pathname)) {
      return "liveblog";
    }

    // 4. Briefing / digest / roundup / compilation detection
    // Title patterns: "This Week in ...", "Daily Briefing", "Morning Roundup", "News Digest", etc.
    if (/\b(daily briefing|morning briefing|evening briefing|weekly briefing|news briefing|this week in|week in review|daily digest|news digest|morning roundup|evening roundup|weekly roundup|daily round-?up|weekly round-?up|tagesüberblick|nachrichtenüberblick|wochenrückblick|résumé de la semaine|tour d'horizon|resumen semanal|rassegna stampa|przegląd tygodnia|przegląd dnia|podsumowanie tygodnia|podsumowanie dnia|daglig oversikt|veckosammanfattning|nyhedsoverblik|ugens nyheder|viikon katsaus|savaitės apžvalga|nedēļas apskats|преглед на седмицата|огляд тижня|преглед на денот|săptămâna în revistă|heti összefoglaló|týdenní přehled)\b/.test(title)) {
      return "briefing";
    }

    // 4b. Event listing / calendar / agenda detection
    if (/\b(events?[\s-]*(?:calendar|listing|guide|agenda|schedule)|what['']?s on|upcoming events?|things to do|veranstaltungen|événements|eventos|eventi|wydarzenia|evenementen|evenemang|begivenheder|tapahtumat|renginiai|pasākumi|események|události|events?\s+this\s+week|events?\s+today|event guide|gig guide|concert schedule)\b/.test(title) ||
        /\/(events?|calendar|agenda|whats-on|what-s-on|veranstaltungen|evenements)\b/.test(pathname)) {
      // Verify content has event-like structure (multiple date/time references)
      var datePatterns = body.match(/\b\d{1,2}[\s./-]\s*(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|januar|februar|märz|april|juni|juli|august|oktober|dezember|styczeń|luty|marzec|kwiecień|maj|czerwiec|lipiec|sierpień|wrzesień|październik|listopad|grudzień)\b/gi) || [];
      if (datePatterns.length >= 2) return "event_listing";
      // Also detect structured event data
      var eventSD = structuredDataNode(["Event", "MusicEvent", "SportsEvent", "TheaterEvent", "Festival"]);
      if (eventSD) return "event_listing";
    }

    // 4c. Video-only / video-centric page detection
    // Structured data: VideoObject, Movie, TVEpisode, etc.
    var videoSD = structuredDataNode(["VideoObject", "Movie", "TVEpisode", "TVSeries", "TVSeason", "Clip"]);
    if (videoSD) {
      // Only classify as video if text content is thin (not a full article with embedded video)
      if (body.length < 800) return "video";
    }
    // DOM signals: prominent video players with minimal article text
    var videoPlayers = document.querySelectorAll(
      "video, [class*='video-player' i], [class*='videoplayer' i], [id*='video-player' i], " +
      "[class*='jwplayer' i], [class*='bitmovin' i], [class*='brightcove' i], " +
      "[data-player], [data-video-id], [data-video], " +
      "[class*='auvio' i][class*='player' i], [class*='media-player' i], [class*='mediaplayer' i]"
    );
    var videoIframes = document.querySelectorAll(
      "iframe[src*='youtube'], iframe[src*='youtu.be'], iframe[src*='vimeo'], " +
      "iframe[src*='dailymotion'], iframe[src*='player'], iframe[src*='video'], " +
      "iframe[data-src*='youtube'], iframe[data-src*='vimeo']"
    );
    if ((videoPlayers.length >= 1 || videoIframes.length >= 1) && body.length < 600) {
      return "video";
    }
    // URL path signals combined with short content
    if (/\/(video|videos|watch|player|clip|replay|auvio|mediathek|mediatheque|videoteka|platforma)\b/.test(pathname) && body.length < 800) {
      // Verify there's actually minimal prose (not just a video page with a full article too)
      var proseLen = body.replace(/https?:\/\/\S+/g, "").replace(/[^a-zA-Z\u00C0-\u024F\u0400-\u04FF\u0370-\u03FF\u0100-\u017F\u0180-\u024F]/g, " ").replace(/\s+/g, " ").trim().length;
      if (proseLen < 500) return "video";
    }

    var formatView = multiTopicExtractionView(content, markdown);
    var formatMarkdown = formatView.markdown || markdown || "";

    // 5. Multi-topic heuristic: page contains multiple distinct timestamped entries or update blocks
    // Count headings and timestamps only after related/sidebar/list/feed widgets are removed.
    if (formatView.root) {
      var headings = formatView.root.querySelectorAll("h2, h3");
      var timeElements = formatView.root.querySelectorAll("time, [datetime]");

      // Multiple time-stamped entries suggest a compilation / live-update page
      // Require higher thresholds: >= 6 time elements (up from 4) and >= 4 headings (up from 3)
      if (timeElements.length >= 6 && headings.length >= 4) {
        // Verify the time elements are associated with distinct sections
        var uniqueTimes = [];
        for (var i = 0; i < timeElements.length; i++) {
          var dt = timeElements[i].getAttribute("datetime") || normalizeText(timeElements[i].textContent);
          if (dt && uniqueTimes.indexOf(dt) === -1) uniqueTimes.push(dt);
        }
        if (uniqueTimes.length >= 4) return "liveblog";
      }
    }

    // 6. Markdown-level heuristic: many H2/H3 with timestamps interspersed
    // Require higher thresholds to avoid false positives on regular articles
    // with a single publication timestamp (e.g. "Stand: 04:07 Uhr")
    if (formatMarkdown) {
      var h2Count = (formatMarkdown.match(/^##\s+/gm) || []).length;
      var timestampCount = (formatMarkdown.match(/\b\d{1,2}[:.]\d{2}\s*(?:Uhr|AM|PM|CET|CEST|UTC|GMT|[A-Z]{2,4}T)?\b/gm) || []).length;
      if (h2Count >= 6 && timestampCount >= 6) return "liveblog";
    }

    // 7. Newsletter / flash-news digest / hub detection:
    // Pages with many short items each linking out (e.g. daily flash-news compilations,
    // weekly newsletters, aggregated briefing hubs). Distinct from "briefing" which
    // matches specific title patterns — this catches structural layout patterns.
    if (formatMarkdown && content && content.html) {
      var mdLines = formatMarkdown.split("\n").filter(function(l) { return l.trim().length > 0; });
      var mdLinks = (formatMarkdown.match(/\[([^\]]*)\]\([^)]+\)/g) || []);
      var mdHeadings = (formatMarkdown.match(/^#{1,3}\s+/gm) || []).length;

      // Count short text blocks (< 200 chars between headings/links) — characteristic of
      // digest/hub layouts where each item is just a headline + 1-2 sentence summary + link
      var shortBlocks = 0;
      var currentBlockLen = 0;
      for (var li = 0; li < mdLines.length; li++) {
        var line = mdLines[li];
        if (/^#{1,3}\s+/.test(line)) {
          if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;
          currentBlockLen = 0;
        } else {
          currentBlockLen += line.length;
        }
      }
      if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;

      // Newsletter/digest: many headings, many links, and most content blocks are short
      if (mdHeadings >= 4 && mdLinks.length >= 5 && shortBlocks >= 4 && shortBlocks >= mdHeadings * 0.6) {
        return "newsletter";
      }

      // Hub/index page: dominated by links with very little prose relative to link count
      // (e.g. news hub pages listing story headlines as links)
      var proseText = formatMarkdown.replace(/\[([^\]]*)\]\([^)]+\)/g, "$1").replace(/^#{1,6}\s+.*$/gm, "").replace(/[^a-zA-Z\u00C0-\u024F\u0400-\u04FF\u0370-\u03FF\u0100-\u017F\u0180-\u024F]/g, " ").replace(/\s+/g, " ").trim();
      var proseWordCount = proseText.split(/\s+/).filter(function(w) { return w.length >= 3; }).length;
      if (mdLinks.length >= 8 && mdHeadings >= 4 && proseWordCount < mdLinks.length * 5) {
        return "newsletter";
      }
    }

    return null;
  }

  function suspicionReasons(metadata, content, markdown, pageText, signals) {
    var reasons = [];
    var title = normalizeText((content && content.title) || metadata.title).toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();
    var page = normalizeText(pageText || "").toLowerCase();
    var combined = (title + " " + body + " " + page).trim();
    var challengeType = challengePageType(metadata, pageText, signals);
    var interstitialType = interstitialPageType(metadata, pageText);
    var docsLike = !!(content && content.docsLike);
    var packagePage = !!(content && content.packagePage);
    var glossaryPage = /definition of |what does .+ mean\??| pronunciation in english|dictionary|definitions for /.test(title) || /(\/dictionary\/|\/definition\/|\/definitions\/|\/pronunciation\/)/.test(location.pathname || "") ||
      (!!queryParam("q") && /\b(dictionary|translation|translate|thesaurus|lexicon|s[łl]ownik|t[łl]umaczenie)\b/.test(title + " " + normalizeText(metadata.excerpt || "").toLowerCase()));
    var readableDocsPage = docsLike && body.length > 20;
    var emptyExtraction = !normalizeText(markdown || "") && !normalizeText((content && content.textContent) || "");
    var boilerplateOnlyExtraction = body.length < 140 && /copyright\b.*\ball rights reserved\b/i.test(body) && !/[.!?].+[.!?]/.test(body);
    var contentText = normalizeText((content && content.textContent) || "").toLowerCase();
    var extractedNotFoundText = normalizeText([body, contentText].join(" ")).toLowerCase();
    var extractedNotFoundBody = notFoundInterstitialEvidence(title, extractedNotFoundText, { maxTextLength: 1100 });
    var hasPublicContent = document.querySelectorAll("main a[href], article a[href]").length >= 3 || (content && content.contentType === "list");
    var consentDominatedBody = consentWallDominates(body);
    var substantialContent = body.length > 500 && !(consentDominatedBody && !hasPublicContent);
    var clearStructure = clearArticleStructure(content, markdown, body);

    if (!docsLike && !substantialContent && consentDominatedBody) reasons.push("consent_interstitial");
    if (!docsLike && shortConsentPrivacyFragment(body)) reasons.push("consent_interstitial");
    var consentLikeWall = consentLikeInterstitial(interstitialType, combined, body, page) && !(interstitialType === "consent_wall" && hasPublicContent);
    if (!docsLike && !substantialContent && (consentLikeWall || (consentWallDominates(page) && !hasPublicContent))) {
      reasons.push("consent_interstitial");
    }
    if (challengeType === "anubis") reasons.push("anubis_challenge_page");
    if (challengeType === "datadome") reasons.push("datadome_challenge_page");
    if (challengeType === "cloudflare") reasons.push("cloudflare_challenge_page");
    if (interstitialType === "consent_wall" && !substantialContent && !hasPublicContent) reasons.push("consent_interstitial");
    if (interstitialType === "meta_login") reasons.push("meta_login_wall");
    if (interstitialType === "human_verification") reasons.push("human_verification_interstitial");
    if (interstitialType === "region_selector") reasons.push("regional_selector_interstitial");
    if (interstitialType === "browser_support") reasons.push("browser_support_interstitial");
    if (interstitialType === "access_error") reasons.push("access_error_interstitial");
    if (interstitialType === "site_unavailable") reasons.push("site_unavailable_interstitial");
    if ((interstitialType === "not_found" || extractedNotFoundBody) && !(docsLike && readableDocsPage)) reasons.push("not_found_interstitial");
    if (interstitialType === "subscription" && (!substantialContent || subscriptionWallDominates(body) || (subscriptionWallDominates(page) && !hasPublicContent))) {
      reasons.push("subscription_interstitial");
    }
    if (interstitialType === "auth_wall") reasons.push("auth_or_login_interstitial");
    if (interstitialType === "meta_login" && /cookie/i.test(combined)) reasons.push("consent_interstitial");
    if (!(docsLike && readableDocsPage) && (challengeType || /(verify you are human|unusual traffic|are you a robot|access denied|security verification|checking your browser)/.test(combined))) {
      reasons.push("bot_or_access_interstitial");
    }
    if (!(docsLike && readableDocsPage) && (interstitialType === "human_verification" || interstitialType === "access_error")) reasons.push("bot_or_access_interstitial");
    if (emptyExtraction && (page.length > 80 || (metadata.title || "").length > 3 || (signals && signals.htmlLength > 200))) reasons.push("empty_extraction");
    if (boilerplateOnlyExtraction && !challengeType && !interstitialType) reasons.push("empty_extraction");
    // Flag empty/near-empty markdown even when pageText is also sparse (JS SPA failure)
    if (!challengeType && !interstitialType && normalizeText(markdown || "").length < 10 && (metadata.title || "").length > 3) {
      if (reasons.indexOf("empty_extraction") === -1 && reasons.indexOf("short_extraction") === -1) reasons.push("short_extraction");
    }

    if (!challengeType && !interstitialType && content && content.contentType !== "search") {
      var extractedLength = body.length;
      var pageLength = page.length;
      var slugTerms = slugKeywords();
      var hasArticlePath = slugTerms.length >= 2;
      var protothemaArticlePage = hostMatches(/(^|\.)protothema\.gr$/i) && content.contentType === "article" && extractedLength >= 500;

      if (content.contentType === "article" && !content.legalProvision && !readableDocsPage && !glossaryPage && !packagePage) {
        if (!protothemaArticlePage) {
          if (hasArticlePath && extractedLength < 500 && pageLength > 2000) {
            if (!clearStructure) reasons.push("truncated_content");
          }
          // Ratio-based truncation: catch moderate truncation where body is 500-1500 chars
          // but represents less than 15% of the full page (e.g. paywall cut-off, lazy-load failure)
          if (hasArticlePath && extractedLength >= 500 && extractedLength < 1500 && pageLength > 3000 && (extractedLength / pageLength) < 0.15 && !clearStructure) {
            reasons.push("truncated_content");
          }
          // Broader moderate truncation: body is 1500-3000 chars but represents less than 12%
          // of the full page text -- catches cases where a longer teaser is extracted but the
          // bulk of the article content is missing (common with SPA lazy-load or paywall teasers)
          if (hasArticlePath && extractedLength >= 1500 && extractedLength < 3000 && pageLength > 8000 && (extractedLength / pageLength) < 0.12 && !clearStructure) {
            reasons.push("truncated_content");
          }
          if (missingPrimaryContent(metadata, content, markdown, body)) {
            reasons.push("truncated_content");
          }
        }
      }

      // General short extraction: substantial page content was lost during extraction
      if (extractedLength < 200 && pageLength > 1000 && !readableDocsPage && !glossaryPage && !packagePage && !clearStructure) {
        reasons.push("short_extraction");
      }

      if (content.contentType === "article" && extractedLength >= 200 && extractedLength < 700 && pageLength > 2500 && !readableDocsPage && !glossaryPage && !packagePage && !clearStructure) {
        var teaserContext = normalizeText([markdown, title, metadata.title, metadata.description].join(" "));
        if (/\b(?:Published:\s*\d{4}|Duration:\s*P?T|featured video|watch video|learn more)\b/i.test(teaserContext)) {
          reasons.push("short_extraction");
        }
      }

      if ((content.contentType === "list" || content.contentType === "article") && detailRecordPath(location.pathname || "") && extractedLength < 500 && shortNavOnlyMarkdown(markdown) && !clearStructure) {
        reasons.push("short_extraction");
      }

      // Nav-only / chrome-only extraction: short markdown dominated by links with little prose
      if (content.contentType === "article" && !readableDocsPage && !glossaryPage && !packagePage && extractedLength >= 200 && extractedLength < 1000 && pageLength > 2000 && !clearStructure) {
        var mdText = normalizeText(markdown || "");
        var linkCount = (mdText.match(/\[([^\]]*)\]\([^)]+\)/g) || []).length;
        var headingCount = (mdText.match(/^#{1,6}\s/gm) || []).length;
        var proseWords = mdText.replace(/\[([^\]]*)\]\([^)]+\)/g, "").replace(/^#{1,6}\s.*$/gm, "").split(/\s+/).filter(function(w) { return w.length >= 3; }).length;
        // Flag if link-dense (more links than prose words) or heading-heavy with few words,
        // but allow compact article shells that still have clear paragraph structure.
        if (!clearStructure && ((linkCount >= 3 && proseWords < linkCount * 2) || (headingCount >= 3 && proseWords < 20))) {
          reasons.push("short_extraction");
        }
      }

      // Glossary-specific: dictionary/definition page title but very little content extracted
      if (glossaryPage && extractedLength < 60 && pageLength > 500) {
        reasons.push("short_extraction");
      }
    }

    var keywords = slugKeywords();
    var queryListPage = content && content.contentType === "list" && (
      queryParam("q") || queryParam("_nkw") || queryParam("st") || /^\/search\//.test(location.pathname)
    );
    if (!challengeType && !interstitialType && keywords.length >= 2 && !queryListPage && !docsLike && !courtNumberCasePath(safeDecodeURI(location.pathname || "").toLowerCase()) && !legalCaseContext(title, body)) {
      // Skip slug-keyword mismatch check when extracted body is predominantly non-Latin script
      // (e.g. Devanagari, Bengali, CJK) since URL slugs are typically ASCII transliterations
      var latinChars = (body.match(/[a-zA-Z]/g) || []).length;
      var totalChars = body.replace(/\s/g, "").length;
      var latinRatio = totalChars > 0 ? latinChars / totalChars : 1;
      if (latinRatio > 0.25) {
        // Normalize both slug keywords and content by stripping diacritics so
        // "rzad" matches "rząd", "isbirligi" matches "işbirliği", etc.
        var normalizedCombined = stripDiacritics(combined);
        var overlap = keywords.filter(function(token) {
          return normalizedCombined.indexOf(token) !== -1;
        }).length;
        // Use a stricter threshold (0.25) to catch more mismatches.
        // For slugs with many keywords (5+), require at least 30% overlap to avoid
        // false positives from long descriptive slugs where some words are generic.
        var overlapThreshold = keywords.length >= 5 ? 0.30 : 0.25;
        if ((overlap / keywords.length) < overlapThreshold) {
          // Secondary check: verify slug keywords against title/headline before flagging.
          // Many transliterated slugs match the headline even when body text uses diacritics.
          var normalizedTitle = stripDiacritics(title);
          var titleOverlap = keywords.filter(function(token) {
            return normalizedTitle.indexOf(token) !== -1;
          }).length;
          if ((titleOverlap / keywords.length) < overlapThreshold && !localizedSlugArticleGuard(metadata, content, body, markdown) && !scientificDatasetRecordUrl(metadata, content, body) && !patentPublicationIdMatchesContent(combined)) {
            reasons.push("url_content_mismatch");
          }
        }
      }
    }

    // Language mismatch: URL or page lang indicates one language, but body content is in another
    if (!challengeType && !interstitialType && body.length > 200 && !courtNumberCasePath(safeDecodeURI(location.pathname || "").toLowerCase()) && !legalCaseContext(title, body)) {
      var expectedLang = urlLanguageHint() || (metadata.language || "").slice(0, 2).toLowerCase();
      if (expectedLang && langStopwords[expectedLang] && !bodyMatchesLanguage(expectedLang, body) && !(expectedLang !== urlLanguageHint() && localizedSlugArticleGuard(metadata, content, body, markdown)) && !normalizedArticleSlugMatchesTitle(metadata, content)) {
        reasons.push("url_content_mismatch");
      }
    }

    if (content && content.contentType === "search") {
      if ((content.resultCount || 0) < 3) reasons.push("search_results_unusable");
      if (/^aplikacje google$/i.test(title) || /^google apps$/i.test(title)) reasons.push("search_engine_shell_page");
      if (/zawartość została wygenerowana przy użyciu ai|generated with ai|ai-generated/i.test(combined)) reasons.push("search_engine_ai_summary_only");
    }

    // Multi-topic / liveblog warning: page contains multiple stories that can't be isolated
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && !content.isolatedLiveblogEntry && !docsLike && !packagePage) {
      var formatView = multiTopicExtractionView(content, markdown);
      var formatMarkdown = formatView.markdown || markdown || "";
      var format = detectContentFormat(metadata, content, formatMarkdown);
      if (format && !(format === "video" && content.hostAware) && !strongSingleTopicPage(metadata, content, formatMarkdown, body) && !scientificRecordContext(metadata, content, markdown, body) && !legalInstrumentContext(title, body)) reasons.push("multi_topic_page");
    }

    // Paywall partial content: paywall detected and content appears truncated
    if (!challengeType && !interstitialType && content && content.contentType === "article" && !likelyListPath()) {
      var paywall = paywallSignals();
      if (paywall && reasons.indexOf("subscription_interstitial") === -1) {
        var publicArticle = metadata && metadata.isAccessibleForFree === true;
        // Flag if we got some content but it looks incomplete:
        // - Short absolute length (< 5000 chars), OR
        // - Content represents less than 40% of page text (paywall cut articles often have
        //   a teaser paragraph then truncation, while full page has nav/footer text), OR
        // - Longer content (< 12000 chars) but very low ratio (< 0.25) — catches cases where
        //   a substantial teaser is extracted but the full article is much longer (common with
        //   premium publishers like handelsblatt, nzz, luxtimes where teasers can be 5-10K chars)
        var paywallRatio = page.length > 0 ? body.length / page.length : 1;
        if (body.length > 0 && ((!publicArticle && body.length < 5000) || (!publicArticle && body.length < 8000 && paywallRatio < 0.40) || (body.length < 12000 && paywallRatio < 0.25))) {
          reasons.push("paywall_partial_content");
        }
      }
    }

    // Photo gallery / low-text media page detection
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && !docsLike) {
      var galleryPath = /\/(foto|fotos|photos?|gallery|galleries|galerie|galerij|galleria|galeria|fotogalerie|bildergalerie|bildspel|fotogalleri|valokuvat|fotoalbum|fotoreportaz|фото|фотогалерея|φωτογραφίες)\b/i.test(location.pathname || "");
      if (galleryPath && body.length < 800) {
        reasons.push("photo_gallery_page");
      }
    }

    // Stale content detection: flag articles with published dates more than 30 days old
    if (!challengeType && !interstitialType && staleContentApplies(metadata, content, title, body)) {
      var pubTime = normalizeText((content && content.publishedTime) || metadata.publishedTime || "");
      if (pubTime) {
        var pubDate = Date.parse(pubTime);
        if (!isNaN(pubDate)) {
          var ageMs = Date.now() - pubDate;
          var ageDays = ageMs / (1000 * 60 * 60 * 24);
          if (ageDays > 30 && body.length >= 1200 && !clearStructure) {
            reasons.push("stale_content");
          }
        }
      }
    }

    // Syndicated / wire-service repost detection
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && !docsLike) {
      if (syndicatedRepostApplies(title, body, page)) {
        reasons.push("syndicated_repost");
      }
    }

    return reasons;
  }
