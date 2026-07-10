  function unidadEditorialArticleContent(metadata) {
    return unidadEditorialEngineArticleContent(metadata, {
      hostPattern: /(^|\.)(?:elmundo|expansion|sport)\.es$/,
      bodySelectors: [
        ".ue-c-article__body[data-section='articleBody']",
        ".ue-c-article__body",
        ".article-body",
        "#article-body",
        "div[itemprop='articleBody']",
        "[itemprop='articleBody']"
      ],
      sportParagraphFallback: true,
      extraRemovalSelectors: [
        ".ft-ad", ".ft-mol-related", ".ft-mol-multimedia", ".jwplayer",
        "[class*='jw-' i]", "[class*='taboola' i]", "[class*='trc_' i]"
      ]
    });
  }

  function unidadEditorialHomepageContent(metadata) {
    if (!hostMatches(/(^|\.)(?:elmundo|expansion|sport)\.es$/)) return null;
    if (!homepageRootPath()) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll(".ue-c-cover-content, article, section").forEach(function(card) {
      if (card.closest("header, nav, footer, aside, [class*='comment' i]")) return;

      var link = card.querySelector(".ue-c-cover-content__link[href], h1 a[href], h2 a[href], h3 a[href]");
      if (!link || link.closest("[class*='comment' i], .ue-c-cover-content__comments")) return;

      var href = link.getAttribute("href") || "";
      if (!/\/(?:\d{4}\/\d{2}\/\d{2}\/|[a-f0-9]{24}\.html|\d{2}_\d{4}_\d{8}_)/i.test(href)) return;

      var title = normalizeText(((link.querySelector(".ue-c-cover-content__headline, h1, h2, h3") || {}).textContent) || link.textContent || "");
      var url = absoluteUrl(href);
      if (!title || title.length < 18 || title.length > 220 || !url || seen[url]) return;
      if (/^(comentarios?|ver comentarios?|opinar|participa)$/i.test(title)) return;

      seen[url] = true;
      items.push({ text: title, url: url, detail: searchItemDetail(card, title) });
    });

    if (items.length < 4) return null;

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: items
    });
  }

  registerHostAwareProfile(true, function(metadata, pageText) {
    return unidadEditorialArticleContent(metadata) ||
      unidadEditorialHomepageContent(metadata);
  });
