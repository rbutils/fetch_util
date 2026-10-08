  function visibleDeclaredArticleBody(selectedText) {
    var articles = structuredDataNodes().filter(function(entity) {
      return nodeTypes(entity).some(function(type) {
        return /^(?:Article|NewsArticle|ReportageNewsArticle|AnalysisNewsArticle|OpinionNewsArticle)$/.test(type);
      }) && entityText(entity.articleBody);
    });
    if (articles.length !== 1) return null;
    var body = entityText(articles[0].articleBody);
    if (selectedText && selectedText.indexOf(body) !== -1) return null;
    var chrome = "nav, aside, footer, dialog, [role='complementary']";
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.closest(chrome);
    });
    if (headings.length !== 1) return null;
    var headline = entityText(articles[0].headline);
    if (headline && normalizeText(headings[0].textContent) !== headline) return null;
    var owners = Array.from(document.querySelectorAll("article")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.closest(chrome) &&
        (headings[0].compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING || node.contains(headings[0])) &&
        normalizeText(visibilityPrunedClone(node, document).textContent).indexOf(body) !== -1;
    }).filter(function(node, _index, all) {
      return !all.some(function(other) { return other !== node && node.contains(other); });
    });
    return owners.length === 1 ? { node: owners[0], heading: headings[0], text: body } : null;
  }

  function supplementOwnedReaderDeclaredBody(content, metadata) {
    if (!content || !content.readerMode || !content.html) return content;
    var ownership = visibleDeclaredArticleBody(normalizeText(content.textContent));
    if (!ownership || ownership.node.contains(ownership.heading)) return content;
    var root = document.createElement("div");
    root.innerHTML = content.html;
    if (normalizeText(root.textContent).indexOf(ownership.text) !== -1) return content;
    if (!sourceOwnedReaderHeadlineTitleMatches(ownership.heading.textContent, content, metadata)) return content;
    var headOwner = ownership.heading.closest("article");
    if (!headOwner || !(headOwner.compareDocumentPosition(ownership.node) & Node.DOCUMENT_POSITION_FOLLOWING)) return content;
    var owners = Array.from(document.querySelectorAll("article")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.parentElement.closest("article") &&
        !node.closest("nav, aside, footer, dialog, [role='complementary']");
    });
    if (owners.length !== 2 || owners.indexOf(headOwner) === -1 || owners.indexOf(ownership.node) === -1) return content;
    // A short lead can have only one paragraph, below Reader's multi-paragraph
    // provenance threshold. Require every selected text/resource/code unit to
    // belong to this unique physical header before appending its declared body.
    if (!articleMaterialPreserved(root, visibilityPrunedClone(headOwner, document))) return content;
    var body = cleanClone(visibilityPrunedClone(ownership.node, document));
    cleanupGenericArticleRoot(body);
    if (normalizeText(body.textContent).indexOf(ownership.text) === -1) return content;
    root.appendChild(body);
    content.html = root.innerHTML;
    content.textContent = normalizeText(root.textContent);
    return content;
  }
