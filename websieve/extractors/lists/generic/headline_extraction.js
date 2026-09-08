  function extractFallbackHeadlineItems(node) {
    if (!node || !node.querySelectorAll) return [];
    var seen = {};
    var ranked = [];
    var context = listPageContext();
    context.tableIndexPage = !!linkedTableIndexRoot();
    var selectors = [
      "h1 a[href]", "h2 a[href]", "h3 a[href]", "h4 a[href]", "article a[href]",
      "section a[href]", "[class*='headline' i] a[href]", "[class*='story' i] a[href]",
      "[class*='post' i] a[href]", "[class*='news' i] a[href]", "[class*='feed' i] a[href]",
      "[class*='teaser' i] a[href]", "[class*='result' i] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("tr, article, section, li, div") || link.parentElement;
      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;
      var candidate = listLinkCandidate(link, container, context, true);
      if (candidate) {
        addCardContext(candidate, candidate.card);
        pushUniqueListCandidate(ranked, seen, candidate);
      }
    });
    return ranked;
  }
