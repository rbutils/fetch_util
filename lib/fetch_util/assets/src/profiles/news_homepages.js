  function financialTimesContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!/(^|\b)ft\.com\b|financial times/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("main a[href*='/content/'], main a[href*='/stream/']").forEach(function(link) {
      var title = normalizeText(link.textContent).replace(/^opinion content\.?\s*/i, "");
      var url = absoluteUrl(link.getAttribute("href"));
      var container = link.closest("article, section, .story-group__article, .story-group-slice, .o-teaser") || link.parentElement;
      var detail = searchItemDetail(container, title);

      if (!title || !url || title.length < 18 || title.length > 180 || seen[url]) return;
      if (/^(top stories|news|opinion|companies|markets news|video|life & arts|spotlight|most read|must-reads you missed|more opinion|more companies|more europe news|more markets news|more technology)$/i.test(title)) return;

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }

  function economistContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!hostMatches(/(^|\.)economist\.com$/) && !/economist/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("main a[href]").forEach(function(link) {
      var href = link.getAttribute("href") || "";
      if (!/(\/\d{4}\/\d{2}\/\d{2}\/|\/interactive\/)/.test(href)) return;

      var title = searchItemTitle(link);
      var url = absoluteUrl(href);
      var container = link.closest("article, section, li, div") || link.parentElement;
      var detail = searchItemDetail(container, title);

      if (!title || !url || title.length < 18 || title.length > 180 || seen[url]) return;
      if (/^(subscribe|log in|the economist pro|weekly edition|current topics|world|business & economics|opinion|in depth|culture, history & society|our a-to-zs|featured story)$/i.test(title)) return;

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "The Economist",
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }

  function bloombergContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!hostMatches(/(^|\.)bloomberg\.com$/) && !/bloomberg/i.test(signature)) return null;
    if (/(\/news\/|\/opinion\/|\/features\/|\/graphics\/)/.test(location.pathname)) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("a[href*='/news/articles/'], a[href*='/news/features/'], a[href*='/opinion/articles/'], a[href*='/features/'], a[href*='/graphics/'], a[href*='/news/newsletters/']").forEach(function(link) {
      var title = searchItemTitle(link).replace(/^AP Photo\s*/i, "").replace(/^Opinion\s*/i, "");
      var url = absoluteUrl(link.getAttribute("href"));
      var container = link.closest("article, section, div") || link.parentElement;
      var detail = searchItemDetail(container, title);

      if (!title || !url || title.length < 18 || title.length > 220 || seen[url]) return;
      if (/^(bloomberg opinion|bloomberg businessweek|newsletter:|watch)$/i.test(title)) return;

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "Bloomberg",
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }

