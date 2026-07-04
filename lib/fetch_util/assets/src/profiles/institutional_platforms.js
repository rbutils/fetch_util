  function drupalPlatformPage() {
    var generator = document.querySelector("meta[name='Generator' i], meta[name='generator' i]");
    var generatorContent = normalizeText(generator && generator.getAttribute("content"));
    if (/\bDrupal\b/i.test(generatorContent)) return true;
    if (document.querySelector(".field--name-body, [class*='field--name-' i], [class*='node--type-' i]")) return true;
    return /(?:^|\s)(?:path-[\w-]+|node-[\w-]+)(?:\s|$)/i.test((document.body && document.body.className) || "");
  }

  function institutionalArticleResult(metadata, root, options) {
    options = options || {};
    if (!root || textLength(root) < (options.minText || 200)) return null;

    var clone = options.preserveContentNav ? safeDeepClone(root, document) : cleanClone(root);
    if (options.preserveContentNav) {
      clone.querySelectorAll("nav.contents, nav[class*='contents' i]").forEach(function(nav) {
        var section = document.createElement("section");
        section.innerHTML = nav.innerHTML;
        nav.replaceWith(section);
      });
      cleanupAgentRoot(clone);
      clone.querySelectorAll("a").forEach(function(el) {
        var href = el.getAttribute("href");
        if (href) el.setAttribute("href", absoluteUrl(href));
      });
    }
    if (options.strip) options.strip(clone);

    var markdown = markdownFor(clone.innerHTML);
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < (options.minText || 200)) return null;

    var titleRoot = options.titleRoot || document;
    var title = normalizeText(((titleRoot.querySelector("h1") || {}).textContent) || options.title || metadata.title || document.title);
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: options.contentType || "article",
      hostAware: true,
      docsLike: !!options.docsLike
    };
  }

  function eurLexDocumentContent(metadata) {
    var root = document.querySelector("#MainContent .EurlexContent #document1") ||
      document.querySelector("#MainContent .EurlexContent #textTabContent") ||
      document.querySelector("#MainContent .EurlexContent #PP1Contents") ||
      document.querySelector("#MainContent .EurlexContent");
    if (!root || !document.querySelector("#MainContent .EurlexContent")) return null;
    if (!document.querySelector("#op-header") && !document.querySelector(".PageShare")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 300,
      docsLike: true,
      title: normalizeText(((document.querySelector("#MainContent .EurlexContent #PP1Contents #title, #MainContent .EurlexContent #PP1Contents #englishTitle") || {}).textContent) || ""),
      titleRoot: document.querySelector("#MainContent") || document,
      strip: function(clone) {
        clone.querySelectorAll("#translatedTitle.hidden, #originalTitle.hidden, .hidden, .PageShare, .AffixSidebarWrapper").forEach(function(el) { el.remove(); });
      }
    });
  }

  function governmentProgramMicrositeContent(metadata) {
    var root = document.querySelector("main#main-content .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main[role='main'] .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main#main-content .node-intro") ||
      null;
    if (!root) return null;
    if (!document.querySelector(".usa-megamenu, .usa-nav__submenu") && !document.querySelector(".usa-banner")) return null;
    if (!root.querySelector("h1, .microsite-title, .field--name--field-intro, .field--name-field-intro")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 350,
      titleRoot: root,
      strip: function(clone) {
        clone.querySelectorAll(".group-menu, [class*='group-menu'], .usa-breadcrumb, [id*='breadcrumb' i], .slick-dots, .slick-arrow").forEach(function(el) { el.remove(); });
      }
    });
  }

  function europaServiceLandingContent(metadata) {
    var root = document.querySelector("main#main-content #main-article") ||
      document.querySelector("main#main-content") ||
      document.querySelector("main[role='main']");
    if (!root || !document.querySelector("#feedback-form")) return null;
    if (!document.querySelector("main#main-content") || !root.querySelector("nav.contents, .contents, h1")) return null;
    if (!/\bYour Europe\b/i.test([metadata.siteName || "", metadata.title || "", document.title || "", document.body.textContent || ""].join(" "))) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 150,
      preserveContentNav: true,
      titleRoot: document.querySelector("main#main-content") || root,
      strip: function(clone) {
        clone.querySelectorAll("#feedback-form, [id*='feedback' i], [class*='feedback' i], .share, [id^='sh-']").forEach(function(el) { el.remove(); });
      }
    });
  }

  function drupalInstitutionalContent(metadata) {
    if (!drupalPlatformPage()) return null;

    var root = document.querySelector(".field--name-body") ||
      document.querySelector("[class*='field--name-body' i]") ||
      document.querySelector("[itemprop='articleBody']");
    if (!root || textLength(root) < 200) return null;

    return institutionalArticleResult(metadata, root, { titleRoot: document });
  }

  function institutionalTopicCardListContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("[id*='listView' i], [role='list'], [class*='topic' i][class*='list' i], [class*='card' i][class*='grid' i]"));
    var best = null;

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var topicishRoot = /topic|taxonomy|listview/i.test((root.id || "") + " " + (root.className || "") + " " + root.getAttribute("data-sf-element"));

      root.querySelectorAll("a[href]").forEach(function(link) {
        if (items.length >= 240) return;
        var href = link.getAttribute("href") || "";
        var url = absoluteUrl(href);
        var title = normalizeText(link.getAttribute("aria-label") || ((link.querySelector("h2, h3, h4") || {}).textContent) || "");
        var paragraphs = Array.prototype.slice.call(link.querySelectorAll("p"));
        var detail = "";

        if (!title && paragraphs.length) title = normalizeText(paragraphs[paragraphs.length - 1].textContent || link.textContent || "");
        if (paragraphs.length > 1) detail = normalizeText(paragraphs[0].textContent || "");
        if (!detail && title) detail = searchItemDetail(link, title);

        if (!title || !url || title.length < 3 || title.length > 180 || seen[url]) return;
        if (!topicishRoot && !/\btopics?\b/i.test(url + " " + title + " " + detail)) return;
        if (/^(home|health topics|topics|news|headlines|menu|search|more)$/i.test(title)) return;

        seen[url] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      if (items.length < 8) return;
      var score = items.length * 100 + (topicishRoot ? 1000 : 0);
      if (!best || score > best.score) best = { root: root, items: items, score: score };
    });

    if (!best) return null;
    var title = normalizeText(((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Topics");

    return listContentResult({
      title: title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: best.items,
      html: cleanClone(best.root).innerHTML,
      textContent: title + "\n" + listMarkdown(best.items)
    });
  }

  function customElementTileDataUrl(tile) {
    var raw = tile && tile.getAttribute("data-cmp-data-layer");
    var found = "";
    var data;
    if (!raw) return "";

    try {
      data = JSON.parse(raw);
      Object.keys(data).some(function(key) {
        var item = data[key] || {};
        found = item["xdm:linkURL"] || item.linkURL || item.url || "";
        return !!found;
      });
    } catch (_error) {
      found = "";
    }

    return found;
  }

  function institutionalCustomElementTileContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("gui-tile-list, [role='list']"));
    var best = null;
    var aemPage = !!document.querySelector(".aem-Grid, [class*='aem-GridColumn'], [data-cmp-data-layer]");

    roots.forEach(function(root) {
      var tiles = Array.prototype.slice.call(root.querySelectorAll("gui-tile, [class*='tile' i]"));
      var seen = {};
      var items = [];
      var customTileRoot = root.tagName && /-/.test(root.tagName.toLowerCase());

      tiles.forEach(function(tile) {
        if (items.length >= 120) return;

        var heading = tile.querySelector("gui-tile-heading, [heading-text], [class*='tile-heading' i]");
        var content = tile.querySelector("gui-tile-content, [content-text], [class*='tile-content' i]");
        var link = tile.querySelector("a[href]");
        var title = normalizeText((heading && heading.getAttribute("heading-text")) || (heading && heading.textContent) || tile.getAttribute("heading-text") || "");
        var detail = normalizeText((content && content.getAttribute("content-text")) || (content && content.textContent) || tile.getAttribute("content-text") || "");
        var href = (link && link.getAttribute("href")) || customElementTileDataUrl(tile);
        var url = absoluteUrl(href || "");
        var key = title + "|" + (url || "");

        if (!title || title.length < 3 || title.length > 180 || seen[key]) return;
        if (!detail && textLength(tile) < 20) return;

        seen[key] = true;
        items.push({ text: title, url: url || location.href, detail: detail });
      });

      if (items.length < 3) return;
      if (!aemPage && !customTileRoot && tiles.length < 4) return;

      var score = items.length * 100 + (customTileRoot ? 500 : 0) + (aemPage ? 500 : 0);
      if (!best || score > best.score) best = { root: root, items: items, score: score };
    });

    if (!best) return null;
    var title = normalizeText(((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Services");

    return listContentResult({
      title: title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: best.items,
      html: cleanClone(best.root).innerHTML,
      textContent: title + "\n" + listMarkdown(best.items)
    });
  }

  function institutionalPlatformContent(metadata) {
    return eurLexDocumentContent(metadata) ||
      governmentProgramMicrositeContent(metadata) ||
      europaServiceLandingContent(metadata) ||
      drupalInstitutionalContent(metadata) ||
      institutionalCustomElementTileContent(metadata) ||
      institutionalTopicCardListContent(metadata);
  }
