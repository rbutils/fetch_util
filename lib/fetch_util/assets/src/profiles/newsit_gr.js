  var newsitGrArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)newsit\.gr$/,
    homepagePath: /^\/?$/,
    body: newsitGrArticleBody,
    titleSelectors: [".entry-title", "article h1", "h1"],
    byline: function(metadata) {
      return (metadata && metadata.byline) || firstText(["[rel='author']", ".author", "[class*='author' i]"]);
    },
    removalSelectors: [
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
    ],
    minBodyTextLength: 180,
    rewriteRoot: function(root) {
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

  function newsitGrArticlePage() {
    return !!newsitGrArticleContent();
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

  registerHostAwareProfile(true, newsitGrArticleContent);