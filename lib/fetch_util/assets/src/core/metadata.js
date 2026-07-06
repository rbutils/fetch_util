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

    return {
      title: metadataValue("og:title", "property") || document.title || firstText(["main h1", "article h1", "h1"]),
      byline: metadataValue("author", "name") || metadataValue("article:author", "property"),
      excerpt: metadataValue("description", "name") || metadataValue("og:description", "property"),
      siteName: metadataValue("og:site_name", "property") || location.hostname,
      publishedTime: metadataValue("article:published_time", "property") || metadataValue("publish-date", "name"),
      canonicalUrl: absoluteUrl(canonical && canonical.getAttribute("href")) || location.href,
      language: document.documentElement.getAttribute("lang") || navigator.language || null,
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
