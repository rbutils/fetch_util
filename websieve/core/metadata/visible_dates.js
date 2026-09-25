function visiblePublishedTimeRoots() {
  var path = location.pathname || "/";
  if (path !== "/" && !/^\/index\.(?:html?|php|aspx?)$/i.test(path)) return visibleMetadataRoots();

  var roots = [];
  document.querySelectorAll("[itemprop='articleBody'], article[role='main']").forEach(function(node) {
    var root = node.closest("article, [role='main'], main") || node;
    if (roots.indexOf(root) === -1 && textLength(root) >= 80) roots.push(root);
  });
  return roots;
}

function visiblePublishedTimeField(node) {
  var contentSelector = "article, main, [role='main'], [itemprop='articleBody'], .entry-content, .post-content";
  if (node.matches(contentSelector)) return false;
  return !node.querySelector(contentSelector + ", h1, h2, h3, h4, h5, h6, figure, blockquote, pre, table");
}

function visiblePublishedTime() {
  var roots = visiblePublishedTimeRoots();
  return firstScopedText(roots, ["time[datetime]"], "datetime") ||
    firstScopedText(roots, [
      "[itemprop='datePublished']",
      "[itemprop='dateModified']",
      "[class*='pubdate' i]",
      "[class*='published-date' i]",
      "[class*='published_at' i]",
      "[class*='published-at' i]",
      "[class*='publication-date' i]",
      "[class*='fecha' i]",
      "[class*='data-publicacao' i]",
      "[class*='data-publicação' i]",
      "[class*='datum' i]",
      "[class*='tarih' i]",
      "[class*='date' i]",
      "[class*='time' i]",
      "[class*='publish' i]",
      "[class*='posted' i]",
      "[data-testid*='date' i]",
      "time"
    ], null, null, visiblePublishedTimeField);
}
