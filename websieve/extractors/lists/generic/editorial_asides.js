  function listEditorialAsideHints(node, hints) {
    var weakHints = /sidebar|side-bar|rail|complementary|secondary|trending|popular|most-read|mostread|recommended|related|videos?|photos?|galler(?:y|ies)|web.?stor/g;
    if (!weakHints.test(hints) || !node || !node.closest || !node.closest("[data-fetchutil-editorial-aside]")) return hints;
    return hints.replace(weakHints, "");
  }

  function editorialAsideLinkUrl(link) {
    if (!link || !link.matches("a[href]")) return "";
    if (link.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return "";
    var heading = link.querySelector("h1, h2, h3, h4");
    var text = normalizeText((heading || link).textContent || link.getAttribute("aria-label") || "");
    var href = link.getAttribute("href");
    var url = materializedHttpUrl(href);
    if (!url || url.split("#")[0] === location.href.split("#")[0]) return "";
    if (text.length < minimumListTitleLength(text) || genericListControlText(text) || looksLikeFooterLink(text, href)) return "";
    return url;
  }

  function editorialAsideHeadingLinks(root) {
    var links = new Set();
    root.querySelectorAll("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4").forEach(function(node) {
      var link = node.closest("a[href]");
      if (editorialAsideLinkUrl(link)) links.add(link);
    });
    return Array.from(links);
  }

  function fallbackWithEditorialAsideItems(items, fallbackItems) {
    if (items.length <= fallbackItems.length) return fallbackItems;
    var candidates = new Set(items.filter(function(item) {
      return item.sourceNode && item.card === item.sourceNode &&
        item.sourceNode.closest("[data-fetchutil-editorial-aside]") && editorialAsideLinkUrl(item.sourceNode);
    }));
    if (!candidates.size) return fallbackItems;

    var originals = new Map();
    items.forEach(function(item) {
      if (!item.sourceNode) return;
      if (!originals.has(item.sourceNode)) originals.set(item.sourceNode, []);
      originals.get(item.sourceNode).push(item);
    });
    var replacements = new Map();
    var complete = fallbackItems.every(function(fallback) {
      var key = sameRootListRecordKey(fallback);
      var original = (originals.get(fallback.sourceNode) || []).find(function(item) {
        return sameRootListRecordKey(item) === key;
      });
      if (!original || replacements.has(original)) return false;
      replacements.set(original, fallback);
      return true;
    });
    if (!complete) return fallbackItems;
    var additions = new Set(Array.from(candidates).filter(function(item) { return !replacements.has(item); }));
    if (!additions.size) return fallbackItems;
    return items.filter(function(item) {
      return replacements.has(item) || additions.has(item);
    }).map(function(item) { return replacements.get(item) || item; });
  }

  function preserveHomepageListAsides(root) {
    if (!homepageRootPath()) return root;
    var asides = root.querySelectorAll("aside");
    if (!asides.length) return root;
    var mainUrls = new Set(editorialAsideHeadingLinks(root).filter(function(link) {
      return !link.closest("aside");
    }).map(editorialAsideLinkUrl));
    if (mainUrls.size < 4) return root;

    asides.forEach(function(aside) {
      if (cookieChromeNode(aside)) return;
      stripPromoAdModules(aside);
      var headingLinks = editorialAsideHeadingLinks(aside);
      var urls = new Set(Array.prototype.map.call(aside.querySelectorAll("a[href]"), editorialAsideLinkUrl).filter(Boolean));
      if (!headingLinks.length || urls.size < 3) return;
      aside.setAttribute("data-fetchutil-editorial-aside", "true");
    });
    return root;
  }
