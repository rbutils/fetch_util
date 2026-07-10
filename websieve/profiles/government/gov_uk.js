  function govUkGuidanceContent(metadata) {
    if (!hostMatches(/(^|\.)gov\.uk$/i)) return null;
    if (!/^\/guidance\//i.test(location.pathname || "")) return null;

    var body = document.querySelector(".gem-c-contents-list-with-body") || document.querySelector(".gem-c-govspeak .govspeak");
    if (!body || textLength(body) < 500) return null;
    var contentsMarkdown = govUkContentsMarkdown(body);

    return profileHtmlContent(metadata, body, {
      title: firstText([".gem-c-heading__text", "main h1", "h1"]) || metadata.title || document.title,
      byline: function() { return metadataListValue(document, "From") || metadata.byline || null; },
      publishedTime: metadata.publishedTime || firstText(["meta[name='govuk:first-published-at']"], "content"),
      siteName: metadata.siteName || "GOV.UK",
      minTextLength: 500,
      cleanupRoot: false,
      rewriteRoot: function(clone) {
        clone.querySelectorAll("nav.gem-c-contents-list, nav[aria-label='Contents']").forEach(function(nav) {
          var div = document.createElement("div");
          Array.prototype.slice.call(nav.childNodes).forEach(function(child) { div.appendChild(child); });
          nav.parentNode.replaceChild(div, nav);
        });
        clone.querySelectorAll([
          "script",
          "style",
          "form",
          ".gem-c-print-link",
          ".gem-c-single-page-notification-button",
          ".published-dates-button-group",
          "[data-sticky-element]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      },
      postProcessMarkdown: function(markdown, root) {
        if (/^##\s+Contents\b/m.test(markdown)) return markdown;
        if (contentsMarkdown) return contentsMarkdown + "\n\n" + markdown;

        var links = Array.prototype.slice.call(root.querySelectorAll(".gem-c-contents-list a, [aria-label='Contents'] a, a[href^='#']"));
        var items = links.map(function(link) {
          var text = normalizeText(link.textContent || "");
          var href = link.getAttribute("href") || "";
          return text && /^#/.test(href) ? "- [" + text + "](" + href + ")" : null;
        }).filter(Boolean);

        return items.length ? "## Contents\n\n" + items.join("\n") + "\n\n" + markdown : markdown;
      },
      validateMarkdown: function(markdown, text) {
        return /^#\s+/m.test(markdown) || text.length >= 500;
      }
    });
  }

  function govUkContentsMarkdown(root) {
    var links = Array.prototype.slice.call((root || document).querySelectorAll(".gem-c-contents-list a, [aria-label='Contents'] a, a[href^='#']"));
    var items = links.map(function(link) {
      var text = normalizeText(link.textContent || "");
      var href = link.getAttribute("href") || "";
      return text && /^#/.test(href) ? "- [" + text + "](" + href + ")" : null;
    }).filter(Boolean);

    return items.length ? "## Contents\n\n" + items.join("\n") : null;
  }
