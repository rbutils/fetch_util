function resultMarkdownCleanup(content) {
  if (hasSourceOwnedAccessIntroduction(content)) {
    return function(value) { return String(value || "").trim(); };
  }
  if (typeof content.sourceOwnedInstitutionalHtml === "string" && content.sourceOwnedInstitutionalHtml === content.html) {
    return function(value) { return String(value || "").trim(); };
  }
  if (typeof content.sourceOwnedDisclosureCatalogHtml === "string" && content.sourceOwnedDisclosureCatalogHtml === content.html) {
    return function(value) { return String(value || "").trim(); };
  }
  if (typeof content.sourceOwnedGeneratedReferenceHtml === "string" && content.sourceOwnedGeneratedReferenceHtml === content.html) {
    return function(value) { return String(value || "").trim(); };
  }
  if (content.sourceOwnedHomepageCollection === true || content.sourceOwnedDataRecord === true ||
      content.sourceOwnedNumberedInstrument === true || content.sourceOwnedIndexedPlay === true ||
      content.sourceOwnedDatedReferenceIndex === true || content.sourceOwnedSoftwareLanding === true ||
      content.sourceOwnedCanonicalDataTable === true) {
    return function(value) { return String(value || "").trim(); };
  }
  if (content.sourceOwnedUnattributedManual === true && content.sourceOwnedCleanedManualHtml === content.html) {
    return function(value) { return cleanupMarkdownNoise(value, true); };
  }
  return cleanupMarkdownNoise;
}

function resultLegalChromeMarkdown(content, markdown) {
  if (content.sourceOwnedGeneratedDocs === true || content.sourceOwnedProduct === true ||
      content.sourceOwnedIndexedPlay === true || content.sourceOwnedDatedReferenceIndex === true ||
      content.sourceOwnedDisclosureCatalog === true || content.sourceOwnedCanonicalDataTable === true) return markdown;
  return stripLeadingLegalInstitutionalChrome(markdown);
}
