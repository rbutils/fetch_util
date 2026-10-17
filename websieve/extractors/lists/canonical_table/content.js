function canonicalDataTableContent(metadata, preparedContext) {
  var context = preparedContext || canonicalDataTableContext(metadata);
  if (!context) return null;
  return withInertDomWork(function() {
    var clone = visibilityPrunedClone(context.root, document);
    if (!clone) return null;
    var holder = document.createElement("div");
    holder.appendChild(clone);
    try {
      cleanDisposableClone(clone);
      cleanupAgentRoot(holder);
      materializeHttpAttributes(holder, false, false);
      var html = holder.innerHTML;
      var markdown = markdownFromDisposableRoot(holder, false, true, true, turndownBlockUnits).trim();
      var content = listItemsContentResult(metadata, {
        title: context.title,
        excerpt: context.description,
        html: html,
        markdown: markdown,
        textContent: normalizeText(markdown)
      });
      content.sourceOwnedCanonicalDataTable = true;
      return content;
    } finally { holder.replaceChildren(); }
  })();
}
