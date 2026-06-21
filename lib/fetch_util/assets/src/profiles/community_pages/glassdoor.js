  function glassdoorContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)glassdoor\.com$/) && !/glassdoor/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/" && location.pathname !== "/index.htm") return null;

    var title = firstText(["main h1", "h1"]) || normalizeText((metadata.title || document.title).replace(/\s*\|.*$/, ""));
    var lines = manyTexts(["main h2", "main p"], 20).filter(function(text) {
      return text.length >= 12 && !/^(continue with google|continue with apple|or email|sign in|community jobs companies salaries for employers)$/i.test(text);
    });
    var description = lines.find(function(text) {
      return text !== title && text.length >= 40;
    }) || metadata.excerpt;
    var highlights = lines.filter(function(text) {
      return text !== title && text !== description;
    }).slice(0, 6);

    if (!title && !description) return null;

    return articleContentFromParts({
      title: title,
      description: description,
      highlights: highlights,
      siteName: metadata.siteName || "Glassdoor"
    });
  }
