function metadataValue(name, attr) {
  var selector = 'meta[' + attr + "=\"" + name + "\"]";
  var node = document.querySelector(selector);
  return node ? node.getAttribute("content") : null;
}

function materializedMetadataValue(name, attr) {
  var selector = 'meta[' + attr + "=\"" + name + "\"]";
  var nodes = document.querySelectorAll(selector);
  for (var index = 0; index < nodes.length; index += 1) {
    var url = materializedHttpUrl(nodes[index].getAttribute("content"));
    if (url) return url;
  }
  return null;
}

function declaredBylineValue(value) {
  var byline = sanitizeByline(value);
  if (!byline || /^(?:\/|\.{1,2}\/)/.test(byline)) return null;
  return byline;
}

function collectMetadata() {
  return withSourceVisibilityRead(function() {
    return computeMetadata();
  });
}

function computeMetadata() {
  var canonicalUrl = materializedCanonicalUrl();
  var schemaArticle = structuredDataNode(["NewsArticle", "Article", "BlogPosting"]);
  var schemaEvent = typeof eventStructuredDataNode === "function" ? eventStructuredDataNode() : null;
  var declaredDescription = metadataValue("description", "name");
  if (!normalizeText(declaredDescription)) declaredDescription = metadataValue("og:description", "property");
  if (!normalizeText(declaredDescription)) declaredDescription = null;
  var schemaAuthor = entityName(schemaArticle && schemaArticle.author);
  var declaredByline = [
    metadataValue("article:author", "name"),
    metadataValue("article:author", "property"),
    metadataValue("parsely-author", "name"),
    schemaAuthor,
    metadataValue("author", "name")
  ].map(declaredBylineValue).find(Boolean) || null;
  var byline = declaredByline || sanitizeByline(visibleByline()) || null;
  var schemaPublishedTime = entityText(schemaArticle && schemaArticle.datePublished);
  var schemaPagePublishedTime = sourceOwnedPagePublicationTime({
    title: metadataValue("og:title", "property") || document.title,
    canonicalUrl: canonicalUrl
  });
  var schemaEventTime = schemaEvent && typeof eventDateText === "function" ? eventDateText(schemaEvent.startDate, schemaEvent.endDate) : null;
  var visibleHeadings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  var sourceOwnedQuestionAnswerDate = visibleHeadings.length ?
    sourceOwnedLeadingQuestionAnswerPublicationTime(visibleHeadings[0].textContent || "", canonicalUrl) : "";

  var metadata = {
    title: metadataValue("og:title", "property") || document.title || firstText(["main h1", "article h1", "h1"]),
    byline: byline,
    declaredByline: declaredByline,
    excerpt: metadataValue("description", "name") || metadataValue("og:description", "property"),
    declaredDescription: declaredDescription,
    siteName: metadataValue("og:site_name", "property") || location.hostname,
    publishedTime: schemaEventTime || metadataValue("article:published_time", "property") || metadataValue("publish-date", "name") || metadataValue("datePublished", "itemprop") || metadataValue("date", "name") || metadataValue("dc.date", "name") || metadataValue("DC.date", "name") || metadataValue("parsely-pub-date", "name") || schemaPublishedTime || metadataValue("govuk:first-published-at", "name") || schemaPagePublishedTime || visiblePublishedTime(),
    canonicalUrl: canonicalUrl || materializedHttpUrl(location.href),
    language: documentLanguage(),
    image: materializedMetadataValue("og:image", "property"),
    video: materializedMetadataValue("og:video", "property") || materializedMetadataValue("og:video:url", "property")
  };

  var sourceRecord = structuredSourceRecordOwnership(metadata);
  if (sourceRecord) {
    metadata.byline = sourceRecord.byline;
    metadata.publishedTime = sourceRecord.publishedTime;
    metadata.recordType = sourceRecord.recordType;
  }

  if (!sourceRecord) {
    var contentsComponent = sourceOwnedContentsComponentOwnership(metadata);
    if (contentsComponent) {
      metadata.contentsComponent = contentsComponent;
      metadata.byline = contentsComponent.byline;
      metadata.publishedTime = contentsComponent.publishedTime;
      metadata.excerpt = contentsComponent.lead;
    }
  }

  Object.defineProperty(metadata, "sourceOwnedQuestionAnswerPublicationTime", {
    value: metadata.publishedTime === sourceOwnedQuestionAnswerDate ? sourceOwnedQuestionAnswerDate : null
  });

  return metadata;
}
