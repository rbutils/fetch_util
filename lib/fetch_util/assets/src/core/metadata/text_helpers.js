function normalizeText(value) {
  if (typeof value !== "string") value = value == null ? "" : String(value);
  return value.replace(/\s+/g, " ").trim();
}

function safeDecodeURI(value) {
  try { return decodeURIComponent(value); } catch (_e) { return value; }
}

function textLength(node) {
  return normalizeText(node && node.textContent).length;
}

function absoluteUrl(value) {
  if (!value) return null;
  try {
    return new URL(value, document.baseURI).href;
  } catch (_error) {
    return value;
  }
}

function normalizeLanguageCode(value) {
  var text = normalizeText(value || "").toLowerCase();
  if (!text) return null;

  var first = text.split(",")[0].replace(/_/g, "-");
  var match = first.match(/^[a-z]{2,3}(?=-|$)/);
  if (!match) return null;

  var code = match[0];
  var aliases = { eng: "en", spa: "es", hin: "hi", fra: "fr", fre: "fr", deu: "de", ger: "de", por: "pt", zho: "zh", chi: "zh" };
  code = aliases[code] || code;

  return code.length === 2 ? code : null;
}

function languageFromText() {
  var text = normalizeText(document.body && document.body.innerText || "");
  if (text.length < 80) return null;

  var compact = text.replace(/\s/g, "");
  var scriptPatterns = [
    ["hi", /[\u0900-\u097F]/g],
    ["ar", /[\u0600-\u06FF]/g],
    ["zh", /[\u4E00-\u9FFF]/g],
    ["ja", /[\u3040-\u30FF]/g],
    ["ko", /[\uAC00-\uD7AF]/g],
    ["el", /[\u0370-\u03FF]/g],
    ["ru", /[\u0400-\u04FF]/g]
  ];

  for (var i = 0; i < scriptPatterns.length; i++) {
    var matches = compact.match(scriptPatterns[i][1]) || [];
    if (matches.length >= 20 && matches.length / compact.length >= 0.25) return scriptPatterns[i][0];
  }

  var words = text.toLowerCase().match(/[a-zÀ-ž]+/g) || [];
  if (words.length < 30) return null;

  var stopwords = {
    en: /^(?:the|and|that|for|with|this|from|are|was|were|have|has|not|but|their|about|more|will|would|which|when)$/,
    es: /^(?:el|la|los|las|un|una|del|de|al|a|en|y|por|con|para|que|más|son|sus|su|se|pero|como|esta|todo|nos|hay|fue|muy|han|sin|sobre|tiene)$/,
    fr: /^(?:les|des|une|est|dans|pour|sur|par|pas|qui|que|avec|son|sont|plus|ses|mais|cette|ont|tout|nous|vous|aux|leur)$/,
    de: /^(?:und|die|der|das|ist|von|zu|mit|den|ein|eine|für|auf|als|auch|nicht|sich|werden|nach|bei|aus|wie|oder|noch|nur|dem|des|über)$/,
    pt: /^(?:dos|das|uma|por|com|para|que|mais|são|mas|como|esta|seu|sua|tem|nos|foi|pode|muito|seus|sobre|também)$/,
    it: /^(?:gli|una|del|per|con|che|sono|più|dalla|della|delle|dei|anche|come|questa|tutto|suo|sua|suoi|nelle|alla)$/,
    nl: /^(?:een|het|van|zijn|met|dat|voor|maar|niet|ook|als|nog|wel|hun|uit|bij|kan|zou|meer|alle|dit|wordt)$/
  };
  var scores = {};
  Object.keys(stopwords).forEach(function(code) { scores[code] = 0; });
  words.forEach(function(word) {
    Object.keys(stopwords).forEach(function(code) {
      if (stopwords[code].test(word)) scores[code] += 1;
    });
  });

  var best = Object.keys(scores).sort(function(a, b) { return scores[b] - scores[a]; })[0];
  var runnerUp = Object.keys(scores).sort(function(a, b) { return scores[b] - scores[a]; })[1];
  return best && scores[best] >= 4 && scores[best] >= (scores[runnerUp] || 0) * 1.8 ? best : null;
}

