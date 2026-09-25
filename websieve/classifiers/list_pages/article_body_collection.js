  function independentArticleBodyCollection() {
    if (!document.body || !likelyListPath()) return false;
    var records = Array.prototype.filter.call(document.querySelectorAll("main article, [role~='main' i] article"), function(article) {
      if (elementSubtreeHidden(article) || article.parentElement.closest("article")) return false;
      var heading = Array.prototype.find.call(article.querySelectorAll("h2, h3, [itemprop~='headline' i]"), function(node) {
        return !elementSubtreeHidden(node);
      });
      if (!heading) return false;
      var body = article.querySelector("[itemprop~='articleBody' i]");
      if (!body || body.closest("article") !== article) return false;
      var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(paragraph) {
        return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 24;
      });
      return paragraphs.length >= 2;
    });
    var titles = records.map(function(article) {
      var heading = Array.prototype.find.call(article.querySelectorAll("h2, h3, [itemprop~='headline' i]"), function(node) {
        return !elementSubtreeHidden(node);
      });
      return normalizeText(heading && heading.textContent || "");
    });
    return titles.length >= 3 && new Set(titles).size === titles.length;
  }

  function independentLinkedArticleCollection(focal) {
    if (!queryOrCategoryPage() && !(likelyListPath() && !articleLikePath())) return false;
    var main = focal && focal.closest("main, [role~='main' i]");
    if (!main) return false;
    var groups = new Map();
    main.querySelectorAll("article").forEach(function(record) {
      if (record === focal || record.contains(focal) || focal.contains(record) || elementVisuallyHidden(record)) return;
      if (record.closest("aside, nav, footer, [role~='complementary' i], [role~='navigation' i], [class*='comment' i], [id*='comment' i]") || relatedMetadataOwner(record)) return;
      for (var scope = record.parentElement; scope && scope !== main; scope = scope.parentElement) {
        var relatedHeading = Array.from(scope.children).some(function(child) {
          return child.matches("h2, h3, h4") && RELATED_SECTION_HEADING_PATTERN.test(normalizeText(child.textContent || ""));
        });
        if (relatedHeading) return;
      }
      var heading = Array.from(record.querySelectorAll("h2, h3, h4")).find(function(node) {
        return node.closest("article") === record && !elementVisuallyHidden(node) && normalizeText(node.textContent || "");
      });
      var link = heading && (heading.closest("a[href]") || heading.querySelector("a[href]"));
      if (!link || link.closest("article") !== record || elementVisuallyHidden(link)) return;
      var href = materializedHttpUrl(link.getAttribute("href"));
      if (!href || focalCanonicalUrl(href) === focalCanonicalUrl(location.href)) return;
      var owner = record.parentElement;
      if (!groups.has(owner)) groups.set(owner, new Set());
      groups.get(owner).add(focalCanonicalUrl(href));
    });
    return Array.from(groups.values()).some(function(destinations) { return destinations.size >= 3; });
  }
