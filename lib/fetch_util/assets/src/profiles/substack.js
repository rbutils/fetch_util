  function substackPostPage(metadata) {
    if (!/^\/p\//i.test(location.pathname || "")) return false;
    if (!document.querySelector(".available-content .body.markup, .post-content .body.markup, article.post .body.markup")) return false;

    var signature = normalizeText([
      metadata && metadata.title,
      metadata && metadata.siteName,
      document.title,
      firstText([".post-title", "h1.post-title", "article.post h1"]),
      firstText(["meta[property='og:image']", "meta[name='twitter:image']"], "content")
    ].join(" "));

    return /\bsubstack\b|substackcdn\.com|substack-post-media/i.test(signature) ||
      !!document.querySelector("article.newsletter-post.post, .post-header .post-title");
  }

  function substackContent(metadata) {
    if (!substackPostPage(metadata)) return null;

    var node = document.querySelector(".available-content .body.markup") ||
      document.querySelector(".post-content .body.markup") ||
      document.querySelector("article.post .body.markup") ||
      document.querySelector(".available-content") ||
      document.querySelector(".post-content");
    if (!node) return null;

    var title = firstText([".post-title", "h1.post-title", "article.post h1", "h1"]) || metadata.title;
    return profileArticleContent(metadata, node, {
      title: title,
      byline: firstText([".byline-names", ".post-meta .profile-hover-card-target", ".post-header a[href*='/profile/']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        root.querySelectorAll(".subscription-widget-wrap, .subscribe-widget, .paywall, .comment-list, [class*='comment'], [class*='subscribe'], [role='dialog']").forEach(function(el) {
          el.remove();
        });
      }
    });
  }
