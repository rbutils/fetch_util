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

  function legalConventionIndexContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll(".page-content .container, main .container, main, .content"));
    var best = null;

    roots.forEach(function(root) {
      var conventionLists = Array.prototype.slice.call(root.querySelectorAll("ul.arrows, ol.arrows, ul, ol")).filter(function(list) {
        var links = Array.prototype.slice.call(list.querySelectorAll("a[href]"));
        if (links.length < 4) return false;
        var conventionLinks = links.filter(function(link) {
          var text = normalizeText(link.textContent || "");
          var href = link.getAttribute("href") || "";
          return /\b(?:convention|protocol|principles?|instrument)\b/i.test(text) && /\b(?:conventions?|instruments?|full-text|specialised-sections)\b/i.test(href);
        });
        return conventionLinks.length >= Math.min(4, links.length);
      });
      var context = normalizeText([root.querySelector("h1, h2") && root.querySelector("h1, h2").textContent, root.textContent].join(" "));
      var score = textLength(root) + conventionLists.length * 1000;

      if (conventionLists.length < 2) return;
      if (!/\bConventions? and (?:other )?Instruments?\b/i.test(context) && !/\bCore Conventions?\b/i.test(context)) return;
      if (!best || score > best.score) best = { root: root, score: score };
    });

    if (!best) return null;

    return institutionalArticleResult(metadata, best.root, {
      docsLike: true,
      minText: 400,
      titleRoot: best.root,
      strip: function(clone) {
        removeAll(clone, COMMON_INSTITUTIONAL_CHROME_SELECTOR + ", [class*='breadcrumb' i], .navbar, [class*='nav' i], form");
      }
    });
  }
