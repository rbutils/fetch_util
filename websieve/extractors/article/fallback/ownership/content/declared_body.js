function sourceOwnedDeclaredArticleBodyOwnership(metadata) {
  var declared = focalSourceArticleMetadata();
  if (!declared || declared.typedArticles.length !== 1 || sourceOwnershipHasLiveblogEvidence()) return null;
  var entities = structuredDataNodes().filter(function(entity) {
    if (!nodeTypes(entity).some(function(type) { return /^(?:NewsArticle|ReportageNewsArticle|BlogPosting|Article)$/i.test(type); })) return false;
    var page = entity.mainEntityOfPage;
    if (page && typeof page === "object") page = page.url || page["@id"];
    return [entity.url, page].some(function(value) { return sourceOwnershipPageUrl(value) === declared.pageUrl; });
  });
  if (entities.length !== 1) return null;
  var entity = entities[0];
  var page = entity.mainEntityOfPage;
  if (page && typeof page === "object") page = page.url || page["@id"];
  if ([entity.url, page].filter(Boolean).some(function(value) {
    return sourceOwnershipPageUrl(value) !== declared.pageUrl;
  }) || typeof entity.articleBody !== "string") return null;
  var text = normalizeText(entity.articleBody);
  if (!text) return null;

  // The declaration proves ownership only when every declared block already
  // exists visibly and uniquely in source order. Never render declaration text.
  var blocks = Array.from(document.querySelectorAll("p, h2, h3, h4, h5, h6")).filter(function(node) {
    if (elementVisuallyHidden(node) || sourceOwnershipInChrome(node) ||
        node.closest("script, style, noscript, template, " + VISIBLE_COMMENT_THREAD_SELECTOR)) return false;
    var value = normalizeText(node.textContent || "");
    return !!value && text.indexOf(value) !== -1;
  });
  if (!blocks.length || normalizeText(blocks.map(function(node) { return node.textContent || ""; }).join(" ")) !== text) return null;
  var values = blocks.map(function(node) { return normalizeText(node.textContent || ""); });
  if (values.some(function(value, index) { return values.indexOf(value) !== index; })) return null;
  var bodyNode = blocks.reduce(function(owner, block) { return sourceOwnershipCommonAncestor(owner, block); });
  if (!bodyNode || bodyNode === document.body || bodyNode === document.documentElement) return null;
  var article = bodyNode.closest("article");
  if (!article || bodyNode === article || elementSubtreeHidden(article) || sourceOwnershipInChrome(article) ||
      commentRecordMarker(article) || article.closest(VISIBLE_COMMENT_THREAD_SELECTOR)) return null;
  if (blocks.some(function(block) { return block.closest("article") !== article; })) return null;
  var headings = Array.from(article.querySelectorAll("h1, h2, [itemprop~='headline' i]")).filter(function(heading) {
    return !bodyNode.contains(heading) && heading.closest("article") === article &&
      !elementVisuallyHidden(heading) && !sourceOwnershipInChrome(heading) &&
      sourceOwnedHeaderPrecedesBody(heading, bodyNode) && !!normalizeText(heading.textContent || "");
  });
  if (headings.length !== 1 || sourceArticleBodyHasForeignLinkedArticle(article, bodyNode, headings[0], declared.pageUrl)) return null;
  var body = focalOwnershipVisibleBody(bodyNode);
  if (!body) return null;
  body.sourceNode = bodyNode;
  body.primarySourceNode = bodyNode;
  var ownership = {
    node: bodyNode,
    ownerRoot: article,
    heading: headings[0],
    title: normalizeText(headings[0].textContent || ""),
    body: body,
    proof: "declared-complete-physical-article-body"
  };
  ownership.titleIdentityProven = declared.headlines.indexOf(ownership.title) !== -1 ||
    articleTitleFromOwnedHeading(ownership.heading.outerHTML, metadata && metadata.title, metadata && metadata.siteName) === ownership.title;
  var headerContext = sourceOwnedArticleHeaderContext(ownership);
  if (headerContext === false) return null;
  ownership.headerContext = headerContext;
  if (sourceOwnedArticleHasUncoveredMaterial(ownership)) return null;
  return ownership;
}

function sourceOwnedDeclaredArticleHeaderLead(ownership, metadata, renderedText) {
  if (!ownership || ownership.proof !== "declared-complete-physical-article-body") return null;
  var description = normalizeText(metadata && metadata.excerpt || "");
  if (!description || !renderedText || renderedText.indexOf(description) === -1) return null;
  var leads = sourceOwnedArticleHeaderNodes(ownership.headerContext).flatMap(function(header) {
    return Array.from(header.querySelectorAll("p")).filter(function(paragraph) {
      return !elementVisuallyHidden(paragraph) && !sourceOwnershipInChrome(paragraph) &&
        !paragraph.closest("figure, figcaption, blockquote, address, time, [itemprop~='author' i], [itemprop~='creator' i]") &&
        !paragraph.querySelector("button, input, textarea, select") &&
        !sourceOwnedPublicationField(paragraph) && normalizeText(paragraph.textContent || "") === description;
    });
  });
  return leads.length === 1 ? description : null;
}
