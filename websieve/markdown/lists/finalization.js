function deferredListFinalizationMarkdown(content, metadata, markdown) {
  var listLikeContent = content.contentType === "list" ||
    (content.contentType === "social" && content.socialKind === "feed");
  var listExtraction = content.listExtraction;
  var sourceTableMarkdown = listExtraction && listExtraction.sourceTableMarkdown;
  if (listLikeContent && content.sectionMarkdownWithDescription && !sourceTableMarkdown) {
    markdown = materializedMarkdown(cleanupMarkdownNoise(content.sectionMarkdownWithDescription));
    content.textContent = markdown;
  }
  if (listLikeContent && listExtraction && content.markdown === listExtraction.markdown && !sourceTableMarkdown) {
    var inlineDescriptionMarkdown = listExtraction.sectionCount ? listMarkdownWithMetadataReferences(listExtraction) :
      listMarkdownWithInlineDescriptions(listExtraction);
    if (inlineDescriptionMarkdown) {
      markdown = materializedMarkdown(cleanupMarkdownNoise(inlineDescriptionMarkdown));
      content.textContent = markdown;
    }
  }
  var controlledPanelMarkdown = listMarkdownWithControlledPanels(content, metadata, markdown);
  if (controlledPanelMarkdown) {
    markdown = materializedMarkdown(cleanupMarkdownNoise(controlledPanelMarkdown));
    content.textContent = markdown;
  }
  var searchToolsMarkdown = homepageSearchToolsMarkdown(content, markdown);
  if (searchToolsMarkdown) {
    markdown = materializedMarkdown(cleanupMarkdownNoise(searchToolsMarkdown));
    content.textContent = markdown;
  }
  if (listLikeContent) markdown = listMarkdownWithPresentationUrls(markdown);
  return markdown;
}
