function resultMarkdownCleanup(content) {
  if (content.sourceOwnedHomepageCollection === true || content.sourceOwnedDataRecord === true ||
      content.sourceOwnedNumberedInstrument === true || content.sourceOwnedIndexedPlay === true ||
      content.sourceOwnedDatedReferenceIndex === true) {
    return function(value) { return String(value || "").trim(); };
  }
  if (content.sourceOwnedUnattributedManual === true && content.sourceOwnedCleanedManualHtml === content.html) {
    return function(value) { return cleanupMarkdownNoise(value, true); };
  }
  return cleanupMarkdownNoise;
}
