  function csdnContent(metadata) {
    if (!hostMatches(/(^|\.)blog\.csdn\.net$/)) return null;
    if (!/\/article\/details\/\d+/i.test(location.pathname || "")) return null;

    var node = document.querySelector("#article_content, .article_content, #content_views");
    if (node && textLength(node) >= 80) {
      return profileArticleContent(metadata, node, {
        title: firstText(["#article-tit", ".title-box h1", ".article-title-box h1", "h1.title-article", "h1"]),
        byline: firstText([".follow-nickName", ".blog-name", ".article-bar-top .name", "a[href^='https://blog.csdn.net/']"]),
        publishedTime: firstText([".time", ".bar-content .time", "time"], "datetime") || metadata.publishedTime,
        minTextLength: 80,
        rewriteRoot: function(root) {
          root.querySelectorAll(".hide-article-box, .readall_box, .article-copyright, .blog-footer-bottom, .recommend-box, .recommend-right, .more-toolbox, .toolbox-list, .csdn-side-toolbar, [class*='comment'], [class*='recommend'], [class*='toolbar'], [class*='share']").forEach(function(el) {
            el.remove();
          });
        },
        siteName: "CSDN"
      });
    }

    var title = firstText(["#article-tit", ".title-box h1", ".article-title-box h1", "h1.title-article", "h1"]) || normalizeText(metadata && metadata.title);
    var description = normalizeText(metadata && metadata.excerpt);
    if (!title && !description) return null;

    return articleContentFromParts({
      title: title,
      byline: metadata && metadata.byline,
      publishedTime: metadata && metadata.publishedTime,
      description: "CSDN article details page returned only public metadata in this browser session." + (description ? " " + description : ""),
      siteName: "CSDN",
      hostAware: true,
      contentType: "article"
    });
  }

  function registerCsdnProfiles() {
    registerHostAwareProfile(true, csdnContent);
  }
