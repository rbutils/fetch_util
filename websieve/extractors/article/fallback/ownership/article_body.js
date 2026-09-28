function sourceOwnershipPageUrl(value) {
  if (!value) return "";
  try {
    var parsed = new URL(value, location.href);
    if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return "";
    parsed.hash = "";
    return parsed.origin + parsed.pathname.replace(/\/$/, "") + parsed.search;
  } catch (_error) {
    return "";
  }
}

function sourceOwnershipCommonAncestor(left, right) {
  for (var node = left; node; node = node.parentElement) {
    if (node.contains(right)) return node;
  }
  return null;
}

function sourceOwnershipInChrome(node) {
  return !node || node.closest("nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i], [class*='sidebar' i], [id*='sidebar' i], [class*='sidemenu' i], [id*='sidemenu' i], [class*='side-menu' i], [id*='side-menu' i], [class*='recommend' i], [id*='recommend' i], [class*='related-posts' i], [id*='related-posts' i]");
}

function sourceArticleBodyCandidates() {
  return Array.from(document.querySelectorAll([
    "article", "[itemprop~='articleBody' i]", "[data-article-body]",
    "[class*='article-body' i]", "[class*='article-content' i]", "[class*='story-content' i]",
    "[class*='post-content' i]", "[class*='entry-content' i]", "[class*='detail' i][class*='content' i]",
    "[class*='description-area' i]"
  ].join(", ")));
}

function sourceArticleBodyHasForeignLinkedArticle(ownerRoot, bodyNode, heading, currentUrl) {
  if (!ownerRoot || !bodyNode || !heading) return false;
  var articles = Array.from(ownerRoot.querySelectorAll("article"));
  if (ownerRoot.matches("article")) articles.unshift(ownerRoot);
  return articles.some(function(candidate) {
    if (candidate.contains(heading) && candidate.contains(bodyNode)) return false;
    if (commentRecordMarker(candidate) || candidate.closest(VISIBLE_COMMENT_THREAD_SELECTOR)) return false;
    if (sourceOwnershipInChrome(candidate) || candidate.closest("figure, [class*='read-more' i], [class*='readmore' i], [class*='embedRelatedStory' i]")) return false;
    return Array.from(candidate.querySelectorAll("h2 a[href], h3 a[href], h4 a[href]")).some(function(link) {
      if (link.closest("article") !== candidate) return false;
      if (elementVisuallyHidden(link) || sourceOwnershipInChrome(link) || normalizeText(link.textContent || "").length < 8) return false;
      var linkedPage = sourceOwnershipPageUrl(link.getAttribute("href"));
      return !!linkedPage && linkedPage !== currentUrl;
    });
  });
}

function resolveCanonicalArticleBodyOwnership() {
  var metadata = focalSourceArticleMetadata();
  var currentUrl = sourceOwnershipPageUrl(location.href);
  var canonical = document.querySelector("link[rel~='canonical' i]");
  if (!metadata || !currentUrl || sourceOwnershipPageUrl(canonical && canonical.getAttribute("href")) !== currentUrl) return null;

  var headings = Array.from(document.querySelectorAll("h1, [itemprop~='headline' i]")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && metadata.headlines.indexOf(normalizeText(heading.textContent || "")) !== -1;
  });
  if (headings.length !== 1) return null;
  var heading = headings[0];
  var candidates = sourceArticleBodyCandidates().filter(function(node) {
    if (sourceOwnershipInChrome(node) || elementSubtreeHidden(node)) return false;
    var shell = sourceOwnershipCommonAncestor(heading, node);
    if (!shell || shell === document.body || shell === document.documentElement || sourceOwnershipInChrome(shell)) return false;
    var shellHint = String(shell.className || "") + " " + String(shell.id || "");
    if (!shell.matches("article, main, [role~='main' i]") && !/(?:article|story|post|entry|detail|content|main)/i.test(shellHint)) return false;
    if (sourceArticleBodyHasForeignLinkedArticle(shell, node, heading, currentUrl)) return false;
    var body = focalOwnershipVisibleBody(node);
    if (!body || body.text.length < 120) return false;
    body.sourceNode = node;
    return true;
  });
  var innermost = candidates.filter(function(node) {
    return !candidates.some(function(other) { return node !== other && node.contains(other); });
  });
  if (innermost.length !== 1) return null;

  var node = innermost[0];
  var body = focalOwnershipVisibleBody(node);
  var ownerRoot = sourceOwnershipCommonAncestor(heading, node);
  if (!body || !ownerRoot) return null;
  body.sourceNode = node;
  var ownership = {
    node: node,
    ownerRoot: ownerRoot,
    heading: heading,
    title: normalizeText(heading.textContent || ""),
    body: body,
    proof: "canonical-article-metadata"
  };
  var headerContext = sourceOwnedArticleHeaderContext(ownership);
  if (headerContext === false) return null;
  ownership.headerContext = headerContext;
  if (sourceOwnedArticleHasUncoveredMaterial(ownership)) return null;
  return ownership;
}
