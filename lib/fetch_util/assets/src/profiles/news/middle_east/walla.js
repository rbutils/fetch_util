function wallaArticleContent(metadata) {
  if (!hostMatches(/(^|\.)walla\.co\.il$/)) return null;

  var root = document.querySelector("main article.common-item, article.common-item, section.item-main-content");
  if (!root) return null;

  return profileArticleContent(metadata, root, {
    title: firstText(["h1.title", "header h1", "h1"]) || metadata.title,
    byline: firstText([".writers-names", ".writer-name-item", ".date-and-time-p"]) || metadata.byline,
    minTextLength: 600,
    rewriteRoot: function(cleanRoot) {
      removeAll(cleanRoot, [
        ".tags-and-breadcrumbs",
        ".share-panel",
        ".under-talkback-wrapper",
        "[class*='taboola' i]",
        "[class*='trc-' i]",
        "[class*='articles-wrapper' i]",
        "[class*='reco-reel' i]",
        "script",
        "style"
      ].join(", "));

      cleanRoot.querySelectorAll("section.article-content h3").forEach(function(heading) {
        var paragraph = document.createElement("p");
        paragraph.innerHTML = heading.innerHTML;
        heading.replaceWith(paragraph);
      });
    }
  });
}

registerHostAwareProfile(true, wallaArticleContent);
