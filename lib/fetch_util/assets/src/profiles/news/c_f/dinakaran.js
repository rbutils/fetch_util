  function dinakaranArticleContent(metadata) {
    if (!hostMatches(/(^|\.)dinakaran\.com$/i)) return null;

    var body = document.querySelector(".post-description") || document.querySelector(".article-main");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: metadata.title,
      byline: null,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".relArticle",
          ".article-list-scroll-section",
          ".side-widget",
          ".side-post-cntnt-right",
          ".main-post-cntnt-right",
          "[class*='related' i]",
          "[id*='related' i]",
          "[class*='recommend' i]",
          "[class*='share' i]",
          "[class*='newsletter' i]",
          "[class*='subscribe' i]",
          "[class*='advert' i]",
          "[class*='promo' i]",
          "[data-ad]"
        ].join(", "));

        root.querySelectorAll("div, section, article").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (!/^(related news|more stories|also read|more from)/i.test(text)) return;
          if (el.querySelectorAll("a[href]").length >= 2) el.remove();
        });
      }
    });
  }

  registerHostAwareProfile(/(^|\.)dinakaran\.com$/i, dinakaranArticleContent);
