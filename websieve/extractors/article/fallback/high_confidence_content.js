function highConfidenceFallbackContent(metadata) {
  if (commentOnlyRoot(document.body) && !fallbackFocalArticleRoot(document.body)) return nonArticleContent();
  var legal = legalProvisionContent();
  if (legal) return legal;

  var record = structuredSourceRecordOwnership(metadata);
  var content = sourceRecordFallbackContent(metadata, record);
  if (!content) return null;
  content.title = metadata.title;
  return content;
}
