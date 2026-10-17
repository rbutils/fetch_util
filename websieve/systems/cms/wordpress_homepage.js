function wordpressHomepageNavigationChrome(node, root, current) {
  for (var parent = node.parentElement; parent && parent !== document.body && !parent.contains(root); parent = parent.parentElement) {
    if (parent.querySelector("h1, h2, h3, h4, h5, h6, pre, table, blockquote, article") ||
        Array.from(parent.querySelectorAll("p")).some(readerSectionParagraphNarrative)) continue;
    var homeLogo = Array.from(parent.querySelectorAll("a[href]")).some(function(link) {
      return link.querySelector("img") && sourceOwnershipPageUrl(link.getAttribute("href")) === current;
    });
    if (!homeLogo) continue;
    var menu = Array.from(parent.querySelectorAll("button[aria-controls]")).some(function(button) {
      var id = normalizeText(button.getAttribute("aria-controls"));
      var targets = Array.from(document.querySelectorAll("[id]")).filter(function(target) { return target.id === id; });
      if (!id || targets.length !== 1 || !parent.contains(targets[0])) return false;
      var links = Array.from(targets[0].querySelectorAll("a[href]")).filter(function(link) {
        return normalizeText(link.textContent) && materializedHttpUrl(link.getAttribute("href"));
      });
      return links.length >= 2;
    });
    if (menu) return true;
  }
  return false;
}

function wordpressHomepageContext(metadata) {
  if (!document.body || !document.body.matches(".home.page") || !homepageRootPath() ||
      !wordpressDomDetected()) return null;
  var current = sourceOwnershipPageUrl(location.href);
  var canonicals = document.querySelectorAll("link[rel~='canonical' i]");
  if (canonicals.length !== 1 || sourceOwnershipPageUrl(canonicals[0].getAttribute("href")) !== current ||
      structuredDataNodes().some(structuredDataFocalRecord)) return null;
  var title = normalizeText(document.title);
  if (!title || (metadata && metadata.title && normalizeText(metadata.title) !== title)) return null;
  if (Array.from(document.querySelectorAll("meta[property='og:type' i]")).some(function(node) {
    return normalizeText(node.getAttribute("content")).toLowerCase() !== "website";
  }) || Array.from(document.querySelectorAll("meta[property='og:title' i]")).some(function(node) {
    return normalizeText(node.getAttribute("content")) !== title;
  }) || Array.from(document.querySelectorAll("meta[property='og:url' i]")).some(function(node) {
    return sourceOwnershipPageUrl(node.getAttribute("content")) !== current;
  })) return null;

  return withSourceVisibilityRead(function() {
    var roots = Array.from(document.querySelectorAll(".entry-content, .wp-block-post-content")).filter(function(root) {
      return !root.parentElement.closest(".entry-content, .wp-block-post-content") &&
        !root.closest("nav, aside, header, footer, form, dialog") && !elementSubtreeHidden(root);
    });
    if (roots.length !== 1) return null;
    var root = roots[0];
    var article = root.closest("article");
    if (article && !article.matches(".page, .type-page")) return null;
    if (root.querySelector("form, input, select, textarea, [itemprop~='articleBody' i]")) return null;
    var attribution = Array.from(root.querySelectorAll(
      "[rel~='author' i], .byline, .post-author, [itemprop~='author' i], time[pubdate], [itemprop~='datePublished' i]"
    )).some(function(node) {
      return (!node.closest("article") || node.closest("article") === article) && !elementSubtreeHidden(node);
    });
    if (attribution) return null;
    var headings = Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(node) {
      return normalizeText(node.textContent) && !homepageLandingChrome(node) && !elementSubtreeHidden(node);
    });
    if (headings.length < 2 || !headings.some(function(node) { return node.tagName === "H1"; }) ||
        !Array.from(root.querySelectorAll("p")).some(function(node) {
          return !elementSubtreeHidden(node) && readerSectionParagraphNarrative(node);
        })) return null;
    var outside = Array.from(document.querySelectorAll("p, h1, h2, h3, h4, h5, h6, pre, table, blockquote"));
    if (outside.some(function(node) {
      return !root.contains(node) && normalizeText(node.textContent) &&
        !node.closest("header, footer, nav, aside, form, button, dialog, [role='navigation'], " +
          "[role='complementary'], [role='contentinfo'], [role='banner'], [role='dialog']") &&
        !wordpressHomepageNavigationChrome(node, root, current) && !elementSubtreeHidden(node);
    })) return null;
    return { root: root, title: title };
  });
}

function wordpressHomepageContent(metadata) {
  var context = wordpressHomepageContext(metadata);
  if (!context) return null;
  var clone = visibilityPrunedClone(context.root, document);
  removeAll(clone, "script, style, noscript, template");
  return profileHtmlContent(metadata, clone, {
    cloneRoot: false,
    cleanupRoot: false,
    cleanupMarkdown: false,
    preserveCleanedRoot: true,
    convertRoot: ownedHomepageMarkdown,
    title: context.title,
    excerpt: metadata.description || metadata.excerpt || null,
    byline: null,
    publishedTime: sourceOwnedPagePublicationTime(metadata),
    contentType: "article",
    hostAware: false,
    extra: { sourceOwnedHomepageCollection: true, sourceOwnedStaticHomepage: true, wordpressBlockPage: true }
  });
}
