function gitlabResourceTitle(metadata, surface) {
  var heading = firstText(["[data-testid='issuable-title']", ".merge-request .title", "main h1", ".page-title"]);
  var base = normalizeText(heading || metadata.title || document.title || "GitLab merge request");
  return base + " - " + surface;
}

function gitlabResourceEmptyMarkdown(root) {
  var selector = "[data-testid='empty-state'], .gl-empty-state, .empty-state, .nothing-here-block, .blank-state";
  var nodes = Array.prototype.slice.call(root.querySelectorAll(selector));
  if (root.matches && root.matches(selector)) nodes.unshift(root);
  var markdown = nodes.map(function(candidate) {
    if (elementSubtreeHidden(candidate)) return "";

    var clone = visibilityPrunedClone(candidate);
    return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  }).find(function(value) {
    return !!normalizeText(value);
  });
  return markdown || "";
}

function gitlabResourceResult(title, sections, htmlNodes) {
  var markdown = sections.filter(Boolean).join("\n\n");
  var html = htmlNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n");
  return {
    title: title,
    siteName: "GitLab",
    excerpt: normalizeText(markdown).slice(0, 300),
    html: html,
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "list"
  };
}
