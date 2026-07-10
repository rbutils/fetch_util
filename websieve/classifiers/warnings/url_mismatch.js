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

  function investorArchivePageGuard(metadata, content, body, markdown) {
    var text = normalizeText([metadata && metadata.title, content && content.title, body, markdown].join(" ")).toLowerCase();
    if (text.length < 800) return false;
    if (!/\b(?:shareholder|annual report|letter to shareholders|berkshire hathaway|investor relations|form\s*(?:10-k|10-q|8-k)|sec filing)\b/.test(text)) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    if (/\/(?:19|20)\d{2}(?:ar|annualreport|annual-report|report|letter)\//.test(path)) return true;
    if (/\/(?:19|20)\d{2}[^/]*(?:letter|report|annual)[^/]*\.html?$/.test(path)) return true;
    if (/\/(?:letters?|annual-reports?|reports?)\//.test(path) && /(?:19|20)\d{2}/.test(path)) return true;
    return false;
  }
