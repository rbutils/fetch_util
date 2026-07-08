  function mediaWikiPage() {
    var bodyClass = normalizeText((document.body && document.body.className) || "");

    return !!document.querySelector(
      "meta[name='generator'][content^='MediaWiki'], #mw-content-text, .mw-parser-output, .vector-body, .vector-body-inner, script[src*='load.php'], #firstHeading, .firstHeading"
    ) || /\bmediawiki\b|\bmw-/i.test(bodyClass);
  }

  function mediaWikiListPage(metadata) {
    var path = location.pathname || "";
    var title = normalizeText(firstText(["#firstHeading", ".firstHeading"]) || (metadata && metadata.title) || document.title);

    return /\/wiki\/(?:Special:(?:Pages|AllPages|Categories|WantedPages|PrefixIndex)|Category:)/i.test(path) ||
      /^(?:Special:(?:Pages|AllPages|Categories|WantedPages|PrefixIndex)|Category:)/i.test(title) ||
      /[?&]title=(?:Special%3A(?:Pages|AllPages|Categories|WantedPages|PrefixIndex)|Category%3A)/i.test(location.search || "");
  }

  function mediaWikiNode() {
    return document.querySelector("#mw-content-text .mw-parser-output") ||
      document.querySelector("#mw-content-text .mw-body-content") ||
      document.querySelector("#bodyContent .mw-parser-output") ||
      document.querySelector("#bodyContent .mw-body-content") ||
      document.querySelector(".mw-parser-output") ||
      document.querySelector(".vector-body-inner") ||
      document.querySelector(".vector-body") ||
      document.querySelector("#mw-content-text") ||
      document.querySelector("#bodyContent");
  }

  function mediaWikiRewriteRoot(root) {
    var selectors = [
      "#mw-panel",
      "#mw-navigation",
      ".vector-sidebar",
      ".vector-legacy-sidebar",
      ".vector-header",
      ".mw-sidebar",
      ".sidebar",
      ".portal",
      ".mw-editsection",
      ".mw-editsection-like",
      ".mw-jump-link",
      ".mw-jump",
      ".toc",
      "#toc",
      ".catlinks",
      "#catlinks",
      ".mw-hidden-catlinks",
      ".printfooter",
      ".noprint",
      ".mw-reference-text",
      ".reference-tooltip",
      ".mwe-popups",
      ".mwe-popups-container",
      ".oo-ui-popupWidget",
      ".navbox",
      "table.navbox"
    ];

    root.querySelectorAll(selectors.join(", ")).forEach(function(node) {
      node.remove();
    });

    root.querySelectorAll(".toc").forEach(function(toc) {
      var itemCount = toc.querySelectorAll("li").length;
      var linkCount = toc.querySelectorAll("a[href]").length;
      if (itemCount > 6 || linkCount > 8 || normalizeText(toc.textContent || "").length > 500) toc.remove();
    });

    root.querySelectorAll("[role='tooltip'], [class*='tooltip' i], [class*='popup' i]").forEach(function(node) {
      if (node.closest("article, .mw-parser-output, #mw-content-text, #bodyContent")) node.remove();
    });

  }

  function mediaWikiContent(metadata) {
    if (!mediaWikiPage()) return null;

    var title = firstText(["#firstHeading", ".firstHeading"]) ||
      normalizeText((metadata && metadata.title) || document.title).replace(/\s*[-|–]\s*MediaWiki.*$/i, "");

    var node = mediaWikiNode();
    if (!node) return null;

    var root = cleanClone(node);
    mediaWikiRewriteRoot(root);

    root.querySelectorAll("script, style, noscript, template").forEach(function(el) {
      el.remove();
    });

    var markdown = normalizeText(root.textContent || "");
    if (normalizeText(markdown).length < 30) return null;

    if (title && !markdownStartsWithTitle(markdown, title)) {
      markdown = "# " + title + "\n\n" + markdown;
    }

    return {
      title: title || (metadata && metadata.title) || document.title,
      byline: metadata && metadata.byline,
      excerpt: normalizeText(markdown).slice(0, 280) || (metadata && metadata.excerpt) || null,
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: metadata && metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: mediaWikiListPage(metadata) ? "list" : "article",
      hostAware: true
    };
  }

  registerHostAwareProfile(true, mediaWikiContent);
