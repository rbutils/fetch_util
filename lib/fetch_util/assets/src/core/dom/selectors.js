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
