var bloggerArticleContent = simpleArticleProfile({
  body: function() {
    if (!document.querySelector("meta[name='generator'][content*='Blogger' i], body[class*='blog' i] .blog-post, body[class*='blog' i] .post-body, body[class*='blog' i] .post-title, iframe#navbar-iframe, .widget.Blog")) return null;
    var body = document.querySelector(".post-body") || document.querySelector("div.post-body") || document.querySelector(".entry-content");
    if (!body) return null;
    return body.closest(".blog-post") || body.closest("article") || body;
  },
  titleSelectors: [".post-title", "h3.post-title"],
  minBodyTextLength: 180,
  removalSelectors: [
    ".post-footer",
    ".post-feeds",
    ".post-share-buttons",
    ".post-icons",
    ".post-author",
    ".post-header",
    ".blog-pager",
    ".comments",
    ".comment",
    ".comment-thread",
    ".comments-content",
    ".date-header",
    ".date-outer",
    ".date-posts",
    ".post-timestamp",
    ".widget",
    ".widget.Blog",
    "[class*='widget' i]",
    "iframe#navbar-iframe"
  ],
  rewriteRoot: function(root) {
    root.querySelectorAll("footer, nav, time, .date, [class*='date' i], [class*='comment' i], [class*='footer' i]").forEach(function(el) {
      el.remove();
    });
  }
});

registerHostAwareProfile(true, bloggerArticleContent);
