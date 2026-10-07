function sourceOwnedGuideDocsContext(metadata) {
  var headings = Array.prototype.filter.call(document.querySelectorAll("main h1, article h1, [role='main'] h1"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
  });
  if (headings.length !== 1) return null;
  var heading = headings[0];
  var title = normalizeText(heading.textContent);
  var pageTitle = normalizeText(document.title || metadata.title || "");
  if (!title || pageTitle.indexOf(title) !== 0) return null;
  var suffix = normalizeText(pageTitle.slice(title.length));
  if (!/^(?:-|\||\u2013|\u2014)\s+.*\b(?:guides?|documentation|reference)\s*$/i.test(suffix)) return null;
  var root = heading.closest("main, article, [role='main']");
  if (!root || root.querySelectorAll("h1").length !== 1) return null;
  var prose = Array.prototype.some.call(root.querySelectorAll("p"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) && normalizeText(node.textContent);
  });
  var sections = Array.prototype.some.call(root.querySelectorAll("h2, h3"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) && normalizeText(node.textContent);
  });
  return prose && sections ? { root: root, title: title } : null;
}

function sourceOwnedGuideDocsContent(metadata, info) {
  if (!info || info.system !== "guide_docs") return null;
  var context = sourceOwnedGuideDocsContext(metadata);
  if (!context) return null;
  var navigationTitles = sourceOwnedGuideNavigationTitles(context.root);
  return docsContentForNode(metadata, context.root, {
    title: context.title,
    hostAware: false,
    rewriteRoot: function(root) {
      root.querySelectorAll("div, section").forEach(function(node) {
        var heading = node.firstElementChild;
        if (!heading || !heading.matches("h2, h3") || navigationTitles.indexOf(normalizeText(heading.textContent)) < 0) return;
        if (node.querySelector("p, pre, code, table, dl")) return;
        var remaining = node.cloneNode(true);
        remaining.querySelectorAll("h2, h3, a").forEach(function(child) { child.remove(); });
        if (!normalizeText(remaining.textContent)) node.remove();
      });
    }
  });
}

function sourceOwnedGuideNavigationTitles(root) {
  var headings = Array.prototype.slice.call(root.querySelectorAll("h2, h3"));
  return headings.filter(function(heading) {
    var title = normalizeText(heading.textContent);
    if (!/^(?:chapters|sections|contents|table of contents)$/i.test(title)) return false;
    if (headings.filter(function(other) { return normalizeText(other.textContent) === title; }).length !== 1) return false;
    var node = heading.parentElement;
    if (!node.matches("div, section") || node.firstElementChild !== heading || node.querySelector("p, pre, code, table, dl")) return false;
    var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
    if (!links.length || !links.every(function(link) { return samePageFragmentLink(link.getAttribute("href")); })) return false;
    var remaining = node.cloneNode(true);
    remaining.querySelectorAll("h2, h3, a").forEach(function(child) { child.remove(); });
    return !normalizeText(remaining.textContent);
  }).map(function(heading) { return normalizeText(heading.textContent); });
}
