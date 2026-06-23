  function nextJsDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)nextjs\.org$/) && !/next\.js/i.test(signature)) return null;
    if (!/^\/docs\//.test(location.pathname)) return null;

    return docsContentBySelectors(metadata, ["main article", "main .prose", "main [data-docs-body]"], {
      titleSelectors: ["main article h1", "main .prose h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*[|·-]\s*Next\.js$/i, "")); }
    });
  }

  function reactDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)react\.dev$/) && !/react/i.test(signature)) return null;
    if (!/^\/(reference|learn)\//.test(location.pathname)) return null;

    return docsContentBySelectors(metadata, ["main article", "main [data-pagefind-body]", "main .max-w-4xl article"], {
      titleSelectors: ["main article h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*[–-]\s*React$/i, "")); }
    });
  }
