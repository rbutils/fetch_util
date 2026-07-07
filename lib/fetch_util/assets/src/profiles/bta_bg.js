  var btaBgArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)bta\.bg$/,
    pathPattern: /^\/bg\/news\//,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: [".post__content"],
    title: function(metadata) { return (metadata && metadata.title) || firstText([".post h1", "main h1", "h1"]) || normalizeText(document.title || ""); },
    bylineSelectors: [".post__author", ".post .author", "[rel='author']"],
    removalSelectors: [".post__footer", ".news-card", ".share", ".social", ".banner", "[class*='advert' i]", "[id*='ad-' i]", "script", "style"],
    minBodyTextLength: 250,
    rewriteRoot: function(root) { root.querySelectorAll("a[href]").forEach(function(link) { link.removeAttribute("href"); }); }
  });

  function btaBgArticlePage() {
    if (!hostMatches(/(^|\.)bta\.bg$/)) return false;
    if (homepageRootPath()) return false;
    return /^\/bg\/news\//.test(location.pathname || "") && !!document.querySelector(".post__content");
  }

  registerHostAwareProfile(true, btaBgArticleContent);