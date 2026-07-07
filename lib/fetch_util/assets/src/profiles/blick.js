function blickArticleContent(metadata) {
  if (!hostMatches(/(^|\.)blick\.ch$/)) return null;
  if (!/\/[^/]+-id\d+\.html(?:[?#].*)?$/i.test(location.pathname || "")) return null;

  var body = document.querySelector("article[class*='Body__StyledContainer']");
  if (!body) return null;

  return profileArticleContent(metadata, body, {
    title: function(meta) {
      return firstText(["h1", "main h1", "article h1"]) || (meta && meta.title);
    },
    byline: function(meta) {
      return firstText(["a[href*='/autoren/']", ".SingleAuthors__Wrapper-sc-86b5d69c-0", ".article-author", ".author"]) || (meta && meta.byline);
    },
    minTextLength: 250,
    rewriteRoot: function(root) {
      removeAll(root, "#containerPiano1, #containerPiano2, .CMPPlaceholder__Wrapper-sc-b34bbfca-0, .EmbeddedContent__StyledEmbeddedContentContainer-sc-5c959b4b-0");
    }
  });
}

registerHostAwareProfile(true, blickArticleContent);