function documentLanguage() {
  return normalizeLanguageCode(document.documentElement && document.documentElement.getAttribute("lang")) ||
    normalizeLanguageCode(metadataValue("Content-Language", "http-equiv")) ||
    normalizeLanguageCode(metadataValue("og:locale", "property")) ||
    languageFromText();
}

function platformSignature(metadata, extraSelectors) {
  var generator = normalizeText(firstText(["meta[name='generator']"], "content") || "");
  var appName = normalizeText(firstText(["meta[name='application-name']", "meta[property='og:site_name']"], "content") || "");
  var signatureParts = (Array.isArray(extraSelectors) ? extraSelectors : extraSelectors ? [extraSelectors] : []).map(function(selector) {
    if (typeof selector === "function") return selector(metadata, generator, appName);
    return firstText([selector]);
  });

  if (signatureParts.length === 0) {
    signatureParts = [metadata && metadata.title, metadata && metadata.siteName, generator, appName, document.title];
  }

  return {
    generator: generator,
    appName: appName,
    signature: normalizeText(signatureParts.join(" "))
  };
}

function firstText(selectors, attr) {
  for (var i = 0; i < selectors.length; i += 1) {
    var node = document.querySelector(selectors[i]);
    if (!node) continue;

    var value = attr ? node.getAttribute(attr) : node.textContent;
    value = normalizeText(value);
    if (value) return value;
  }

  return null;
}

function visibleMetadataRoots() {
  var roots = [];
  [
    "article[itemtype*='NewsArticle']",
    "article[itemtype*='Article']",
    "article",
    "main article",
    "main"
  ].forEach(function(selector) {
    document.querySelectorAll(selector).forEach(function(node) {
      if (roots.indexOf(node) === -1 && textLength(node) >= 80) roots.push(node);
    });
  });

  return roots.length ? roots : [document];
}

function firstScopedText(roots, selectors, attr) {
  for (var r = 0; r < roots.length; r += 1) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = roots[r].querySelector(selectors[i]);
      if (!node || node.closest("nav, footer, aside")) continue;

      var value = attr ? node.getAttribute(attr) : node.textContent;
      value = normalizeText(value);
      if (value) return value;
    }
  }

  return null;
}

function visibleByline() {
  var value = firstScopedText(visibleMetadataRoots(), [
    "[rel='author']",
    "[itemprop='author'] [itemprop='name']",
    "[itemprop='author']",
    "[class*='byline' i]",
    "[class*='author' i]",
    "[class*='autor' i]",
    "[class*='auteur' i]",
    "[class*='verfasser' i]",
    "[class*='redakteur' i]",
    "[class*='penulis' i]",
    "[class*='tac-gia' i]",
    "[class*='tacgia' i]",
    "[class*='writer' i]",
    "[class*='reporter' i]",
    "[data-testid*='author' i]"
  ]);

  return normalizeText(value || "").replace(/^(?:by|por|par|von|di|da|door|av|af|de|autor(?:a)?|auteur|redactie|redacción|redacao|redação|penulis|oleh|tác giả|tac gia|بقلم|כתבת?|מאת)\s*:?\s+/i, "") || null;
}

function visiblePublishedTime() {
  return firstScopedText(visibleMetadataRoots(), ["time[datetime]"], "datetime") ||
    firstScopedText(visibleMetadataRoots(), [
      "[itemprop='datePublished']",
      "[itemprop='dateModified']",
      "[class*='pubdate' i]",
      "[class*='published-date' i]",
      "[class*='published_at' i]",
      "[class*='published-at' i]",
      "[class*='publication-date' i]",
      "[class*='fecha' i]",
      "[class*='data-publicacao' i]",
      "[class*='data-publicação' i]",
      "[class*='datum' i]",
      "[class*='tarih' i]",
      "[class*='date' i]",
      "[class*='time' i]",
      "[class*='publish' i]",
      "[class*='posted' i]",
      "[data-testid*='date' i]",
      "time"
    ]);
}

