  function topChannelArticleContent(metadata) {
    if (!hostMatches(/(^|\.)top-channel\.tv$/)) return null;
    if (!/^\/\d{4}\/\d{2}\/\d{2}\//.test(location.pathname || "")) return null;

    var root = document.querySelector(".contentWrapper .siteWidthContainer");
    if (!root) return null;

    return profileArticleContent(metadata, root, {
      title: firstText([".titleInner h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title),
      byline: firstText([".titleInner .date", ".date"]) || metadata.byline,
      minTextLength: 500,
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, "article:first-of-type, .adGroupWrapper, .featuredPoll, script, style");
      }
    });
  }

  registerHostAwareProfile(true, topChannelArticleContent);
