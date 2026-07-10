function metadataValue(name, attr) {
  var selector = 'meta[' + attr + "=\"" + name + "\"]";
  var node = document.querySelector(selector);
  return node ? node.getAttribute("content") : null;
}

function collectMetadata() {
  var canonical = document.querySelector('link[rel="canonical"]');
  var schemaArticle = structuredDataNode(["NewsArticle", "Article", "BlogPosting"]);
  var schemaEvent = typeof eventStructuredDataNode === "function" ? eventStructuredDataNode() : null;
  var schemaAuthor = entityName(schemaArticle && schemaArticle.author);
  var schemaPublishedTime = entityText(schemaArticle && schemaArticle.datePublished);
  var schemaModifiedTime = entityText(schemaArticle && schemaArticle.dateModified);
  var schemaEventTime = schemaEvent && typeof eventDateText === "function" ? eventDateText(schemaEvent.startDate, schemaEvent.endDate) : null;

  return {
    title: metadataValue("og:title", "property") || document.title || firstText(["main h1", "article h1", "h1"]),
    byline: metadataValue("author", "name") || metadataValue("article:author", "property") || metadataValue("parsely-author", "name") || schemaAuthor || visibleByline(),
    excerpt: metadataValue("description", "name") || metadataValue("og:description", "property"),
    siteName: metadataValue("og:site_name", "property") || location.hostname,
    publishedTime: schemaEventTime || metadataValue("article:published_time", "property") || metadataValue("publish-date", "name") || metadataValue("datePublished", "itemprop") || metadataValue("date", "name") || metadataValue("dc.date", "name") || metadataValue("DC.date", "name") || metadataValue("parsely-pub-date", "name") || schemaPublishedTime || schemaModifiedTime || visiblePublishedTime(),
    canonicalUrl: absoluteUrl(canonical && canonical.getAttribute("href")) || location.href,
    language: documentLanguage(),
    image: metadataValue("og:image", "property") || null,
    video: metadataValue("og:video", "property") || metadataValue("og:video:url", "property") || null
  };
}
