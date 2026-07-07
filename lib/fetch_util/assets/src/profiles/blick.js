var blickArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)blick\.ch$/,
  pathPattern: /\/[^/]+-id\d+\.html(?:[?#].*)?$/i,
  bodySelectors: ["article[class*='Body__StyledContainer']"],
  titleSelectors: ["h1", "main h1", "article h1"],
  bylineSelectors: ["a[href*='/autoren/']", ".SingleAuthors__Wrapper-sc-86b5d69c-0", ".article-author", ".author"],
  removalSelectors: ["#containerPiano1", "#containerPiano2", ".CMPPlaceholder__Wrapper-sc-b34bbfca-0", ".EmbeddedContent__StyledEmbeddedContentContainer-sc-5c959b4b-0"],
  minBodyTextLength: 250
});

registerHostAwareProfile(true, blickArticleContent);
