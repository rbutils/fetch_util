  function tovimaGrArticleContent(metadata) {
    if (!hostMatches(/(^|\.)tovima\.gr$/)) return null;
    if (homepageRootPath()) return null;

    var body = document.querySelector(".post-body.main-content.article-wrapper") ||
      document.querySelector(".post-body.main-content") ||
      document.querySelector("[itemprop='articleBody']");
    if (!body) return null;
    if (metadata) metadata.language = "";

    return profileArticleContent(metadata, body, {
      title: firstText(["article h1", "main h1", "h1"]) || (metadata && metadata.title),
      byline: (metadata && metadata.byline) || firstText(["[rel='author']", ".author", ".post-author"]),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".google-preferred-source",
          ".whsk_parent__div",
          ".wrap_article_banner",
          "[id^='banner-']",
          "[id*='banner' i]",
          "[id*='ad-' i]",
          "[class*='advert' i]",
          "[class*='related' i]",
          "[class*='share' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, span, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^κάντε\s+to\s+bhma\s+προτιμώμενη\s+πηγή$/i.test(text)) el.remove();
          if (/googletag\.cmd\.push|google-preferred-source/i.test(text)) el.remove();
        });

        root.querySelectorAll("a").forEach(function(link) {
          link.replaceWith(document.createTextNode(" " + (link.textContent || "") + " "));
        });
      }
    });
  }

  var tovimaGrBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return tovimaGrArticleContent(metadata) || tovimaGrBaseHostAwareContent(metadata, pageText);
  };
