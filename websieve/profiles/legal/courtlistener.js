  function courtListenerOpinionContent(metadata) {
    if (!hostMatches(/(^|\.)courtlistener\.com$/i)) return null;
    if (!/^\/opinion\/\d+\//i.test(location.pathname || "")) return null;

    var root = document.querySelector("#opinion-content, .opinion-content, [data-testid='opinion-content'], article .opinion") ||
      document.querySelector("article") ||
      document.querySelector("main");
    if (!root || textLength(root) < 700) return null;

    return profileHtmlContent(metadata, root, {
      title: normalizeText(((document.querySelector("main h1, article h1, h1") || {}).textContent) || metadata.title || document.title),
      byline: function() { return firstText([".author", ".judge", ".judges", "[class*='judge' i]"]) || null; },
      siteName: metadata.siteName || "CourtListener",
      minTextLength: 700,
      rewriteRoot: function(clone) {
        clone.querySelectorAll([
          "script",
          "style",
          "nav",
          "aside",
          "form",
          ".sidebar",
          ".breadcrumb",
          ".breadcrumbs",
          ".alert",
          ".btn",
          ".share",
          ".citation-links",
          ".download-menu",
          "[class*='citation' i]",
          "[class*='download' i]",
          "[class*='related' i]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      },
      validateMarkdown: function(_markdown, text) {
        return /\b(?:v\.|versus|plaintiff|defendant|appellant|appellee|court|appeal|opinion|judgment)\b/i.test(text);
      },
      extra: { legalOpinion: true }
    });
  }
