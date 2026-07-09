var protothemaArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)protothema\.gr$/i,
  pathPattern: /\/article\/\d+\//i,
  body: function() {
    var section = document.querySelector("main .section.mainSection");
    if (!section) return null;

    var wrapper = document.createElement("div");
    var article = document.createElement("article");
    article.appendChild(section.cloneNode(true));
    wrapper.appendChild(article);
    return wrapper;
  },
  titleSelectors: [".headerArticleInfo h1", "main .section.mainSection h1", "h1"],
  minBodyTextLength: 250,
  removalSelectors: [
    ".breadcrumbs",
    ".article-meta-links",
    ".article-flow-note",
    "[class*='share' i]",
    "[class*='related' i]",
    "[class*='recommend' i]",
    "[class*='popular' i]",
    "[class*='newsletter' i]",
    "[class*='ad' i]",
    "script",
    "style",
    "iframe"
  ]
});

registerHostAwareProfile(true, protothemaArticleContent);
