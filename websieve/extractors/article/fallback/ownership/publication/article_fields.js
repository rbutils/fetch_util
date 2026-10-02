function sourceOwnedArticlePublicationFields(metadata, ownership, article) {
  var sourceRoot = ownership && ownership.node && ownership.node.matches("article") ? ownership.node : ownership && ownership.ownerRoot;
  var publication = sourceOwnedFallbackPublication(metadata, sourceRoot, {
    node: sourceRoot,
    visibleNode: article
  });
  return {
    publishedTime: publication ? publication.publishedTime : null,
    sourceOwnedArticlePublicationResolved: !!publication
  };
}
