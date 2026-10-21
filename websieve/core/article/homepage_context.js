function homepageFlatPublicationProse(node) {
  if (!node.matches("div, section") || elementSubtreeHidden(node) ||
      node.matches("[role='navigation'], [role='banner'], [role='dialog'], [role='alertdialog'], " +
        "[role='complementary'], [role='contentinfo'], [role='button']") ||
      cookieConsentInterfaceNode(node)) return false;
  var inline = new Set(["a", "b", "br", "em", "i", "mark", "s", "small", "span", "strong", "sub", "sup", "u"]);
  var complete = Array.from(node.querySelectorAll("*")).every(function(child) {
    if (!inline.has(child.localName) || child.matches("[role='button'], [role='navigation'], [role='dialog']")) return false;
    return child.localName !== "a" || !!materializedHttpUrl(child.getAttribute("href"));
  });
  return complete && readerSectionParagraphNarrative(node);
}

function homepagePublicationContext(sourceRoot, renderedRoot) {
  if (!sourceRoot || !sourceRoot.isConnected || !renderedRoot || !document.body ||
      !document.body.matches(".home.page") || !homepageRootPath()) return renderedRoot;
  var page = sourceRoot.closest("article.page, article.type-page");
  if (!page) return renderedRoot;
  var canonical = document.querySelectorAll("link[rel~='canonical' i]");
  if (canonical.length !== 1 || sourceOwnershipPageUrl(canonical[0].getAttribute("href")) !==
      sourceOwnershipPageUrl(location.href)) return renderedRoot;

  return withSourceVisibilityRead(function() {
    var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(main) {
      return !elementSubtreeHidden(main);
    });
    if (mains.length !== 1 || !mains[0].contains(page)) return renderedRoot;
    var pages = Array.from(mains[0].querySelectorAll("article.page, article.type-page")).filter(function(owner) {
      return !elementSubtreeHidden(owner);
    });
    if (pages.length !== 1 || pages[0] !== page) return renderedRoot;
    var prose = Array.from(document.body.children).filter(function(node) {
      return !node.contains(sourceRoot) && homepageFlatPublicationProse(node);
    });
    if (!prose.length) return renderedRoot;

    var entries = prose.map(function(source) {
      return {source: source, clone: visibilityPrunedClone(source, document)};
    });
    entries.push({source: sourceRoot,
      clone: renderedRoot.isConnected ? visibilityPrunedClone(renderedRoot, document) : renderedRoot});
    entries.sort(function(left, right) {
      return left.source.compareDocumentPosition(right.source) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });
    var wrapper = document.createElement("div");
    entries.forEach(function(entry) { wrapper.appendChild(entry.clone); });
    return wrapper;
  });
}
