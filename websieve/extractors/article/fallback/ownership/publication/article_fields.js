function sourceOwnedArticlePublicationFields(metadata, ownership, article) {
  var sourceRoot = ownership && ownership.node && ownership.node.matches("article") ? ownership.node : ownership && ownership.ownerRoot;
  var publication = sourceOwnedFallbackPublication(metadata, sourceRoot, {
    node: sourceRoot,
    visibleNode: article
  });
  return {
    publishedTime: publication ? publication.publishedTime : null,
    sourceOwnedArticlePublicationResolved: !!publication
  };
}

function sourceOwnedMediaPublication(ownership, metadata) {
  if (!ownership || ownership.proof !== "same-owner-source-headline-and-media" ||
      !metadata || !ownership.node.contains(ownership.heading) || !ownership.node.contains(ownership.media)) return null;
  var pageUrl = sourceOwnershipPageUrl(metadata.canonicalUrl);
  if (!pageUrl || pageUrl !== sourceOwnershipPageUrl(materializedCanonicalUrl())) return null;
  var publication = sourceOwnedPublicationRecords(ownership.title, pageUrl);
  if (!publication.records || publication.records.length > 1) return { publishedTime: null };
  var recordDate = publication.records.length ? entityText(publication.records[0].datePublished) : "";
  var head = sourceOwnedHeadPublicationTime();
  if (head.ambiguous ||
      (head.value && recordDate && !sourceOwnedPublicationDatesEquivalent(head.value, recordDate))) return { publishedTime: null };
  var visible = sourceOwnedMediaVisiblePublication(ownership);
  if (visible.ambiguous || (visible.value && (recordDate && !sourceOwnedPublicationDatesEquivalent(visible.value, recordDate) ||
      head.value && !sourceOwnedPublicationDatesEquivalent(visible.value, head.value)))) return { publishedTime: null };
  return { publishedTime: visible.value || head.value || recordDate || null };
}

function sourceOwnedMediaVisiblePublication(ownership) {
  var owner = ownership.media.closest("article") || ownership.node;
  var related = ownership.relatedCollection;
  var fields = Array.from(owner.querySelectorAll("time[datetime], [itemprop~='datePublished' i], [class*='published' i]")).filter(function(node) {
    if (related && related.contains(node) || elementSubtreeHidden(node) || visiblePublicationSchedule(node) ||
        node.matches("article, main, [role='main']") ||
        node.querySelector("article, main, h1, h2, h3, h4, figure, blockquote, pre, table, a[href]") ||
        node.closest("aside, nav, footer, form, figure, figcaption, blockquote, [role='note'], [role='complementary'], " +
          "[class*='related' i], [class*='recommend' i], [class*='sidebar' i]") ||
        sourceOwnedMediaModifiedField(node, owner) ||
        node.closest("article") !== owner.closest("article") ||
        !(ownership.heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    var label = normalizeText(node.textContent || "");
    if (/^(?:updated|last updated|modified)\b/i.test(label)) return false;
    if (node.matches("time[datetime]") && !node.matches("[itemprop~='datePublished' i], [class*='published' i]") &&
        !sourceOwnedMediaPlainTimeField(node, owner, label)) return false;
    return visiblePublicationDateLike(sourceOwnedPublicationNodeDate(node));
  });
  fields = fields.filter(function(node) {
    return !fields.some(function(other) { return other !== node && other.contains(node); });
  });
  return sourceOwnedUniquePublicationValue(fields.map(sourceOwnedPublicationNodeDate));
}

function sourceOwnedMediaModifiedField(node, owner) {
  for (var field = node; field && field !== owner; field = field.parentElement) {
    if (field.matches("[itemprop~='dateModified' i]") ||
        /(?:^|[\s_-])(?:updated|modified)(?:$|[\s_-])/i.test(field.getAttribute("class") || "")) return true;
  }
  return false;
}

function sourceOwnedMediaPlainTimeField(node, owner, label) {
  if (node.closest("p, blockquote, figure, figcaption")) return false;
  var header = node.closest("header, [class*='entry-meta' i], [class*='post-meta' i], [class*='article-meta' i]");
  if (header && owner.contains(header) && !header.contains(owner) && !header.querySelector("video, audio, iframe")) return true;
  return node.parentElement === owner && /^(?:published|posted)\b/i.test(label);
}
