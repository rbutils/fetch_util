function canonicalArticleBodyContent(metadata, ownership, article, publicPreview) {
  article = article || sourceOwnedArticleMarkup(ownership);
  var text = normalizeText(article.textContent || "");
  var headerMetadata = sourceOwnedFallbackHeaderMetadata(ownership.body.sourceNode, ownership.title, metadata || {});
  var attribution = headerMetadata || metadata || {};
  var publicationFields = sourceOwnedArticlePublicationFields(metadata, ownership, article);
  var titleIdentityUnproven = ownership.titleIdentityProven === false;
  var completeArticleLead = sourceOwnedCompleteArticleLead(ownership);
  var content = {
    title: titleIdentityUnproven ? (metadata && metadata.title) || ownership.title : ownership.title,
    byline: attribution.byline || null,
    excerpt: publicPreview ? publicPreview.text :
      (fallbackSourceOwnedSummary(ownership.body.sourceNode, text, ownership) ||
        sourceOwnedArticleHeaderLead(ownership) || completeArticleLead ||
        fallbackArticleExcerpt(ownership.body.sourceNode, text, metadata, true, ownership)),
    siteName: (metadata && metadata.siteName) || location.hostname,
    publishedTime: publicationFields.sourceOwnedArticlePublicationResolved ? publicationFields.publishedTime : attribution.publishedTime || null,
    html: article.innerHTML,
    textContent: text,
    readerMode: false,
    contentType: "article",
    sourceOwnedFocalArticle: true,
    sourceOwnedTitleIdentityUnproven: titleIdentityUnproven,
    sourceOwnedHeadingTitle: ownership.title,
    focalPermalinkContent: true
  };
  if (publicPreview) content.focalPublicPreview = true;
  Object.defineProperty(content, "sourceOwnedArticleBody", { value: ownership.body.sourceNode });
  content.sourceOwnedArticlePublicationResolved = publicationFields.sourceOwnedArticlePublicationResolved;
  return content;
}

function sourceOwnedReaderFallback(primary, fallback) {
  if (!primary || !primary.readerMode || !fallback || !fallback.sourceOwnedFocalArticle) return null;
  var sourceBody = fallback.sourceOwnedArticleBody;
  if (!sourceBody || !sourceBody.querySelector("h1")) return null;
  primary.html = fallback.html;
  primary.textContent = fallback.textContent;
  var excerpt = normalizeText(primary.excerpt || "");
  if (excerpt && normalizeText(fallback.textContent || "").indexOf(excerpt) === -1) primary.excerpt = fallback.excerpt;
  return primary;
}
