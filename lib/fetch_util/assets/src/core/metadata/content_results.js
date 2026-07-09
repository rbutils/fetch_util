function articleContentFromParts(parts) {
  var sections = [];
  var meta = [];

  if (parts.title) sections.push("# " + parts.title);
  if (parts.byline) meta.push("- Author: " + parts.byline);
  if (parts.publishedTime) meta.push("- Published: " + parts.publishedTime);
  asArray(parts.details).forEach(function(detail) {
    if (detail) meta.push("- " + detail);
  });
  if (meta.length) sections.push(meta.join("\n"));
  if (parts.description) sections.push(parts.description);
  if (parts.highlights && parts.highlights.length) {
    sections.push(parts.highlights.map(function(item) {
      return "- " + item;
    }).join("\n"));
  }

  var markdown = sections.filter(Boolean).join("\n\n").trim();
  return {
    title: parts.title,
    byline: parts.byline || null,
    excerpt: parts.description || null,
    siteName: parts.siteName || location.hostname,
    publishedTime: parts.publishedTime || null,
    html: "",
    markdown: markdown,
    textContent: normalizeText(markdown),
    docsLike: !!parts.docsLike,
    hostAware: !!parts.hostAware,
    readerMode: false,
    contentType: parts.contentType || "article",
    socialKind: parts.socialKind || null,
    platform: parts.platform || null,
    handle: parts.handle || null,
    replyCount: parts.replyCount === undefined ? null : parts.replyCount,
    community: parts.community || null,
    score: parts.score === undefined ? null : parts.score
  };
}

function queryParam(name) {
  return new URLSearchParams(location.search).get(name);
}

function searchQuery() {
  return queryParam("q") || queryParam("p") || queryParam("query") || queryParam("text") || "";
}

function isSearchEnginePage() {
  return /(^|\.)(google\.|bing\.com$|duckduckgo\.com$|search\.brave\.com$|ecosia\.org$)/.test(location.hostname);
}

function listContentResult(options) {
  var markdown = options.markdown != null ? options.markdown : listMarkdown(options.items || []);
  return {
    title: options.title,
    byline: null,
    excerpt: options.excerpt,
    siteName: options.siteName || location.hostname,
    publishedTime: null,
    html: options.html || "",
    textContent: options.textContent != null ? options.textContent : markdown,
    markdown: markdown,
    readerMode: false,
    contentType: "list"
  };
}

function listItemsContentResult(metadata, options) {
  options = options || {};
  var items = options.items;
  var markdown = options.markdown != null ? options.markdown : listMarkdown(items || []);
  var result = {
    title: options.title || (metadata && metadata.title) || document.title,
    byline: null,
    excerpt: options.excerpt != null ? options.excerpt : (items[0] ? items[0].text : metadata && metadata.excerpt),
    siteName: options.siteName || (metadata && metadata.siteName) || location.hostname,
    publishedTime: options.publishedTime || (metadata && metadata.publishedTime),
    html: options.html || "",
    textContent: options.textContent != null ? options.textContent : markdown,
    markdown: markdown,
    readerMode: false,
    contentType: options.contentType || "list"
  };
  if (items) result.itemCount = items.length;
  if (options.hostAware) result.hostAware = true;
  if (options.statusPage) result.statusPage = true;
  return result;
}
