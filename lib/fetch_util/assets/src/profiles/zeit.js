  function zeitArticleContent(metadata) {
    if (!hostMatches(/(^|\.)zeit\.de$/)) return null;

    var article = document.querySelector("article.article") || document.querySelector("article#js-article");
    var body = article && (article.querySelector(".article-body") || article.querySelector(".article-page"));
    if (!article || !body) return null;
    if (!body.querySelector(".paragraph, p")) return null;

    return profileArticleContent(metadata, article, {
      title: firstText([".article-heading", ".article-heading__headline", "h1.article-heading", "h1"]) || metadata.title,
      byline: firstText([".article-meta .authors", ".article__authors", "[rel='author']"]) || metadata.byline,
      minTextLength: 500,
      rewriteRoot: function(root) {
        root.querySelectorAll([
          ".iqdcontainer",
          ".summy",
          ".summary__feedback",
          ".newsletter",
          "[class*='newsletter' i]",
          "[class*='topicbox' i]",
          "[class*='recommend' i]",
          "[class*='related' i]",
          "[data-ct-area*='comments' i]",
          "[data-ct-area*='sharing' i]",
          "[data-ct-area*='recommend' i]",
          "[aria-label*='Newsletter' i]",
          "[aria-label*='Mehr zum Thema' i]",
          "[aria-label*='Seitennavigation' i]",
          "[aria-label*='Schlagwörter' i]",
          "aside",
          "nav"
        ].join(", ")).forEach(function(el) {
          el.remove();
        });
      }
    });
  }
