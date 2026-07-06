  function amebaBlogArticleContent(metadata) {
    if (!amebaBlogArticlePage()) return null;

    var body = amebaBlogArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([
        ".skinArticleTitle",
        ".skin-entryTitle",
        "article.skin-entry h1",
        "h1"
      ]) || metadata.title,
      byline: firstText([
        ".skin-entryAuthor",
        ".skin-entryThemes",
        "[rel='author']"
      ]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[data-toc]",
          ".js-ad",
          ".ad",
          ".adsbygoogle",
          ".skin-ad",
          ".skin-entryFooter",
          ".entry-share",
          ".js-entryFooter",
          ".js-commentArea",
          ".commentArea",
          ".blogCard",
          ".ogpCard"
        ].join(", "));

        root.querySelectorAll("img").forEach(function(img) {
          var src = img.getAttribute("src") || "";
          if (/\/blog\/ucs\/img\/char\//i.test(src)) img.remove();
        });

        root.querySelectorAll("a[href^='#']").forEach(function(link) {
          var text = normalizeText(link.textContent || "");
          if (!text || /^目次を/.test(text)) link.remove();
        });
      }
    });
  }

  function amebaBlogArticlePage() {
    if (!hostMatches(/(^|\.)ameblo\.jp$/)) return false;
    if (!/\/entry-\d+\.html(?:$|[?#])/i.test(location.pathname || "")) return false;
    return !!amebaBlogArticleBody();
  }

  function amebaBlogArticleBody() {
    return document.querySelector("#entryBody") ||
      document.querySelector(".article-body") ||
      document.querySelector(".skinArticleBodyEx") ||
      document.querySelector(".skinArticleBody") ||
      document.querySelector(".entry-text") ||
      document.querySelector("article.entry") ||
      document.querySelector("article.skin-entry .skin-entryBody");
  }

  var amebaBlogBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return amebaBlogArticleContent(metadata) || amebaBlogBaseHostAwareContent(metadata, pageText);
  };
