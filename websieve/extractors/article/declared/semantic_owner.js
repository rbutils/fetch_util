function declaredSemanticArticleContext() {
  var declared = focalSourceArticleMetadata();
  if (!declared || declared.typedArticles.length !== 1 || sourceOwnershipHasLiveblogEvidence()) return null;
  var entities = structuredDataNodes().filter(function(entity) {
    if (!nodeTypes(entity).some(function(type) { return /^(?:NewsArticle|ReportageNewsArticle)$/i.test(type); })) return false;
    var page = entity.mainEntityOfPage;
    if (page && typeof page === "object") page = page.url || page["@id"];
    return [entity.url, page].some(function(value) { return sourceOwnershipPageUrl(value) === declared.pageUrl; });
  });
  if (entities.length !== 1 || typeof entities[0].articleBody !== "string") return null;
  var entity = entities[0];
  var declaredHeadline = normalizeText(entity.headline || "");
  if (!declaredHeadline) return null;
  var page = entity.mainEntityOfPage;
  if (page && typeof page === "object") page = page.url || page["@id"];
  if ([entity.url, page].filter(Boolean).some(function(value) {
    return sourceOwnershipPageUrl(value) !== declared.pageUrl;
  })) return null;
  var body = normalizeText(entity.articleBody);
  if (!body) return null;

  // Scalar evidence precedes visibility work. The declaration never supplies
  // rendered paragraphs: it must match the complete ordered physical material.
  var paragraphs = Array.from(document.querySelectorAll("p")).filter(function(node) {
    var value = normalizeText(node.textContent || "");
    if (!value || body.indexOf(value) === -1) return false;
    return !node.closest("nav, aside, footer, form, script, style, noscript, template, " + VISIBLE_COMMENT_THREAD_SELECTOR) &&
      !elementVisuallyHidden(node) && !sourceOwnershipInChrome(node);
  });
  if (paragraphs.length < 2 || normalizeText(paragraphs.map(function(node) { return node.textContent || ""; }).join(" ")) !== body) return null;
  var values = paragraphs.map(function(node) { return normalizeText(node.textContent || ""); });
  if (values.some(function(value, index) { return values.indexOf(value) !== index; })) return null;
  var article = paragraphs[0].closest("article");
  if (!article || commentRecordMarker(article) || article.closest(VISIBLE_COMMENT_THREAD_SELECTOR) ||
      elementSubtreeHidden(article) || sourceOwnershipInChrome(article) ||
      paragraphs.some(function(node) { return node.closest("article") !== article; })) return null;
  var headings = Array.from(article.querySelectorAll("h1, [itemprop~='headline' i]")).filter(function(node) {
    return node.closest("article") === article && !elementVisuallyHidden(node) &&
      !sourceOwnershipInChrome(node) && normalizeText(node.textContent || "") === declaredHeadline;
  });
  if (headings.length !== 1 || !(headings[0].compareDocumentPosition(paragraphs[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
  return { root: article, heading: headings[0], title: normalizeText(headings[0].textContent || ""), paragraphs: paragraphs };
}

function declaredSemanticArticleContent(metadata) {
  var context = declaredSemanticArticleContext();
  if (!context) return null;
  var prepared = declaredArticleReferenceRoot(context);
  var content = docsContentForNode(metadata, prepared.root, {
    title: context.title,
    hostAware: false,
    focusFragment: false,
    preserveAuthoredSections: true,
    preserveCleanedRoot: true,
    rewriteRoot: function(root) {
      restoreDeclaredArticleReferences(root, prepared.references);
      materializeDeclaredArticleMedia(root);
    }
  });
  if (!content) return null;
  var publication = sourceOwnedArticlePublicationFields(metadata, { node: context.root, ownerRoot: context.root }, context.root);
  content.byline = metadata.byline || null;
  content.publishedTime = publication.sourceOwnedArticlePublicationResolved ? publication.publishedTime : null;
  content.sourceOwnedArticlePublicationResolved = publication.sourceOwnedArticlePublicationResolved;
  content.sourceOwnedDeclaredSemanticArticle = true;
  content.sourceOwnedGeneratedDocs = true;
  content.docsLike = false;
  content.excerpt = normalizeText(context.paragraphs[0].textContent || "");
  return content;
}

function sourceOwnedPrimaryContent(metadata, preparedManual) {
  return physicalOwnedReferenceContent(metadata) ||
    declaredSemanticArticleContent(metadata) || canonicalPublishedEntryContent(metadata) ||
    preparedManual || physicalStandaloneManualContent(metadata) || datedReferenceIndexContent(metadata) || declaredNewsPortalContent(metadata);
}
