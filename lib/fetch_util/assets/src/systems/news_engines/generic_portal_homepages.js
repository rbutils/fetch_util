  function homepageNeedsSectionCollector(root) {
    var seen = {};
    var cardSelector = "article, li, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']";
    var needed = false;
    root.querySelectorAll("section, [role='region']").forEach(function(region) {
      var parent = region.parentElement;
      while (parent) {
        if (parent.matches && parent.matches("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) needed = true;
        parent = parent.parentElement;
      }
      if (listNoiseNode(region) || listNoiseNode(region.parentElement)) needed = true;
      var cards = Array.prototype.slice.call(region.querySelectorAll(cardSelector));
      if (cards.some(function(card) { return card.querySelector("p"); })) needed = true;
      if (cards.some(function(card) { return cards.some(function(nested) { return nested !== card && card.contains(nested); }); })) needed = true;
      cards.forEach(function(card) {
        var link = card.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href]");
        var url = link && absoluteUrl(link.getAttribute("href"));
        var key = url && homepageCanonicalUrl(url);
        if (key && seen[key]) needed = true;
        if (key) seen[key] = true;
      });
    });
    return needed;
  }

  function genericHomepageSectionedMarkdown(root) {
    if (!homepageRootPath() || document.querySelector("article h1, article [itemprop='articleBody']") || document.querySelectorAll("article p").length >= 6) return "";
    if (!homepageNeedsSectionCollector(root)) return "";
    var seen = {};
    var sections = [];
    var cardSelector = "article, li, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']";

    root.querySelectorAll("section, [role='region']").forEach(function(region) {
      var parent = region.parentElement;
      while (parent) {
        if (parent.matches && parent.matches("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return;
        parent = parent.parentElement;
      }
      if (listNoiseNode(region) || listNoiseNode(region.parentElement)) return;
      var heading = region.querySelector("h1, h2, h3, h4");
      var label = normalizeText(heading && heading.textContent);
      if (!label || rejectedHomepageLeadText(label, "")) return;
      var allCards = Array.prototype.slice.call(region.querySelectorAll(cardSelector));
      var cards = allCards.filter(function(card) {
        return !allCards.some(function(nested) { return nested !== card && card.contains(nested); });
      });
      var lines = [];
      cards.forEach(function(card) {
        var link = card.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href]");
        if (!link) return;
        var title = normalizeText(link.textContent || "");
        var url = absoluteUrl(link.getAttribute("href"));
        var key = url && homepageCanonicalUrl(url);
        if (!title || !url || seen[key]) return;
        seen[key] = true;
        var context = [
          normalizeText((card.querySelector("[class*='summary'], [class*='description'], [class*='excerpt'], p") || {}).textContent || "").slice(0, 240),
          normalizeText((card.querySelector("time") || {}).getAttribute && ((card.querySelector("time").getAttribute("datetime") || card.querySelector("time").textContent)) || "").slice(0, 80),
          normalizeText((card.querySelector("img[alt]:not([alt='']), figcaption") || {}).getAttribute && ((card.querySelector("img[alt]:not([alt='']), figcaption").getAttribute("alt") || card.querySelector("img[alt]:not([alt='']), figcaption").textContent)) || "").slice(0, 160)
        ].filter(Boolean);
        lines.push("- [" + title + "](" + url + ")" + (context.length ? " - " + context.join(" - ") : ""));
      });
      if (lines.length) sections.push("## " + label + "\n\n" + lines.join("\n"));
    });

    return sections.length >= 2 ? sections.join("\n\n") : "";
  }

  function genericPortalHomepageContent(metadata) {
    var sectionedMarkdown = genericHomepageSectionedMarkdown(document.body);
    if (sectionedMarkdown && document.querySelector("h1")) {
      return listContentResult({ title: metadata && metadata.title, excerpt: metadata && metadata.excerpt, markdown: sectionedMarkdown, textContent: sectionedMarkdown });
    }
    var leadRoot = genericHomepageLeadRoot(metadata, { minItems: 4 });
    if (!leadRoot) return null;
    sectionedMarkdown = genericHomepageSectionedMarkdown(document.body);
    if (sectionedMarkdown) {
      return listContentResult({ title: metadata && metadata.title, excerpt: metadata && metadata.excerpt, markdown: sectionedMarkdown, textContent: sectionedMarkdown });
    }

    var title = leadRoot.hero || (metadata && metadata.title) || document.title || location.hostname;
    var markdownParts = [];
    if (leadRoot.hero) markdownParts.push("# " + leadRoot.hero);
    if (metadata && metadata.excerpt) markdownParts.push(metadata.excerpt);
    if (leadRoot.headings.length >= 2) {
      markdownParts.push(leadRoot.headings.slice(0, 6).map(function(text) { return "- " + text; }).join("\n"));
    }
    markdownParts.push(listMarkdown(leadRoot.items.slice(0, 12)));

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

  function registerGenericPortalHomepageProfiles() {
    registerHostAwareProfile(true, genericPortalHomepageContent);
  }
