  function homepageRootPath() {
    var path = (location.pathname || "").toLowerCase();
    return path === "" || path === "/" || /^\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?$/i.test(path);
  }

  function rejectedHomepageLeadText(text, href) {
    text = normalizeText(text || "");
    href = href || "";
    if (!text) return true;
    if (text.length > 180) return true;
    if (/^(home|menu|search|sign in|log in|login|register|create account|my account|account|subscribe|newsletter|advertise|contact|about|privacy|terms|cookies?|careers?|help|support|learn more|read more|view all|see all|show more|skip to content|open menu|close|language|english|français|deutsch|español|italiano)$/i.test(text)) return true;
    if (/^(buy|sell|rent|sold|agents?|homes?|condos?|commercial|mortgages?|calculators?|guides?|news|travel|trains?|buses?|flights?|hotels?|cars?|packages?|deals?|offers?|destinations?|routes?|stations?|tickets?|timetables?)$/i.test(text) && text.length < 18) return true;
    if (/\b(?:privacy|terms|cookie|login|signin|sign-in|register|account|newsletter|subscribe|advertise|contact|about)\b/i.test(href)) return true;
    return false;
  }

  function homepageCardRoot(link) {
    var selector = "article, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']";
    return link.closest && link.closest(selector);
  }

  function homepageCanonicalUrl(url) {
    return listCanonicalKey(url)
      .replace(/([?&])(?:utm_[^&=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)=[^&]*&?/gi, "$1")
      .replace(/[?&]$/, "");
  }

  function homepageHasEditorialSections(root) {
    var count = 0;
    root.querySelectorAll("section, [role='region']").forEach(function(region) {
      var parent = region.parentElement;
      while (parent) {
        if (parent.matches && parent.matches("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return;
        parent = parent.parentElement;
      }
      if (listNoiseNode(region) || listNoiseNode(region.parentElement)) return;
      if (!region.querySelector("h1, h2, h3, h4")) return;
      if (region.querySelector("article a[href], li a[href], [class*='card'] a[href], [class*='story'] a[href]")) count += 1;
    });
    return count >= 2;
  }

  function genericHomepageLeadRoot(metadata, options) {
    options = options || {};
    if (!document.body || !homepageRootPath()) return null;
    if (homepageHasEditorialSections(document)) return null;
    if (typeof articleLikePath === "function" && articleLikePath()) return null;
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
        if (headings.length >= 8) return;
        var text = normalizeText(heading.textContent || "");
        if (heading.closest && heading.closest("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return;
        if (listNoiseNode(heading.parentElement)) return;
        if (text.length >= 6 && text.length <= 90 && !rejectedHomepageLeadText(text, "")) headings.push(text);
      });

      root.querySelectorAll("a[href]").forEach(function(link) {
        if (items.length >= 18) return;
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

  function utilitySectionNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var text = normalizeText(node.textContent || "");
    // Large article containers on wiki-style pages can look utility-like because they
    // contain many links, but they are still substantive content and should survive.
    if (text.length > 1000 && node.querySelectorAll("p, h1, h2, h3, h4, h5, h6").length >= 2) return false;

    var heading = normalizeText((node.querySelector("h2, h3, h4, h5, h6, strong, b") || {}).textContent || "");
    if (!heading) {
      // Check first text node or first child's text as a fallback
      var firstChild = node.firstElementChild || node;
      var firstText = normalizeText(firstChild.textContent || "");
      // Only use if the first text is short enough to be a heading
      if (firstText.length <= 40) heading = firstText;
    }
    if (!utilityHeadingText(heading)) return false;

    return node.querySelectorAll("a[href], li, tr").length >= 3;
  }
