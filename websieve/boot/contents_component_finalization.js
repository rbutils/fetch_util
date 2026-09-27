function contentsComponentFinalizationHtml(content) {
  if (content.sourceOwnedContentsComponent) {
    content.html = sourceOwnedContentsComponentHtml(content.html, content.sourceOwnedContentsComponent);
  }
  return content;
}

function contentsComponentFinalizationMarkdown(content, markdown) {
  if (!content.sourceOwnedContentsComponent) return markdown;
  return sourceOwnedContentsComponentMarkdown(markdown, content.sourceOwnedContentsComponent);
}
