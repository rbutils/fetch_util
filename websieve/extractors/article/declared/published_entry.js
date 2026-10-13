function canonicalPublishedEntryContext(metadata) {
  var declared = focalSourceArticleMetadata();
  if (!declared || declared.typedArticles.length || sourceOwnershipHasLiveblogEvidence()) return null;
  var current = focalCanonicalUrl(location.href);
  if (!/^https?:\/\//i.test(current) || declared.pageUrl !== current) return null;
  var titles = declared.headlines.concat([(metadata && metadata.title) || "", document.title || ""])
    .map(function(value) { return normalizeText(value); }).filter(Boolean);
  var entries = Array.from(document.querySelectorAll(".hentry.type-post.status-publish")).filter(function(root) {
    if (!root.parentElement || root.matches("html, body")) return false;
    if (root.parentElement.closest(".hentry") || commentRecordMarker(root)) return false;
    var headings = Array.from(root.querySelectorAll("h1")).filter(function(heading) {
      return heading.closest(".hentry") === root && !heading.closest("nav, aside, footer, form");
    });
    if (headings.length !== 1) return false;
    var heading = headings[0];
    var title = normalizeText(heading.textContent || "");
    if (!title || !titles.length || titles.some(function(value) {
      return value !== title && [" | ", " - ", " — ", " – "].every(function(separator) {
        return value.indexOf(title + separator) !== 0;
      });
    })) return false;
    var bookmarks = Array.from(heading.querySelectorAll("a[rel~='bookmark' i][href]"));
    if (bookmarks.length !== 1 || focalCanonicalUrl(bookmarks[0].href) !== current ||
        normalizeText(bookmarks[0].textContent || "") !== title) return false;
    return !elementSubtreeHidden(root) && !elementVisuallyHidden(heading) &&
      !sourceOwnershipArticleChrome(root, root);
  });
  if (entries.length !== 1) return null;
  var root = entries[0];
  var heading = root.querySelector("h1");
  var paragraphs = Array.from(root.querySelectorAll("p")).filter(function(node) {
    return node.closest(".hentry") === root && sourceRecordBefore(heading, node) &&
      !node.closest("nav, aside, footer, form, " + VISIBLE_COMMENT_THREAD_SELECTOR) &&
      !sourceOwnershipArticleChrome(node, root) && !elementVisuallyHidden(node) &&
      normalizeText(node.textContent || "");
  });
  if (paragraphs.length < 2) return null;
  return { root: root, heading: heading, title: normalizeText(heading.textContent || ""), lead: paragraphs[0] };
}

function canonicalPublishedEntryHeader(context) {
  var region = context.heading.parentElement;
  if (!region || region === context.root || !region.contains(context.lead)) return null;
  var authors = [];
  var dates = [];
  Array.from(region.querySelectorAll("a[href], time[datetime], .published, .dt-published")).forEach(function(node) {
    if (!sourceRecordBefore(context.heading, node) || !sourceRecordBefore(node, context.lead) ||
        elementVisuallyHidden(node) || sourceOwnershipArticleChrome(node, context.root)) return;
    var value = normalizeText(node.textContent || "");
    if (!value) return;
    var range = document.createRange();
    range.selectNodeContents(region);
    range.setEndBefore(node);
    if (node.matches("a[rel~='author' i], .author, .p-author") || /\bby\s*$/i.test(normalizeText(range.toString()))) {
      if (authors.indexOf(value) === -1) authors.push(value);
    }
    var date = node.getAttribute("datetime") || value;
    var ownedDate = node.matches("time[datetime], .published, .dt-published") ||
      (node.matches("a[href]") && focalCanonicalUrl(node.href) === focalCanonicalUrl(location.href));
    if (ownedDate && /\b\d{4}\b/.test(date) && Number.isFinite(Date.parse(date))) {
      if (dates.indexOf(date) === -1) dates.push(date);
    }
  });
  return { byline: authors.length === 1 ? authors[0] : null, publishedTime: dates.length === 1 ? dates[0] : null };
}

function canonicalPublishedEntryContent(metadata) {
  var context = canonicalPublishedEntryContext(metadata);
  if (!context) return null;
  var header = canonicalPublishedEntryHeader(context);
  var visible = visibilityPrunedClone(context.root, document);
  var article = document.createElement("article");
  Array.from(visible.attributes).forEach(function(attribute) {
    article.setAttribute(attribute.name, attribute.value);
  });
  while (visible.firstChild) article.appendChild(visible.firstChild);
  var content = docsContentForNode(metadata, article, {
    title: context.title,
    hostAware: false,
    focusFragment: false,
    preserveAuthoredSections: true,
    preserveCleanedRoot: true,
    rewriteRoot: function(root) { materializeDeclaredArticleMedia(root, true); }
  });
  if (!content) return null;
  content.byline = header ? header.byline : null;
  content.publishedTime = header ? header.publishedTime : null;
  content.sourceOwnedArticlePublicationResolved = true;
  content.sourceOwnedDeclaredSemanticArticle = true;
  content.sourceOwnedGeneratedDocs = true;
  content.docsLike = false;
  content.excerpt = normalizeText(context.lead.textContent || "");
  return content;
}
