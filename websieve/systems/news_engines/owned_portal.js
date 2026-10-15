function declaredNewsPortalContext(metadata) {
  var current = focalCanonicalUrl(location.href);
  if (!/^https?:\/\//i.test(current)) return null;
  var canonical = document.querySelector("link[rel~='canonical' i]");
  if (!canonical || focalCanonicalUrl(canonical.getAttribute("href")) !== current) return null;
  var page = new URL(current);
  if (page.pathname !== "/" || page.search || focalSourceArticleMetadata()) return null;
  var entities = structuredDataNodes();
  var organizations = entities.filter(function(entity) {
    return nodeTypes(entity).some(function(type) { return /^NewsMediaOrganization$/i.test(type); }) &&
      focalCanonicalUrl(entity.url) === current;
  });
  var sites = entities.filter(function(entity) {
    return nodeTypes(entity).some(function(type) { return /^WebSite$/i.test(type); }) && focalCanonicalUrl(entity.url) === current;
  });
  if (organizations.length !== 1 || sites.length !== 1) return null;
  var name = normalizeText(entityText(organizations[0].name));
  if (!name || normalizeText(entityText(sites[0].name)) !== name) return null;
  var siteNames = Array.from(document.querySelectorAll("meta[property='og:site_name' i], meta[property='og:title' i]")).map(function(node) {
    return normalizeText(node.getAttribute("content") || "");
  });
  if (!siteNames.length || siteNames.some(function(value) { return value !== name; })) return null;
  var roots = document.querySelectorAll("main, [role='main']");
  if (roots.length !== 1) return null;
  var root = roots[0];
  if (elementSubtreeHidden(root) || sourceOwnershipArticleChrome(root, root)) return null;
  var records = Array.from(root.querySelectorAll("h2 a[href], h3 a[href]")).filter(function(link) {
    if (!normalizeText(link.textContent || "") || elementVisuallyHidden(link) || sourceOwnershipArticleChrome(link, root)) return false;
    var destination = declaredArticleHttpUrl(link.getAttribute("href"));
    if (!destination || focalCanonicalUrl(destination) === current) return false;
    return new URL(destination).origin === page.origin && !link.closest("nav, aside, footer, form, [role='navigation'], [role='complementary']");
  });
  var destinations = new Set(records.map(function(link) { return focalCanonicalUrl(link.getAttribute("href")); }));
  if (destinations.size < 2) return null;
  var description = normalizeText(entityText(organizations[0].description)) || normalizeText(entityText(sites[0].description));
  return { root: root, title: name, records: records, description: description };
}

function declaredNewsPortalContent(metadata) {
  var context = declaredNewsPortalContext(metadata);
  if (!context) return null;
  var content = docsContentForNode(metadata, context.root, {
    title: context.title, hostAware: false, focusFragment: false,
    pruneSourceVisibility: true, preserveAuthoredSections: true, preserveCleanedRoot: true,
    preserveMaterializedCollection: true,
    prepareRoot: function(root) { root.setAttribute("data-fetchutil-page-overview", "true"); },
    rewriteRoot: function(root) { materializeDeclaredArticleMedia(root, true); }
  });
  if (!content) return null;
  content.title = context.title;
  content.excerpt = context.description || content.excerpt;
  content.byline = null;
  content.publishedTime = null;
  content.sourceOwnedArticlePublicationResolved = true;
  content.readerMode = false;
  content.contentType = "list";
  content.docsLike = false;
  content.sourceOwnedGeneratedDocs = true;
  content.sourceOwnedDeclaredNewsPortal = true;
  return content;
}
