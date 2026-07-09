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

  function metadataValue(name, attr) {
    var selector = 'meta[' + attr + '="' + name + '"]';
    var node = document.querySelector(selector);
    return node ? node.getAttribute("content") : null;
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
    var signatureParts = asArray(extraSelectors).map(function(selector) {
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

  function collectMetadata() {
    var canonical = document.querySelector('link[rel="canonical"]');
    var schemaArticle = structuredDataNode(["NewsArticle", "Article", "BlogPosting"]);
    var schemaEvent = typeof eventStructuredDataNode === "function" ? eventStructuredDataNode() : null;
    var schemaAuthor = entityName(schemaArticle && schemaArticle.author);
    var schemaPublishedTime = entityText(schemaArticle && schemaArticle.datePublished);
    var schemaModifiedTime = entityText(schemaArticle && schemaArticle.dateModified);
    var schemaEventTime = schemaEvent && typeof eventDateText === "function" ? eventDateText(schemaEvent.startDate, schemaEvent.endDate) : null;

    return {
      title: metadataValue("og:title", "property") || document.title || firstText(["main h1", "article h1", "h1"]),
      byline: metadataValue("author", "name") || metadataValue("article:author", "property") || metadataValue("parsely-author", "name") || schemaAuthor || visibleByline(),
      excerpt: metadataValue("description", "name") || metadataValue("og:description", "property"),
      siteName: metadataValue("og:site_name", "property") || location.hostname,
      publishedTime: schemaEventTime || metadataValue("article:published_time", "property") || metadataValue("publish-date", "name") || metadataValue("datePublished", "itemprop") || metadataValue("date", "name") || metadataValue("dc.date", "name") || metadataValue("DC.date", "name") || metadataValue("parsely-pub-date", "name") || schemaPublishedTime || schemaModifiedTime || visiblePublishedTime(),
      canonicalUrl: absoluteUrl(canonical && canonical.getAttribute("href")) || location.href,
      language: documentLanguage(),
      image: metadataValue("og:image", "property") || null,
      video: metadataValue("og:video", "property") || metadataValue("og:video:url", "property") || null
    };
  }

  function asArray(value) {
    if (!value) return [];
    return Array.isArray(value) ? value : [value];
  }

  function flattenStructuredData(value, nodes) {
    if (!value) return;
    if (Array.isArray(value)) {
      value.forEach(function(item) {
        flattenStructuredData(item, nodes);
      });
      return;
    }
    if (typeof value !== "object") return;

    if (value["@graph"]) flattenStructuredData(value["@graph"], nodes);
    nodes.push(value);
  }

  function structuredDataNodes() {
    var nodes = [];

    document.querySelectorAll('script[type="application/ld+json"]').forEach(function(script) {
      var text = script.textContent || script.innerText || "";
      if (!normalizeText(text)) return;

      try {
        flattenStructuredData(JSON.parse(text), nodes);
      } catch (_error) {
      }
    });

    return nodes;
  }

  function nodeTypes(node) {
    return asArray(node && node["@type"]).map(function(type) {
      return String(type);
    });
  }

  function structuredDataNode(typeNames) {
    var wanted = asArray(typeNames);

    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return wanted.indexOf(type) !== -1;
      });
    }) || null;
  }

  function structuredDataNodeMatchingType(predicate) {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(predicate);
    }) || null;
  }

  function medicalWebPageStructuredDataNode() {
    return structuredDataNode(["MedicalWebPage"]);
  }

  function medicalStructuredDataNode() {
    return structuredDataNodeMatchingType(function(type) {
      return type === "MedicalWebPage" || type === "MedicalEntity" || /^Medical[A-Z]/.test(type);
    });
  }

  function healthArticleUrlSignal() {
    var host = (location.hostname || "").replace(/^www\./i, "").toLowerCase();
    var path = (location.pathname || "").toLowerCase();

    if (/cdc\.gov$/.test(host) && /\/(?:about|signs-symptoms|symptoms|causes|risk-factors|testing|treatment|prevention|living-with|basics|facts)\b/.test(path)) return true;
    if (/mayoclinic\.org$/.test(host) && /\/diseases-conditions\/[^/]+\/(?:symptoms-causes|diagnosis-treatment|in-depth)\//.test(path)) return true;
    if (/webmd\.com$/.test(host) && /\/(?:depression|anxiety|mental-health|a-to-z-guides?|pain-management|diabetes|heart-disease|cancer|lung)\b/.test(path)) return true;
    if (/nhs\.uk$/.test(host) && /\/conditions\/[^/]+\//.test(path)) return true;
    if (/who\.int$/.test(host) && /\/news-room\/fact-sheets\/detail\//.test(path)) return true;

    return false;
  }

  function substantialMedicalArticleContent(content) {
    if (!content) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    if (text.length < 420) return false;

    var paragraphs = root.querySelectorAll("p").length;
    var headings = root.querySelectorAll("h1, h2, h3").length;
    var longBlocks = Array.prototype.filter.call(root.querySelectorAll("p, li, section, div"), function(node) {
      return normalizeText(node.textContent || "").length >= 120;
    }).length;
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;

    return linkDensity < 0.45 && (paragraphs >= 3 || longBlocks >= 4 || (headings >= 2 && text.length >= 900));
  }

  function medicalArticlePage(metadata, content) {
    if (content && (content.contentType === "interstitial" || content.contentType === "product")) return false;
    if (!substantialMedicalArticleContent(content)) return false;
    if (medicalStructuredDataNode()) return true;
    return healthArticleUrlSignal();
  }

  function applyMedicalContentType(content, metadata) {
    if (!content || content.contentType === "interstitial" || content.contentType === "product") return content;
    if (!medicalWebPageStructuredDataNode()) return content;

    content.contentType = "medical";
    return content;
  }

  function entityName(value) {
    if (!value) return null;
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) return entityName(value[0]);
    return normalizeText(value.name || value.headline || value.alternateName || "");
  }

  function entityText(value) {
    if (!value) return null;
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) {
      return normalizeText(value.map(function(item) {
        return entityText(item) || "";
      }).join(" "));
    }
    return normalizeText(value.text || value.description || value.name || "");
  }

  function definitionReferenceMetadataScore(metadata) {
    var text = normalizeText([
      metadata && metadata.title,
      metadata && metadata.excerpt,
      metadata && metadata.siteName,
      metadataValue("og:type", "property")
    ].join(" ")).toLowerCase();
    var score = 0;

    if (/\b(dictionary|glossary|lexicon|thesaurus|encyclopedia|database)\b/.test(text)) score += 3;
    if (/\b(definition|definitions|meaning|pronunciation|part of speech|citation|reference)\b/.test(text)) score += 2;
    if (/\b(website|article)\b/.test(text) && /\b(dictionary|glossary|definition|definitions|database)\b/.test(text)) score += 1;

    structuredDataNodes().some(function(node) {
      var types = nodeTypes(node).join(" ").toLowerCase();
      if (/definedterm|dictionary|glossary|creativework|article/.test(types) && /\b(definition|term|description|citation)\b/.test(text + " " + types)) {
        score += 2;
        return true;
      }
      return false;
    });

    return score;
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
    return /(^|\.)(google\.|bing\.com$|duckduckgo\.com$|search\.brave\.com$|ecosia\.org$)/.test(location.hostname) && !!searchQuery();
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
      excerpt: options.excerpt != null ? options.excerpt : ((items && items[0] && items[0].text) || (metadata && metadata.excerpt)),
      siteName: options.siteName || (metadata && metadata.siteName) || location.hostname,
      publishedTime: options.publishedTime != null ? options.publishedTime : ((metadata && metadata.publishedTime) || null),
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

  function bodyInnerText(pageText) {
    return (document.body && document.body.innerText) || pageText || "";
  }
