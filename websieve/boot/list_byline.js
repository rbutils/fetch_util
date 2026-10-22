function listPagePrimaryUrlKeys(content) {
  var extraction = content && content.listExtraction;
  var items = extraction && extraction.items || content && content.listSourceItems || [];
  return new Set(items.map(function(item) {
    return listCanonicalKey(item && item.url);
  }).filter(Boolean));
}

function listPageBylineOwnedByRecord(node, primaryUrlKeys) {
  if (!node || primaryUrlKeys.size < 2) return false;
  return Array.from(document.querySelectorAll("a[href]")).some(function(link) {
    var key = listCanonicalKey(materializedHttpUrl(link.getAttribute("href")));
    if (!key || !primaryUrlKeys.has(key)) return false;
    var card = listCardRoot(link, link.parentElement);
    return card && genericListCardBoundary(card) && card.contains(node);
  });
}

function listPageBylineSourceOwnership(value, content) {
  var key = normalizeText(value || "").toLowerCase();
  var primaryUrlKeys = listPagePrimaryUrlKeys(content);
  var ownership = { local: false, global: false, recordCount: primaryUrlKeys.size };
  if (!key || primaryUrlKeys.size < 2) return ownership;

  var selector = [
    "[rel='author']",
    "[itemprop='author'] [itemprop='name']",
    "[itemprop='author']",
    "[class*='byline' i]",
    "[class*='author' i]",
    "[class*='autor' i]",
    "[class*='auteur' i]",
    "[class*='verfasser' i]",
    "[class*='redakteur' i]",
    "[class*='penulis' i]",
    "[class*='tac-gia' i]",
    "[class*='tacgia' i]",
    "[class*='writer' i]",
    "[class*='reporter' i]",
    "[data-testid*='author' i]"
  ].join(", ");

  Array.from(document.querySelectorAll(selector)).forEach(function(node) {
    if (elementVisuallyHidden(node) || node.closest("nav, footer, aside")) return;
    if (normalizeText(sanitizeByline(node.textContent) || "").toLowerCase() !== key) return;
    if (listPageBylineOwnedByRecord(node, primaryUrlKeys)) ownership.local = true;
    else ownership.global = true;
  });
  return ownership;
}

function listPageByline(byline, metadata, content) {
  var value = normalizeText(byline || "");
  if (!value || !content || content.contentType !== "list") return byline;

  var key = value.toLowerCase();
  var declared = [metadata && metadata.declaredByline, content.hostAware && content.byline].some(function(candidate) {
    return normalizeText(candidate || "").toLowerCase() === key;
  });
  if (declared) return byline;

  var sourceOwnership = listPageBylineSourceOwnership(value, content);
  if (sourceOwnership.recordCount < 2) return byline;
  return sourceOwnership.local && !sourceOwnership.global ? null : byline;
}

function collectionPublishedTime(content, metadata) {
  if (content.sourceOwnedLiveblog && !content.isolatedLiveblogEntry) return content.publishedTime || null;
  if (content.sourceOwnedArticlePublicationResolved === true) return content.publishedTime || null;
  if (content.contentType === "list" || (content.contentType === "social" && content.socialKind === "feed")) {
    return content.publishedTime || null;
  }
  return content.publishedTime || metadata.publishedTime;
}
