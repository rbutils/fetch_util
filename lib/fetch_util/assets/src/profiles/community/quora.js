  function quoraContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)quora\.com$/)) return null;
    if (!/(security verification|just a moment|protect against malicious bots)/i.test(pageText || "")) return null;

    var slug = safeDecodeURI((location.pathname || "").split("/").filter(Boolean)[0] || "").replace(/[-_]+/g, " ");
    slug = normalizeText(slug);
    if (!slug || /^just a moment$/i.test(slug)) return null;

    return articleContentFromParts({
      title: slug,
      description: metadata.excerpt,
      siteName: metadata.siteName || "Quora"
    });
  }
