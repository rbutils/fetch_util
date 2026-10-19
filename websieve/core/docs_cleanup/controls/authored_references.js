var docsAuthoredReferenceContexts = new WeakMap();
var docsAuthoredArticleContexts = new WeakSet();

function docsAuthoredSourceReferences(root) {
  return withSourceVisibilityRead(function() {
    return Array.from(root.querySelectorAll("a[href]")).filter(function(link) {
      if (!normalizeText(link.getAttribute("href"))) return false;
      if (link.closest("nav, [role='navigation'], [role='toolbar'], [role='menu'], [role='dialog'], dialog, form, button, [role='button'], [role='tab'], [aria-controls], pre, code, kbd, samp")) return false;
      var owner = link.closest("p, li, dt, dd, td, th, blockquote, h1, h2, h3, h4, h5, h6");
      return !!(owner && root.contains(owner) && !elementSubtreeHidden(link));
    });
  });
}

function rememberDocsAuthoredReferences(root, source, readableSource, references, sourceClones, cleanedElements) {
  if (source.nodeType === Node.ELEMENT_NODE && source.ownerDocument === document && source.isConnected &&
      source.closest("article, [itemprop~='articleBody']")) docsAuthoredArticleContexts.add(root);
  if (!references.length) return;
  var preserved = new WeakSet();
  references.forEach(function(reference) {
    var readable = source === readableSource ? reference : sourceClones.get(reference);
    var clone = readable && cleanedElements.get(readable);
    if (clone && root.contains(clone)) preserved.add(clone);
  });
  docsAuthoredReferenceContexts.set(root, preserved);
}

function docsAuthoredReferenceNode(root, node) {
  var references = docsAuthoredReferenceContexts.get(root);
  if (!references) return false;
  var containing = node.closest("a");
  if (containing && references.has(containing)) return true;
  return Array.from(node.querySelectorAll("a")).some(function(link) { return references.has(link); });
}

function docsAuthoredArticleNode(root, node) {
  return docsAuthoredArticleContexts.has(root) && root.contains(node);
}

function docsMarkdownForRoot(root, preserveCleanedRoot) {
  if (typeof TurndownService !== "function") return root.innerHTML;
  var references = docsAuthoredReferenceContexts.get(root);
  var articleOwned = docsAuthoredArticleContexts.has(root);
  // Removing controls can leave adjacent text nodes. Coalescing them changes
  // neither serialized HTML nor program text, and matches the ordinary parser.
  if (references || articleOwned) root.normalize();
  var parsed = document.createElement("div");
  parsed.innerHTML = root.innerHTML;
  var sourceChildren = Array.from(root.childNodes);
  var parsedChildren = Array.from(parsed.childNodes);
  if ((references || articleOwned) && sourceChildren.length === parsedChildren.length && sourceChildren.every(function(child, index) {
    return child.isEqualNode(parsedChildren[index]);
  })) {
    if (articleOwned) docsAuthoredArticleContexts.add(parsed);
    if (references) {
      var preserved = new WeakSet();
      var parsedLinks = parsed.querySelectorAll("a");
      root.querySelectorAll("a").forEach(function(link, index) {
        if (references.has(link)) preserved.add(parsedLinks[index]);
      });
      docsAuthoredReferenceContexts.set(parsed, preserved);
    }
  }
  return convertMarkdownRoot(parsed, false, true, preserveCleanedRoot);
}
