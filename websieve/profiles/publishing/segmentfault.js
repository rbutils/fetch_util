  function segmentfaultArticleContent(metadata) {
    if (!segmentfaultArticlePage()) return null;

    var body = segmentfaultArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["main h1", ".article-title", "h1"]) || metadata.title,
      byline: firstText([".article-author", ".author", "a[href^='/u/']"]) || metadata.byline,
      minTextLength: 120,
      rewriteRoot: function(root) {
        root.querySelectorAll(".widget-vote, .widget-share, .article-operation, .article-copyright, .comment, .comments, [class*='share' i], [class*='comment' i]").forEach(function(el) {
          el.remove();
        });
      }
    });
  }

  function segmentfaultArticlePage() {
    if (!hostMatches(/(^|\.)segmentfault\.com$/)) return false;
    if (!/^\/a\/\d+/.test(location.pathname || "")) return false;
    return !!segmentfaultArticleBody();
  }

  function segmentfaultArticleBody() {
    return document.querySelector("article.article-content") ||
      document.querySelector(".article-content") ||
      document.querySelector("article.article") ||
      document.querySelector(".content-body") ||
      document.querySelector("#articleContent");
  }

  registerHostAwareProfile(true, segmentfaultArticleContent);