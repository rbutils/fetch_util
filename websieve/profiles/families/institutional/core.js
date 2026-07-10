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
