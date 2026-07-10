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

  function staleContentApplies(metadata, content, title, body) { if (!content || content.contentType !== "article" || content.docsLike) return false; if (hostMatches(/(^|\.)siol\.net$/)) return false; if (evergreenScienceOrDataPage(metadata, content, title, body)) return false; if (retrospectiveOrHistoricalContext(metadata, content, title, body)) return false; var newsArticle = structuredDataNode(["NewsArticle", "ReportageNewsArticle", "LiveBlogPosting", "AnalysisNewsArticle", "OpinionNewsArticle"]); if (newsArticle) { var modifiedTime = normalizeText(entityText(newsArticle.dateModified) || metadataValue("article:modified_time", "property") || metadataValue("article:modified_time", "name") || metadataValue("dateModified", "property") || metadataValue("dateModified", "name") || ""); if (modifiedTime) { var modifiedDate = Date.parse(modifiedTime); if (!isNaN(modifiedDate)) { var modifiedAgeDays = (Date.now() - modifiedDate) / (1000 * 60 * 60 * 24); if (modifiedAgeDays <= 30) return false; } } return true; } var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase(); if (ogType && ogType !== "article") return false; if (document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output")) return false; var context = normalizeText([ title, metadata && metadata.siteName, metadata && metadata.excerpt, metadataValue("article:section", "property"), location.pathname || "" ].join(" ")).toLowerCase(); if (/\b(docs?|documentation|reference|encyclopedia|wiki|manual|api|guide|tutorial|learn|legal|charter|terms|privacy|about us)\b/.test(context)) return false; if (/\b(news|breaking|politics|business|markets?|economy|world|national|local|analysis|opinion|investigation|report)\b/.test(context)) return true; return body.length < 5000 && /\b(updated|published|reported)\b/.test(context); }

  function syndicatedRepostApplies(title, body, page) {
    var text = normalizeText(body + " " + page).toLowerCase();
    if (!text) return false;

    if (hostMatches(/(^|\.)(prnewswire\.com|globenewswire\.com|businesswire\.com)$/i)) return false;

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
