  function fazContent(metadata) {
    if (!hostMatches(/(^|\.)faz\.net$/)) return null;
    return fazHomepageContent(metadata) || fazArticleContent(metadata);
  }

  function fazHomepageContent(metadata) {
    var path = (location.pathname || "").toLowerCase();
    if (!(path === "" || path === "/" || path === "/aktuell" || path === "/aktuell/")) return null;

    var seen = {};
    var items = [];
    document.querySelectorAll("main a[href]").forEach(function(link) {
      if (items.length >= 18) return;
      var href = link.getAttribute("href") || "";
      if (!/\.html(?:$|[?#])/i.test(href)) return;

      var title = searchItemTitle(link).replace(/^[A-ZÄÖÜ0-9.,:;!?\s-]{4,}\s*:\s*/u, "");
      var url = absoluteUrl(href);
      if (!title || title.length < 18 || title.length > 180 || seen[url]) return;
      if (/^(liveblog|ticker|mehr zum thema|alle themen|bildbeschreibung ausklappen|artikelrechte erwerben)$/i.test(title)) return;

      var container = link.closest("article, section, li, [data-selector*='teaser'], [data-external-selector*='teaser']") || link.parentElement;
      var detail = searchItemDetail(container, title);
      if (detail.length > 180) detail = "";

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;
    return listContentResult({
      title: (metadata && metadata.title) || document.title,
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || "Frankfurter Allgemeine Zeitung",
      items: items
    });
  }

  function fazArticleContent(metadata) {
    if (!/\.html(?:$|[?#])/i.test(location.pathname || "")) return null;

    var body = document.querySelector(".walled-content") ||
      document.querySelector(".at-article-body") ||
      document.querySelector("[data-external-selector='body-elements']") ||
      document.querySelector(".article-body");
    if (!body || !body.querySelector("p, [data-selector='body-paragraph']")) return null;

    fazRemoveFalsePaywallMarker(body);
    return profileArticleContent(metadata, body, {
      title: firstText(["[data-external-selector='header-title']", "article h1", "main h1", "h1"]) || (metadata && metadata.title),
      byline: firstText(["[data-external-selector*='header-detail'] .meta1", "[rel='author']"]) || (metadata && metadata.byline),
      minTextLength: 500,
      prependTitle: false,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[data-selector='article-rights']",
          "[data-external-selector='footer-links']",
          "[data-external-selector='taboola-ads']",
          "[id*='taboola']",
          "[class*='taboola']",
          "[class*='trc_']",
          "[class*='tbl-']",
          "[class*='aside-slot']",
          "[class*='newsletter' i]",
          "[class*='recommend' i]",
          "[class*='share' i]"
        ].join(", "));

        root.querySelectorAll("section, div").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(mehr zum thema|f\.a\.z\.-artikel häufiger in ihren suchergebnissen sehen)/i.test(text)) el.remove();
        });
      },
      postProcessMarkdown: function(markdown) {
        return markdown.replace(/^###\s+(.+)$/gm, "**$1**");
      }
    });
  }

  function fazRemoveFalsePaywallMarker(body) {
    var text = normalizeText(body && body.textContent);
    if (text.length < 2500) return;
    if (/(nur für abonnenten|nur für abonnent|abo abschließen|weiterlesen mit|lesen sie diesen artikel mit)/i.test(text)) return;
    removeAll(document, "#taboola-below-paywall-thumbnails, #taboola-below-liveblog-thumbnails, [id*='paywall' i][id*='taboola' i], [id*='liveblog' i][id*='taboola' i]");
    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      if (/isAccessibleForFree/i.test(script.textContent || "")) script.remove();
    });
  }

  registerHostAwareProfile(true, fazContent);