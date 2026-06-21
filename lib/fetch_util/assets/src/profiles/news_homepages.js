  function financialTimesContent(metadata) {
    var signature = docsHostSignature(metadata);
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

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: items
    });
  }

  function economistContent(metadata) {
    var signature = docsHostSignature(metadata);
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

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "The Economist",
      items: items
    });
  }

  function bloombergContent(metadata) {
    var signature = docsHostSignature(metadata);
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

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "Bloomberg",
      items: items
    });
  }

  function genericPortalHomepageContent(metadata) {
    var leadRoot = genericHomepageLeadRoot(metadata, { minItems: 4 });
    if (!leadRoot) return null;

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
