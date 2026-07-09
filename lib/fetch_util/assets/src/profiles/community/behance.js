  function behanceContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)behance\.net$/)) return null;

    var items = [];
    var seen = {};

    document.querySelectorAll("a[href*='/gallery/'], a[href*='/project/']").forEach(function(link) {
      if (items.length >= 12) return;

      var href = link.getAttribute("href");
      if (!href) return;

      var url = absoluteUrl(href);
      try {
        var parsed = new URL(url, location.href);
        parsed.searchParams.delete("tracking_source");
        parsed.searchParams.delete("l");
        url = parsed.toString();
      } catch (_error) {
      }

      var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (!title) return;

      var key = title + "|" + url;
      if (seen[key]) return;
      seen[key] = true;

      var container = link.closest("article, li, div, section") || link.parentElement;
      items.push({ text: title, url: url, detail: searchItemDetail(container, title) });
    });

    if (items.length >= 4) {
      var query = safeDecodeURI((location.pathname || "").split("/").filter(Boolean).slice(-1)[0] || "").replace(/[-_+]+/g, " ");
      query = normalizeText(query);

      return {
        title: query ? "Behance projects for " + query : (metadata.title || document.title),
        byline: null,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || "Behance",
        publishedTime: null,
        html: "",
        textContent: listMarkdown(items),
        markdown: listMarkdown(items),
        readerMode: false,
        contentType: "list",
        hostAware: true
      };
    }

    if (!/(cookie settings|measure performance|personalize advertising|adobe and our partners)/i.test(pageText || "")) return null;

    var title = normalizeText((metadata.title || document.title).replace(/\s*::\s*Photos, videos, logos, illustrations and branding$/i, "")) || metadata.title || "Behance page";
    var description = metadata.excerpt || "This Behance page is showing Adobe cookie settings instead of the original content.";
    var details = ["Access notice: Adobe cookie settings prompt"];
    if (/^\/search\//.test(location.pathname)) details.push("Requested view: Behance search results");

    return articleContentFromParts({
      title: title,
      description: description,
      details: details,
      siteName: metadata.siteName || "Behance"
    });
  }
