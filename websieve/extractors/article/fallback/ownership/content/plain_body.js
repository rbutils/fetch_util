function sourceOwnedPlainArticleIdentity(metadata, heading) {
  var headline = normalizeText(heading.textContent || "");
  var value = function(property) {
    var nodes = Array.from(document.querySelectorAll("meta[property='" + property + "' i]"));
    var values = Array.from(new Set(nodes.map(function(node) { return normalizeText(node.getAttribute("content") || ""); })));
    return values.length === 1 ? values[0] : "";
  };
  var canonical = sourceOwnershipPageUrl(materializedCanonicalUrl());
  var declared = sourceOwnershipPageUrl(value("og:url"));
  var current = sourceOwnershipPageUrl(location.href);
  if (!headline || value("og:type").toLowerCase() !== "article" || value("og:title") !== headline ||
      !canonical || declared !== canonical || !current) return false;
  var target = new URL(canonical);
  var page = new URL(current);
  return target.origin === page.origin && target.pathname === page.pathname &&
    (!target.search || target.search === page.search) &&
    normalizeText(metadata.title || "").indexOf(headline) === 0;
}

function sourceOwnedPlainArticleBodyOwnership(metadata) {
  if (!metadata || homepageRootPath() || sourceOwnershipHasLiveblogEvidence()) return null;
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
  });
  if (headings.length !== 1 || !sourceOwnedPlainArticleIdentity(metadata, headings[0])) return null;
  var heading = headings[0];
  if (heading.closest("article")) return null;
  var candidates = Array.from(document.querySelectorAll("div, section")).filter(function(node) {
    return Array.from(node.classList).some(function(token) {
      return /^(?:article|story|post|entry)[-_](?:body|content)$/i.test(token);
    }) && !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
      !node.closest(VISIBLE_COMMENT_THREAD_SELECTOR) && !node.contains(heading) &&
      !!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
  });
  candidates = candidates.filter(function(node) {
    return !candidates.some(function(other) { return other !== node && node.contains(other); });
  });
  if (candidates.length !== 1) return null;
  var node = candidates[0];
  var owner = sourceOwnershipCommonAncestor(heading, node);
  if (!owner || owner === document.body || owner === document.documentElement ||
      sourceOwnershipInChrome(owner) || sourceArticleBodyHasForeignLinkedArticle(owner, node, heading, materializedCanonicalUrl())) return null;
  var body = focalOwnershipVisibleBody(node);
  if (!body || body.text.length < 120 || body.paragraphs < 2) return null;
  body.sourceNode = node;
  body.primarySourceNode = node;
  var ownership = {
    node: node, ownerRoot: owner, heading: heading, title: normalizeText(heading.textContent || ""),
    body: body, proof: "unique-canonical-headed-body-branch", titleIdentityProven: true
  };
  ownership.interfaceNodes = sourceOwnedPlainArticleInterfaceNodes(ownership);
  var header = sourceOwnedArticleHeaderContext(ownership);
  if (header === false) return null;
  ownership.headerContext = header;
  var dateFields = sourceOwnedArticleHeaderNodes(header).flatMap(function(root) {
    return [root].concat(Array.from(root.querySelectorAll("time, div, span")));
  }).filter(function(field) {
    if (field.querySelector("p, h1, h2, h3, blockquote, article, figure, pre, table") || elementSubtreeHidden(field)) return false;
    var value = field.getAttribute("datetime") || normalizeText(Array.from(field.childNodes).filter(function(child) {
      return child.nodeType === Node.TEXT_NODE;
    }).map(function(child) { return child.nodeValue; }).join(" "));
    return visiblePublicationDateLike(value) && sourceHeaderMetadataDateKey(value) === sourceHeaderMetadataDateKey(metadata.publishedTime);
  });
  if (dateFields.length !== 1) return null;
  ownership.contextNodes = Array.from(owner.querySelectorAll("[itemprop~='author' i], [class*='author' i], [class*='byline' i]")).filter(function(context) {
    return !node.contains(context) && !elementSubtreeHidden(context) && !sourceOwnershipInChrome(context) &&
      !!(node.compareDocumentPosition(context) & Node.DOCUMENT_POSITION_FOLLOWING) &&
      !context.closest(VISIBLE_COMMENT_THREAD_SELECTOR + ", " + VISIBLE_COMMENT_RECORD_SELECTOR) &&
      !context.querySelector("p, h1, h2, h3, article, blockquote, pre, table, form, input, textarea");
  });
  return sourceOwnedArticleHasUncoveredMaterial(ownership) ? null : ownership;
}

function sourceOwnedPlainArticleLead(ownership, renderedText) {
  if (!ownership || ownership.proof !== "unique-canonical-headed-body-branch") return null;
  var body = ownership.body.sourceNode;
  var paragraph = Array.from(body.querySelectorAll("p")).find(function(node) {
    var text = normalizeText(node.textContent || "");
    var repeatedTitle = text.replace(/^[（(]?[^：:]+[：:]\s*/, "").replace(/[）)]$/, "");
    if (!text || repeatedTitle === ownership.title || elementSubtreeHidden(node) ||
        sourceOwnershipInChrome(node) || fallbackExcerptChromeOwner(body, node) ||
        node.closest("blockquote, figure, figcaption, form, " + VISIBLE_COMMENT_RECORD_SELECTOR)) return false;
    for (var parent = node.parentElement; parent && parent !== body; parent = parent.parentElement) {
      if (parent.querySelector("video, audio") && /(?:^|[-_\s])(?:video|audio|media)(?:$|[-_\s])/i.test(parent.className || "")) return false;
    }
    return renderedText.indexOf(text) !== -1 && /\p{L}/u.test(text);
  });
  return paragraph ? normalizeText(paragraph.textContent || "") : null;
}
