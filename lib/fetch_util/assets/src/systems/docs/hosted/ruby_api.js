  function rubyApiIndexContent(metadata, title) {
    var seen = {};
    var items = [];

    document.querySelectorAll("a[href*='/o/']").forEach(function(link) {
      if (items.length >= 12) return;

      var href = absoluteUrl(link.getAttribute("href"));
      var label = normalizeText(link.textContent);
      if (!href || !/\/\d+(?:\.\d+)?\/o\//.test(href) || !/^read more$/i.test(label) || seen[href]) return;

      var card = link.parentElement;
      while (card && card !== document.body) {
        var heading = normalizeText((card.querySelector("h2, h3") || {}).textContent || "");
        var description = firstRootText(card, ["p"]);
        if (heading && description) {
          seen[href] = true;
          items.push({ text: heading, url: href, detail: description });
          return;
        }
        card = card.parentElement;
      }
    });

    if (items.length < 3) return null;

    var markdown = ["# " + title, metadata.excerpt, listMarkdown(items)].filter(Boolean).join("\n\n");
    var result = listContentResult({
      title: title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      markdown: markdown,
      textContent: normalizeText(markdown)
    });
    result.byline = metadata.byline;
    result.publishedTime = metadata.publishedTime;
    return result;
  }

  function rubyApiContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)rubyapi\.org$/) && !/ruby api/i.test(signature)) return null;

    var title = normalizeText((metadata.title || document.title).replace(/\s*\|\s*Ruby API.*$/i, "")) || "Ruby API";
    if (location.pathname === "/" || /^\/\d+(?:\.\d+)?\/?$/.test(location.pathname)) return rubyApiIndexContent(metadata, title);

    return docsContentBySelectors(metadata, ["main", ".ruby-documentation"], {
      titleSelectors: ["main h1", ".ruby-documentation h1"],
      fallbackTitle: title,
      rewriteRoot: function(root) {
        root.querySelectorAll("form, button").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "h2, h3, p, div, span", /^(type signatures|preview)$/i);
      }
    });
  }
