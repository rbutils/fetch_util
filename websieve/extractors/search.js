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

  function externalHttpUrl(value) {
    try {
      var parsed = new URL(value, location.href);
      var sameEngine = parsed.hostname === location.hostname ||
        (googleEngineHost(location.hostname) && googleEngineHost(parsed.hostname)) ||
        (/(^|\.)bing\.com$/i.test(location.hostname) && /(^|\.)bing\.com$/i.test(parsed.hostname)) ||
        (/(^|\.)duckduckgo\.com$/i.test(location.hostname) && /(^|\.)duckduckgo\.com$/i.test(parsed.hostname));
      if (!/^https?:$/i.test(parsed.protocol) || sameEngine) return null;
      return parsed.href;
    } catch (_error) {
      return null;
    }
  }

  function googleEngineHost(host) {
    return /(^|\.)google\.[a-z]{2,3}(?:\.[a-z]{2})?$/i.test(host);
  }

  function equivalentGoogleWrapperHosts(left, right) {
    var leftBase = left.toLowerCase().replace(/^www\./, "");
    var rightBase = right.toLowerCase().replace(/^www\./, "");
    return /^google\.[a-z]{2,3}(?:\.[a-z]{2})?$/.test(leftBase) && leftBase === rightBase;
  }

  function normalizeSearchTarget(url) {
    try {
      var parsed = new URL(url, location.href);

      if (equivalentGoogleWrapperHosts(location.hostname, parsed.hostname) && parsed.pathname === "/url") {
        var wrappedGoogle = parsed.searchParams.get("q") || parsed.searchParams.get("url");
        if (!wrappedGoogle) return null;
        try {
          wrappedGoogle = decodeURIComponent(wrappedGoogle);
        } catch (_googleDecodeError) {
          return null;
        }
        return externalHttpUrl(wrappedGoogle);
      }

      if (/(^|\.)bing\.com$/i.test(location.hostname) && /(^|\.)bing\.com$/i.test(parsed.hostname) && parsed.pathname === "/ck/a") {
        var encodedBingTarget = parsed.searchParams.get("u") || "";
        if (!/^a1[A-Za-z0-9_-]+={0,2}$/.test(encodedBingTarget)) return null;
        var base64 = encodedBingTarget.slice(2).replace(/-/g, "+").replace(/_/g, "/");
        if (base64.length % 4 === 1) return null;
        base64 += "=".repeat((4 - (base64.length % 4)) % 4);
        try {
          var binary = atob(base64);
          var escaped = "";
          for (var index = 0; index < binary.length; index += 1) {
            escaped += "%" + ("0" + binary.charCodeAt(index).toString(16)).slice(-2);
          }
          return externalHttpUrl(decodeURIComponent(escaped));
        } catch (_bingDecodeError) {
          return null;
        }
      }

      if (/(^|\.)duckduckgo\.com$/i.test(location.hostname) && /(^|\.)duckduckgo\.com$/i.test(parsed.hostname) && /^\/l\//.test(parsed.pathname)) {
        var wrappedDuckDuckGo = parsed.searchParams.get("uddg");
        if (!wrappedDuckDuckGo) return null;
        try {
          wrappedDuckDuckGo = decodeURIComponent(wrappedDuckDuckGo);
        } catch (_duckDuckGoDecodeError) {
          return null;
        }
        return externalHttpUrl(wrappedDuckDuckGo);
      }

    } catch (_error) {
    }

    return absoluteUrl(url);
  }

  function sponsoredSearchResult(title, detail, href, rawHref) {
    var text = (title + " " + detail).toLowerCase();
    return /\bad\b|sponsored|report ad/.test(text) || /[?&](ad_|ad=|ad_domain=)/i.test(href) || /(?:^|\/)y\.js\?/i.test(rawHref || "");
  }

  function searchEngineSource() {
    var host = location.hostname.toLowerCase();
    if (/(^|\.)google\./.test(host)) return "google";
    if (/(^|\.)duckduckgo\.com$/.test(host)) return "duckduckgo";
    if (host === "bing.com" || /\.bing.com$/.test(host)) return "bing";
    if (host === "search.brave.com") return "brave";
    if (host === "ecosia.org" || /\.ecosia.org$/.test(host)) return "ecosia";
    return null;
  }

  function searchResultContainers(source) {
    var selectors = {
      google: ".MjjYud, .g",
      duckduckgo: "article[data-testid='result'], .result",
      bing: "li.b_algo, .b_algo",
      brave: "[data-testid='result'], .snippet, .fdb",
      ecosia: "article[data-test-id='result'], .result"
    };
    return selectors[source] ? document.querySelectorAll(selectors[source]) : [];
  }

  function searchResultLink(container, source) {
    var selectors = {
      google: "h3",
      duckduckgo: ".result__title a, a.result__a, a[data-testid='result-title-a']",
      bing: "h2 a",
      brave: "a[data-testid='result-title'], a.result-header, h2 a, h3 a",
      ecosia: "a.result-title, a[data-test-id='result-title'], h2 a, h3 a"
    };
    var heading = container.querySelector(selectors[source] || "h2 a, h3 a");
    if (!heading) return null;
    return heading.tagName === "A" ? heading : heading.closest("a");
  }

  function searchResultDetail(container, title, source) {
    var selectors = {
      google: ".VwiC3b, .yXK7lf, [data-sncf], .IsZvec",
      duckduckgo: ".result__snippet, [data-testid='result-snippet']",
      bing: ".b_caption p",
      brave: ".snippet-description, [data-testid='result-description'], .description",
      ecosia: ".result-snippet, [data-test-id='result-snippet']"
    };
    var snippet = container.querySelector(selectors[source] || "");
    return searchItemDetail(snippet || container, title);
  }

  function sponsoredSearchContainer(container, source) {
    var marker = normalizeText([
      container.getAttribute("aria-label") || "",
      container.getAttribute("data-text-ad") || "",
      container.className || ""
    ].join(" "));
    if (/\b(ad|advert|sponsored|promoted)\b/i.test(marker)) return true;
    if (source === "google" && (container.matches(".uEierd") || container.closest(".uEierd"))) return true;
    if (container.querySelector(".related-question-pair, .related-searches, [data-async-context*='related']")) return true;
    return source === "duckduckgo" && container.matches(".result--ad, [data-testid='result-ad']");
  }

  function emptySearchResult(metadata) {
    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: searchQuery(),
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: "",
      textContent: "",
      markdown: "",
      readerMode: false,
      contentType: "search",
      resultCount: 0
    };
  }

  function blockedSearchPage(bodyText) {
    return /captcha|verify you are human|unusual traffic|security check|before you continue|enable javascript to continue/i.test(bodyText);
  }

  function pushSearchItem(items, seen, title, href, detail) {
    title = normalizeText(title);
    var rawHref = href;
    href = normalizeSearchTarget(href);
    detail = normalizeText(detail);

    if (!href || !title) return;
    if (/^(images|videos|news|maps|shopping|sign in|privacy|terms|feedback|more|people also ask|related searches)$/i.test(title)) return;
    if (/^(javascript:|mailto:)/i.test(href)) return;
    if (!isSearchResultHref(href)) return;
    if (sponsoredSearchResult(title, detail, href, rawHref)) return;

    var key = title + "|" + href;
    if (seen[key]) return;
    seen[key] = true;

    items.push({ text: title, url: href, detail: detail });
  }

  function searchResultsContent(metadata) {
    var source = searchEngineSource();
    if (!source) return null;
    var bodyText = normalizeText((document.body && document.body.textContent) || "");
    if (typeof consentWallPage === "function" && consentWallPage(metadata.title || document.title, bodyText || pageReadableText() || "")) {
      return null;
    }
    if (blockedSearchPage(bodyText)) return null;

    var items = [];
    var seen = {};
    searchResultContainers(source).forEach(function(container) {
      if (sponsoredSearchContainer(container, source)) return;
      var link = searchResultLink(container, source);
      if (!link) return;
      var title = searchItemTitle(link);
      pushSearchItem(items, seen, title, link.getAttribute("href"), searchResultDetail(container, title, source));
    });

    if (!items.length) return emptySearchResult(metadata);

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
