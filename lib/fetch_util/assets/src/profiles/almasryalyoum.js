function almasryalyoumArticleContent(metadata) {
  if (!hostMatches(/(^|\.)almasryalyoum\.com$/)) return null;
  if (homepageRootPath()) return null;
  if (!/\/news\/details\/\d+\/?$/i.test(location.pathname || "")) return null;

  var body = composeProfileArticleRoot({
    scopeSelectors: [".masry-article-details"],
    titleSelectors: [".article-title", "h1"],
    captionSelectors: [".article-main-img"],
    bodySelectors: [".article-details.update-font", ".article-details"],
    minTextLength: 250
  });

  if (!body) return null;

  return profileArticleContent(metadata, body, {
    minTextLength: 250,
    extra: { docsLike: true },
    rewriteRoot: function(root) {
      removeAll(root, [
        "style",
        "script",
        "iframe",
        ".related-article-inside-body",
        ".masry-article-horizontal-ads",
        ".no-print",
        "[class*='share' i]",
        "[class*='social' i]",
        "[class*='ad' i]"
      ].join(", "));
    }
  });
}

registerHostAwareProfile(true, almasryalyoumArticleContent);
