function sourceOwnedSplitArticleContent(metadata) {
  var declared = focalSourceArticleMetadata();
  if (!declared || declared.typedArticles.length !== 1 || sourceOwnershipHasLiveblogEvidence()) return null;
  var entity = declared.typedArticles[0];
  if (!entity.headline) return null;
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
  });
  if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== entity.headline) return null;
  var heading = headings[0];
  var header = heading.closest("[class~='article--header'], [class~='article__header'], [data-article-header]");
  if (!header || elementSubtreeHidden(header) || sourceOwnershipInChrome(header)) return null;
  var bodies = Array.from(document.querySelectorAll("[class~='article--content'], [class~='article__content'], [data-article-body]")).filter(function(node) {
    return !header.contains(node) && !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
      !!(header.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
  });
  var preview = null;
  if (bodies.length === 2) {
    var leadRole = /(?:^|\s)article(?:--|__)content[-_](?:free|preview|lead|summary)(?:\s|$)/i;
    var bodyRole = /(?:^|\s)article(?:--|__)content[-_](?:paid|full|body)(?:\s|$)/i;
    if (!leadRole.test(bodies[0].className) || !bodyRole.test(bodies[1].className) ||
        bodies[0].contains(bodies[1]) || !focalOwnershipVisibleBody(bodies[0]) ||
        sourceArticleBodyHasForeignLinkedArticle(bodies[0], bodies[0], heading, declared.pageUrl)) return null;
    preview = bodies[0];
  } else if (bodies.length !== 1) return null;
  var node = bodies[bodies.length - 1];
  if (node.contains(header) || sourceArticleBodyHasForeignLinkedArticle(node, node, heading, declared.pageUrl)) return null;
  var body = focalOwnershipVisibleBody(node);
  if (!body) return null;
  var headers = preview ? [header, preview] : [header];
  var description = normalizeText(metadata && metadata.excerpt || "");
  var leads = description ? Array.from(document.querySelectorAll("p")).filter(function(lead) {
    return !node.contains(lead) && !headers.some(function(root) { return root.contains(lead); }) &&
      !elementSubtreeHidden(lead) && !sourceOwnershipInChrome(lead) && !lead.closest("blockquote, q, pre, code") &&
      normalizeText(lead.textContent || "") === description &&
      !!(heading.compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING) &&
      !!(lead.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
  }) : [];
  if (leads.length > 1) return null;
  if (leads.length === 1) headers.push(leads[0]);
  headers.sort(function(left, right) { return left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1; });
  body.sourceNode = node;
  body.primarySourceNode = node;
  var ownership = {
    node: node,
    ownerRoot: sourceOwnershipCommonAncestor(header, node),
    heading: heading,
    title: normalizeText(heading.textContent || ""),
    body: body,
    headerContext: headers,
    proof: "declared-split-article-regions"
  };
  return canonicalArticleBodyContent(metadata, ownership);
}
