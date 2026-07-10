  function isSearchResultHref(url) {
    try {
      var parsed = new URL(url, location.href);
      var sameHost = parsed.hostname === location.hostname;
      if (!sameHost) return /^https?:/.test(parsed.protocol);

      return /^\/(url|imgres|search|ck\/a|y\.js|l\/.+|aclick)/.test(parsed.pathname) || parsed.pathname === "/";
    } catch (_error) {
      return false;
    }
  }

  function normalizeSearchTarget(url) {
    try {
      var parsed = new URL(url, location.href);
      ["uddg", "u", "u3", "r", "rut", "ad_domain"].forEach(function(name) {
        var value = parsed.searchParams.get(name);
        if (value && /^https?:/i.test(decodeURIComponent(value))) url = decodeURIComponent(value);
      });
    } catch (_error) {
    }

    return absoluteUrl(url);
  }

  function sponsoredSearchResult(title, detail, href, rawHref) {
    var text = (title + " " + detail).toLowerCase();
    return /\bad\b|sponsored|report ad/.test(text) || /[?&](ad_|ad=|ad_domain=)/i.test(href) || /(?:^|\/)y\.js\?/i.test(rawHref || "");
  }

  function pushSearchItem(items, seen, title, href, detail) {
    title = normalizeText(title);
    var rawHref = href;
    href = normalizeSearchTarget(href);
    detail = normalizeText(detail);

    if (!href || !title) return;
    if (title.length < 8 || title.length > 180) return;
    if (/^(images|videos|news|maps|shopping|sign in|privacy|terms|feedback|more)$/i.test(title)) return;
    if (/^(javascript:|mailto:)/i.test(href)) return;
    if (!isSearchResultHref(href)) return;
    if (sponsoredSearchResult(title, detail, href, rawHref)) return;

    var key = title + "|" + href;
    if (seen[key]) return;
    seen[key] = true;

    items.push({ text: title, url: href, detail: detail });
  }

  function searchResultsContent(metadata) {
    var bodyText = normalizeText((document.body && document.body.textContent) || "");
    if (typeof consentWallPage === "function" && consentWallPage(metadata.title || document.title, bodyText || pageReadableText() || "")) {
      return null;
    }

    var items = [];
    var seen = {};
    var selectors = [
      ".result__title a, [data-testid='result-title-a']",
      "li.b_algo h2 a, .b_algo h2 a",
      "a h3",
      "main a[data-testid='result-title-a'], main article a[href], main .result a[href], main .snippet a[href]"
    ];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        var link = node.tagName === "A" ? node : node.closest("a");
        if (!link) return;

        var container = link.closest("article, li, div[data-testid], .result, .b_algo, .g, .fdb") || link.parentElement;
        var title = searchItemTitle(link);
        pushSearchItem(items, seen, title, link.getAttribute("href"), searchItemDetail(container, title));
      });
    });

    if (items.length < 4) {
      document.querySelectorAll("main a[href], [role='main'] a[href]").forEach(function(link) {
        var container = link.closest("article, li, div, section") || link.parentElement;
        var title = searchItemTitle(link);
        pushSearchItem(items, seen, title, link.getAttribute("href"), searchItemDetail(container, title));
      });
    }

    if (!items.length) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: searchQuery(),
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "search",
      resultCount: items.length
    };
  }
