  function secEdgarFilingContent(metadata) {
    if (!hostMatches(/(^|\.)sec\.gov$/i)) return null;
    if (!/^\/Archives\/edgar\/data\//i.test(location.pathname || "")) return null;

    var root = document.querySelector("#formDiv, .formContent, #main-content, main, body");
    if (!root) return null;

    var title = firstText(["#formName", ".formName", "h1", "h2"]) || normalizeText(metadata.title || document.title);
    return profileHtmlContent(metadata, root, {
      title: title || "SEC EDGAR filing",
      byline: null,
      siteName: "SEC EDGAR",
      publishedTime: null,
      minTextLength: 500,
      cleanupRoot: false,
      rewriteRoot: function(clone) {
        clone.querySelectorAll("script, style, noscript, iframe, form, input, button, nav").forEach(function(el) { el.remove(); });
      },
      postProcessMarkdown: function(markdown) {
        return markdown.replace(/\n{4,}/g, "\n\n\n").trim();
      },
      extra: { secFiling: true }
    });
  }
