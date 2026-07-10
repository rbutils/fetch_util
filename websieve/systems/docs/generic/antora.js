  function antoraVisibleTexts(selectors) {
    var seen = {};
    var items = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        var text = normalizeText(node.textContent);
        if (!text || seen[text]) return;
        seen[text] = true;
        items.push(text);
      });
    });

    return items;
  }

  function antoraDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "antora") return null;

    var article = firstMatchingNode(["main.main article.doc", "article.doc", "main.main", "main"]);
    if (!article) return null;

    var heading = firstRootText(article, ["h1"]);
    var landing = !heading;

    if (landing) {
      var title = normalizeText((metadata.title || document.title).replace(/\s*::\s*Fedora Docs$/i, ""));
      var sections = antoraVisibleTexts(["article.doc h2", "article.doc h3"]).filter(function(text) {
        return text.length >= 4 && !/^(contents?|navigation)$/i.test(text);
      });
      var seen = {};
      var items = [];
      var cardSelector = ".homepage-card, .home-card, .card, [class*='homepage-card'], [class*='home-card'], [class*='doc-card'], li, section";

      article.querySelectorAll("a.homepage-link[href], a.homepage-link-primary[href], a.homepage-link-secondary[href]").forEach(function(link) {
        var rawHref = link.getAttribute("href");
        var url = rawHref ? rawHref : absoluteUrl(link.href);
        var text = normalizeText(link.textContent);
        var detail = "";
        var card = link.closest(cardSelector);
        var sibling = link.nextElementSibling;
        if (sibling && /^(P|DIV|UL|OL)$/i.test(sibling.tagName || "") && (!card || sibling.closest(cardSelector) === card)) detail = normalizeText(sibling.textContent);
        if (!detail) {
          var container = card || link.closest("section, div, li, article") || link.parentElement;
          detail = docsScopedFirstText(container, ["p", "li"], cardSelector);
          if (detail === text) detail = "";
        }

        if (!url || !text || text.length < 4 || seen[url]) return;
        seen[url] = true;
        items.push({ text: text, url: url, detail: detail });
      });

      if (!items.length) return null;

      var parts = [];
      if (title) parts.push("# " + title);
      if (sections.length) parts.push(sections.map(function(text) { return "- " + text; }).join("\n"));
      parts.push(listMarkdown(items));
      var markdown = parts.filter(Boolean).join("\n\n").trim();

      return {
        title: title || metadata.title,
        byline: null,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || location.hostname,
        publishedTime: null,
        html: "",
        markdown: markdown,
        textContent: normalizeText(markdown),
        readerMode: false,
        contentType: "list"
      };
    }

    return docsArticleContent(metadata, article, {
      title: heading || normalizeText((metadata.title || document.title).replace(/\s*::\s*Fedora Docs$/i, "")),
      rewriteRoot: function(root) {
        root.querySelectorAll(".toolbar, .crumbs, .page-languages, .languages-menu, .languages-menu-toggle, .page-versions, .page-navigation, .nav-container, .edit-this-page, .pagination, aside, nav").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("div, p, section, small").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (!text || text.length > 220) return;
          if (/(the .* docs team|version\s+[A-Z]?\d+|last review\b|last build\b|edit this page\b|report an issue\b)/i.test(text)) el.remove();
        });
      }
    });
  }
