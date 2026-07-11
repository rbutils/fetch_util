  function cjkLikeText(text) {
    return /[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/.test(text || "");
  }

  function minimumListTitleLength(text) {
    return cjkLikeText(text) ? 4 : 8;
  }

  function likelyListPath() {
    var path = (location.pathname || "").toLowerCase();
    var segments = path.split("/").filter(Boolean);
    var last = segments[segments.length - 1] || "";

    if (!segments.length) return true;
    if (/^\/(index|default|home)\b/i.test(path) || /^\/\d+(,\d+)*\.html?$/i.test(path)) return true;
    if (/\/(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|notizie|calciomercato|mercato|forums?|boards?|community|discussions?|threads)\/?$/.test(path)) return true;
    if (segments.length <= 2 && !/\d{4}[-/]\d{2}[-/]\d{2}/.test(path) && !/-/.test(last) && !/\.(html?|php|aspx?|jsp|shtml)$/i.test(last)) return true;
    return false;
  }

  function opaqueDetailPath() {
    return opaqueDetailIdPath((location.pathname || "").toLowerCase().split("/").filter(Boolean));
  }

  function opaqueDetailIdPath(segments) {
    if (!segments || segments.length !== 2) return false;

    var first = segments[0] || "";
    var last = segments[1] || "";
    if (/^(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|forums?|boards?|community|discussions?|threads)$/.test(first)) return false;
    return last.length >= 6 && /[a-z]/i.test(last) && /\d/.test(last) && /^[a-z0-9_-]+$/.test(last);
  }

  function queryOrCategoryPage() {
    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    return /(?:^|[?&])(q|query|search|searchtext|keyword|k)=/.test(query) ||
      /\/(search|s|shop|browse|category|categories|collections?|catalog|keyword|wholesale|products?|jobs?)\b/.test(path) ||
      /\b(category|categories|collection|catalog|search results?|shop|jobs?\s+(?:in|matching|for)|job results?)\b/i.test(document.title || "");
  }

  function articleLikePath() {
    var path = location.pathname || "";
    if (/\/(?:articles?|blogs?|columns?|archives?|entries?|posts?)\/?$/i.test(path)) return false;
    return /(?:^|\/)(?:a-[a-z0-9]+|20\d{2}|\d{4}\/\d{2}\/\d{2}|article|articles|blog|blogs|column|columns|archive|archives|news\/[\w-]+|entry|entries|post|posts|view\/[A-Z]{3}\d{15,}|\d{5,}[\w-]*\.html?)(?:\/|\b)/i.test(path);
  }

  function articleRouteFocalContent(content) {
    if (!document.body) return false;
    if (!articleLikePath()) return false;
    if (content && content.contentType !== "article" && content.contentType !== "medical") return false;

    var focal = document.querySelector("[itemprop='articleBody'], article[role='main'], main article");
    var root = focal || document.createElement("div");
    if (!focal && content && content.html) root.innerHTML = content.html;
    var heading = document.querySelector("h1") || root.querySelector("h1");
    var paragraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      var owner = paragraph.closest("article");
      return !owner || owner === root;
    });
    var text = normalizeText(paragraphs.map(function(paragraph) { return paragraph.textContent || ""; }).join(" "));
    if (!focal && content && content.html) text = normalizeText(root.textContent || "");
    var nestedArticles = root.querySelectorAll("article").length - (root.matches && root.matches("article") ? 1 : 0);
    var bylineOrTime = document.querySelector("[rel='author'], [itemprop='author'], [itemprop='datePublished'], time, .byline, [class*='byline' i]");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("p a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 1;

    var substantialProse = paragraphs.length >= 2 && text.length >= 120;
    var structuredLiveBody = nestedArticles >= 2 && normalizeText(root.textContent || "").length >= 280;
    return !!heading && (substantialProse || structuredLiveBody) && linkDensity < 0.45 &&
      (!!focal || !!content) && (!!bylineOrTime || (content && (content.byline || content.publishedTime)) || !!focal);
  }

  function articleEntryPath(path) {
    return /\/(?:20\d{2}|\d{4}\/\d{2}|[a-z0-9-]+\/\d{5,}(?:\/|$)|\d{5,}(?:\/|$)|[^\/]+-[^\/]+-[^\/]+)/i.test(path || "");
  }

  function looksLikeFooterLink(text, href) {
    return /^(privacy|cookies?|terms|chi siamo|about us|contact|contatti|redazione|advertising|newsletter|subscribe|login|sign in|register|cookie settings|manage preferences)$/i.test(text) ||
      /\/(privacy|cookie|cookies|terms|about|contatti|contact|redazione|login|register)\b/i.test(href || "");
  }

  function currentListPageUrl() {
    return location.origin + location.pathname;
  }

  function tokenizeListText(text) {
    return safeDecodeURI(text || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").split(/\s+/).filter(Boolean);
  }

  function listPageContext(metadata) {
    metadata = metadata || {};

    var heading = document.querySelector("main h1, [role='main'] h1, h1");
    var siteTokens = tokenizeListText((metadata.siteName || location.hostname || "").replace(/^www\./i, ""));
    var generic = /^(latest|news|article|articles|articlelist|story|stories|home|homepage|index|default|today|more|page|pages|section|sections|category|categories|topic|topics|read|view|photo|photos|video|videos|gallery|galleries|live|blog|blogs|web|english|telugu|samayam|newsweb|edition)$/;
    var tokens = tokenizeListText([
      location.pathname || "",
      metadata.title || "",
      document.title || "",
      heading ? heading.textContent : ""
    ].join(" ")).filter(function(token) {
      return token.length >= 3 && !/^\d+$/.test(token) && !generic.test(token) && siteTokens.indexOf(token) === -1;
    });

    var keywords = [];
    tokens.forEach(function(token) {
      if (keywords.indexOf(token) === -1 && keywords.length < 12) keywords.push(token);
    });

    var sectionFragments = [];
    (location.pathname || "").split("/").filter(Boolean).forEach(function(segment) {
      var value = safeDecodeURI(segment || "").toLowerCase();
      if (!value || /^\d/.test(value) || /\.(html?|php|aspx?|jsp|cms)$/i.test(value)) return;
      if (/^(news|latest-news|latest|articlelist|articles?|read|view|topic|topics|section|sections|home|index|default|world|india-news|international-news|english|telugu)$/.test(value)) return;
      if (sectionFragments.indexOf(value) === -1) sectionFragments.push(value);
    });

    return {
      currentUrl: currentListPageUrl(),
      keywords: keywords,
      sectionFragments: sectionFragments.slice(0, 4)
    };
  }