function manyTexts(selectors, limit) {
  var seen = {};
  var items = [];

  selectors.forEach(function(selector) {
    document.querySelectorAll(selector).forEach(function(node) {
      if (items.length >= (limit || 20)) return;

      var text = normalizeText(node.textContent);
      if (!text || seen[text]) return;
      seen[text] = true;
      items.push(text);
    });
  });

  return items;
}

function bodyInnerText(pageText) {
  return (document.body && document.body.innerText) || pageText || "";
}

function humanizeValue(value) {
  return normalizeText(String(value || "").split("/").pop().replace(/[_-]+/g, " "));
}

function articleContentFromParts(parts) {
  var sections = [];
  var meta = [];

  if (parts.title) sections.push("# " + parts.title);
  if (parts.byline) meta.push("- Author: " + parts.byline);
  if (parts.publishedTime) meta.push("- Published: " + parts.publishedTime);
  asArray(parts.details).forEach(function(detail) {
    if (detail) meta.push("- " + detail);
  });
  if (meta.length) sections.push(meta.join("\n"));
  if (parts.description) sections.push(parts.description);
  if (parts.highlights && parts.highlights.length) {
    sections.push(parts.highlights.map(function(item) {
      return "- " + item;
    }).join("\n"));
  }

  var markdown = sections.filter(Boolean).join("\n\n").trim();
  return {
    title: parts.title,
    byline: parts.byline || null,
    excerpt: parts.description || null,
    siteName: parts.siteName || location.hostname,
    publishedTime: parts.publishedTime || null,
    html: "",
    markdown: markdown,
    textContent: normalizeText(markdown),
    docsLike: !!parts.docsLike,
    hostAware: !!parts.hostAware,
    readerMode: false,
    contentType: parts.contentType || "article"
  };
}

function queryParam(name) {
  return new URLSearchParams(location.search).get(name);
}

function searchQuery() {
  return queryParam("q") || queryParam("p") || queryParam("query") || queryParam("text") || "";
}

function isSearchEnginePage() {
  return /(^|\.)(google\.|bing\.com$|duckduckgo\.com$|search\.brave\.com$|ecosia\.org$)/.test(location.hostname);
}

function listContentResult(options) {
  var markdown = options.markdown != null ? options.markdown : listMarkdown(options.items || []);
  return {
    title: options.title,
    byline: null,
    excerpt: options.excerpt,
    siteName: options.siteName || location.hostname,
    publishedTime: null,
    html: options.html || "",
    textContent: options.textContent != null ? options.textContent : markdown,
    markdown: markdown,
    readerMode: false,
    contentType: "list"
  };
}

function listItemsContentResult(metadata, options) {
  options = options || {};
  var items = options.items;
  var markdown = options.markdown != null ? options.markdown : listMarkdown(items || []);
  var result = {
    title: options.title || (metadata && metadata.title) || document.title,
    byline: null,
    excerpt: options.excerpt != null ? options.excerpt : (items[0] ? items[0].text : metadata && metadata.excerpt),
    siteName: options.siteName || (metadata && metadata.siteName) || location.hostname,
    publishedTime: options.publishedTime || (metadata && metadata.publishedTime),
    html: options.html || "",
    textContent: options.textContent != null ? options.textContent : markdown,
    markdown: markdown,
    readerMode: false,
    contentType: options.contentType || "list"
  };
  if (items) result.itemCount = items.length;
  if (options.hostAware) result.hostAware = true;
  if (options.statusPage) result.statusPage = true;
  return result;
}
