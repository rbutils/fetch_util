  function genericHomepageLeadRoot(metadata, options) {
    options = options || {};
    if (!document.body || !homepageRootPath()) return null;
    if (homepageHasEditorialSections(document)) return null;
    if (typeof articleRouteFocalContent === "function" && articleRouteFocalContent()) return null;
    if (document.querySelector("article h1, article [itemprop='articleBody'], [type='application/ld+json']")) {
      var bodyText = normalizeText(document.body.textContent || "");
      if (document.querySelector("article h1") && bodyText.length < 30000) return null;
    }

    var roots = [];
    ["main", "[role='main']", "#main", ".main", "body"].forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(root) {
        if (roots.indexOf(root) === -1) roots.push(root);
      });
    });

    var best = null;
    var minItems = options.minItems || 5;
    var intentText = normalizeText([
      (metadata && metadata.title) || "",
      (metadata && metadata.siteName) || "",
      document.title || "",
      document.body.textContent || ""
    ].join(" ")).toLowerCase().slice(0, 6000);
    var portalIntent = /\b(find|search|book|compare|deals?|offers?|destinations?|routes?|tickets?|timetables?|trains?|travel|hotels?|homes?|properties|real estate|for sale|for rent|marketplaces?|listings?|latest|top stories|headlines|breaking news)\b/i.test(intentText);

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var headings = [];
      var hero = normalizeText(((root.querySelector("h1") || {}).textContent) || "");

      root.querySelectorAll("h2, h3").forEach(function(heading) {
        var text = normalizeText(heading.textContent || "");
        if (heading.closest && heading.closest("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return;
        if (listNoiseNode(heading.parentElement)) return;
        if (text.length >= 6 && text.length <= 90 && !rejectedHomepageLeadText(text, "")) headings.push(text);
      });

      root.querySelectorAll("a[href]").forEach(function(link) {
        if (link.closest("header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']")) return;

        var href = link.getAttribute("href") || "";
        var url = absoluteUrl(href);
        var title = normalizeText(((link.querySelector("h1, h2, h3, h4") || {}).textContent) || link.textContent || link.getAttribute("aria-label") || "");
        var canonicalUrl = url && homepageCanonicalUrl(url);
        if (!url || seen[canonicalUrl] || rejectedHomepageLeadText(title, href)) return;
        if (title.length < 12 && !/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(title)) return;

        var container = link.closest("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']") || link.parentElement;
        var cardRoot = homepageCardRoot(link);
        if (cardRoot && cardRoot !== container && cardRoot.contains(link)) container = cardRoot;
        if (cardRoot && cardRoot.querySelector("article h1 a[href], article h2 a[href], article h3 a[href], article h4 a[href]") && !cardRoot.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href]").contains(link)) return;
        var detail = searchItemDetail(container, title);
        if (detail.length > 180) detail = "";

        seen[canonicalUrl] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      var text = normalizeText(root.textContent || "");
      var links = root.querySelectorAll("a[href]").length;
      var cards = root.querySelectorAll("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']").length;
      var heroScore = hero && hero.length >= 8 && hero.length <= 120 ? 180 : 0;
      var sectionScore = Math.min(headings.length, 6) * 60;
      var score = items.length * 180 + heroScore + sectionScore + Math.min(cards, 18) * 12 + Math.min(links, 80);

      if (items.length < minItems && !(items.length >= 3 && heroScore && headings.length >= 2)) return;
      if (!portalIntent && !(items.length >= 6 && cards >= 6 && headings.length >= 3)) return;
      if (links < items.length || text.length < 120) return;
      if (!best || score > best.score) {
        best = { root: root, items: items, hero: hero, headings: headings, score: score };
      }
    });

    if (!best) return null;
    if (best.items.length < minItems && (!best.hero || best.headings.length < 2)) return null;
    return best;
  }

  function genericPortalHomepageContent(metadata) {
    if (homepageRootPath()) {
      var sectioned = listContent(metadata, { portalRoot: true });
      if (sectioned.portalRootEvidence) return sectioned;
    }

    var leadRoot = genericHomepageLeadRoot(metadata, { minItems: 4 });
    if (!leadRoot) return null;

    var title = leadRoot.hero || (metadata && metadata.title) || document.title || location.hostname;
    var markdownParts = [];
    if (leadRoot.hero) markdownParts.push("# " + leadRoot.hero);
    if (metadata && metadata.excerpt) markdownParts.push(metadata.excerpt);
    if (leadRoot.headings.length >= 2) {
      markdownParts.push(leadRoot.headings.map(function(text) { return "- " + text; }).join("\n"));
    }
    markdownParts.push(listMarkdown(leadRoot.items));

    var markdown = markdownParts.filter(Boolean).join("\n\n").trim();
    if (normalizeText(markdown).length < 180) return null;

    return listContentResult({
      title: title,
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || location.hostname,
      markdown: markdown,
      textContent: normalizeText(markdown)
    });
  }
