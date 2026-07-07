  function newsitGrArticleContent(metadata) {
    if (!newsitGrArticlePage()) return null;
    if (metadata) metadata.language = "";

    var body = newsitGrArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".entry-title", "article h1", "h1"]) || metadata.title,
      byline: metadata.byline || firstText(["[rel='author']", ".author", "[class*='author' i]"]),
      minTextLength: 180,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".advert-block",
          ".share-inside-the-content",
          ".share-menu",
          ".sticky-container",
          "[id*='div-gpt-ad' i]",
          "[class*='related' i]",
          "[class*='recommend' i]",
          "[class*='newsletter' i]",
          "[class*='google' i]",
          "figure",
          "blockquote.twitter-tweet",
          "[data-twitter-extracted]",
          "iframe",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, span, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 220) return;
          if (/^(διαφήμιση|ακολουθήστε το newsit\.gr|προσθήκη του newsit\.gr ως προτεινόμενη πηγή στην google)$/i.test(text)) el.remove();
        });

        root.querySelectorAll("a").forEach(function(link) {
          link.replaceWith(document.createTextNode(link.textContent || ""));
        });
      }
    });
  }

  function newsitGrArticlePage() {
    if (!hostMatches(/(^|\.)newsit\.gr$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector("article[id^='post-'] .inside-article .entry-content section, article[id^='post-'] .entry-content section");
  }

  function newsitGrArticleBody() {
    var section = document.querySelector("article[id^='post-'] .inside-article .entry-content section") ||
      document.querySelector("article[id^='post-'] .entry-content section") ||
      document.querySelector("article .entry-content section") ||
      document.querySelector(".entry-content section");
    if (!section) return null;

    var root = document.createElement("article");
    var excerpt = document.querySelector(".article-excerpt");
    if (excerpt && normalizeText(excerpt.textContent || "")) root.appendChild(safeDeepClone(excerpt, document));
    root.appendChild(safeDeepClone(section, document));
    return root;
  }

  var newsitGrBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return newsitGrArticleContent(metadata) || newsitGrBaseHostAwareContent(metadata, pageText);
  };
