function liveblogParentHeadMetadataValue(selector) {
  if (!document.head) return null;
  var node = document.head.querySelector(selector);
  if (!node) return null;
  return normalizeText(node.getAttribute("content") || "") || null;
}

function liveblogParentHeaderRegion(context) {
  var selector = "header, [role~='banner' i], [class*='article-header' i], [id*='article-header' i], [class*='liveblog-header' i], [id*='liveblog-header' i]";
  var candidates = Array.from(context.parentRoot.querySelectorAll(selector)).filter(function(region) {
    if (!region.contains(context.heading) || elementSubtreeHidden(region) || sourceOwnershipInChrome(region)) return false;
    if (region.querySelector("article")) return false;
    return !context.records.some(function(record) {
      return region.contains(record.node) || record.node.contains(region);
    });
  });
  var innermost = candidates.filter(function(region) {
    return !candidates.some(function(other) { return region !== other && region.contains(other); });
  });
  return innermost.length === 1 ? innermost[0] : null;
}

function liveblogParentHeaderMetadataNodes(context, selector, region) {
  if (!region) return [];
  return Array.from(region.querySelectorAll(selector)).filter(function(node) {
    if (!region.contains(node) || elementVisuallyHidden(node) || sourceOwnershipInChrome(node)) return false;
    if (node.closest(VISIBLE_COMMENT_THREAD_SELECTOR)) return false;
    return !context.records.some(function(record) {
      return record.node.contains(node) || node.contains(record.node);
    });
  });
}

function liveblogParentHeaderPublishedTime(context) {
  var region = liveblogParentHeaderRegion(context);
  var values = liveblogParentHeaderMetadataNodes(
    context,
    "time[datetime], time, [itemprop~='datePublished' i], [class*='published' i], [class*='date' i]",
    region
  ).map(function(node) {
    return normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "");
  }).filter(function(value, index, all) { return value && all.indexOf(value) === index; });
  return values.length === 1 ? values[0] : null;
}

function liveblogParentHeaderByline(context) {
  var region = liveblogParentHeaderRegion(context);
  var bylines = liveblogParentHeaderMetadataNodes(context, "[class*='byline' i]", region);
  if (bylines.length === 1) return normalizeText(bylines[0].textContent || "") || null;
  var authors = liveblogParentHeaderMetadataNodes(
    context,
    "[rel~='author' i], [itemprop~='author' i], [class*='author' i]",
    region
  ).map(function(node) {
    return normalizeText(node.getAttribute("content") || node.textContent || "");
  }).filter(function(value, index, all) { return value && all.indexOf(value) === index; });
  return authors.length ? authors.join(", ") : null;
}
