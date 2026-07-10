  function pressReleaseNode() {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)PressRelease$/i.test(type);
      });
    }) || null;
  }

  function strongPressReleaseSignals(metadata) {
    if (pressReleaseNode()) return true;

    var context = normalizeText([
      document.title,
      metadata && metadata.title,
      metadata && metadata.excerpt,
      metadata && metadata.siteName,
      metadataValue("article:section", "property"),
      location.hostname,
      location.pathname,
      firstText(["main h1", "article h1", "h1"])
    ].join(" ")).toLowerCase();
    var bodyLead = normalizeText((document.body && document.body.innerText) || "").slice(0, 2500).toLowerCase();
    var investorRelationsContext = /\b(?:investor relations|earnings release|quarterly results?|financial statements?|form\s*(?:10-k|10-q|8-k)|sec filing)\b/.test(context + " " + bodyLead);
    var newsroomHost = /(^|\.)(prnewswire\.com|cision\.com|globenewswire\.com|businesswire\.com|apple\.com|amazon\.com|google)$/i.test(location.hostname || "") && /\b(newsroom|news-releases?|company-news|press)\b/i.test(location.pathname || "");
    var corporateReleaseRoute = /\/(?:newsroom|news-releases?|press(?:-release)?|company-news|about\/news)\//i.test(location.pathname || "");
    var dateline = /\b[A-Z][A-Z .'-]{2,40},\s+(?:Jan\.?|Feb\.?|Mar\.?|Apr\.?|May|Jun\.?|Jul\.?|Aug\.?|Sep\.?|Sept\.?|Oct\.?|Nov\.?|Dec\.?)\s+\d{1,2},\s+\d{4}\s*(?:\/PRNewswire\/|--|–)/.test((document.body && document.body.innerText) || "");
    var releaseWords = /\b(press release|news release|announces?|announced|launches?|unveils?|reports? results)\b/.test(context + " " + bodyLead);

    return releaseWords && !investorRelationsContext && (newsroomHost || corporateReleaseRoute || dateline);
  }

  function pressReleaseRoot() {
    var selectors = [
      "[itemtype*='PressRelease']",
      "[itemprop='articleBody']",
      ".release-body",
      "#release-body",
      "[class*='release-body' i]",
      "[class*='news-release-content' i]",
      "[class*='press-release' i] [class*='body' i]",
      "[class*='article-body' i]",
      "[data-testid*='article-body' i]",
      "article",
      "main article",
      "main"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = Array.prototype.slice.call(document.querySelectorAll(selectors[i]));
      nodes.sort(function(a, b) { return textLength(b) - textLength(a); });
      for (var j = 0; j < nodes.length; j += 1) {
        var text = normalizeText(nodes[j].textContent || "");
        if (text.length >= 250 && nodes[j].querySelectorAll("p, li, blockquote").length >= 2) return nodes[j];
      }
    }

    return null;
  }

  function pressReleaseContent(metadata) {
    if (!strongPressReleaseSignals(metadata)) return null;

    var schema = pressReleaseNode();
    var root = pressReleaseRoot();
    var title = entityText(schema && (schema.headline || schema.name)) || metadata.title || firstText(["main h1", "article h1", "h1"]) || document.title;
    var description = entityText(schema && schema.description) || metadata.excerpt;
    var publishedTime = entityText(schema && (schema.datePublished || schema.dateModified)) || metadata.publishedTime || null;
    var byline = entityName(schema && (schema.author || schema.publisher)) || metadata.byline || null;
    var clone = root ? cleanClone(root) : document.createElement("div");

    if (!root && schema) {
      var schemaBody = entityText(schema.articleBody || schema.text || schema.description);
      if (schemaBody) clone.innerHTML = "<p>" + schemaBody.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n{2,}/g, "</p><p>") + "</p>";
    }

    if (!normalizeText(clone.textContent || "")) return null;

    cleanupAgentRoot(clone);
    cleanupGenericArticleRoot(clone);
    removeAll(clone, "nav, header, footer, aside, form, script, style, noscript, [class*='related' i], [class*='recommend' i], [class*='share' i], [class*='social' i], [class*='subscribe' i], [class*='newsletter' i]");

    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 250) return null;

    if (title && markdown && !markdownStartsWithTitle(markdown, title)) {
      markdown = "# " + normalizeText(title) + "\n\n" + markdown;
      text = normalizeText(markdown);
    }

    return {
      title: normalizeText(title),
      byline: byline,
      excerpt: description || text.slice(0, 280) || null,
      siteName: metadata.siteName || location.hostname,
      publishedTime: publishedTime,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "press_release"
    };
  }
