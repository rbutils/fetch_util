  function indexHuArticleContent(metadata) {
    if (!indexHuArticlePage()) return null;

    var body = indexHuArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: indexHuArticleTitle(metadata),
      byline: firstText([".current-post .author", ".current-post [class*='author' i]", "[class*='szerzo' i]"]) || metadata.byline,
      minTextLength: 180,
      publishedTime: indexHuPublishedTime(metadata),
      rewriteRoot: function(root) {
        removeAll(root, [
          ".new-posts",
          ".next-post",
          ".previous-post",
          ".related",
          ".ajanlo",
          ".share",
          ".social",
          ".comments",
          ".comment",
          "[class*='advert' i]",
          "[class*='hirdet' i]",
          "[id*='ad' i]"
        ].join(", "));

        removeAll(root, "h1, h2, h3.title");

        root.querySelectorAll("p, div, span, li").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^új poszt érkezett/i.test(text)) el.remove();
          if (/^(hirdetés|megosztás|kommentek|kapcsolódó)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function indexHuArticlePage() {
    if (!hostMatches(/(^|\.)index\.hu$/)) return false;
    if (/^\/mindekozben\/poszt\//i.test(location.pathname || "")) return !!indexHuArticleBody();
    if (!/(\/\d{4}\/\d{2}\/\d{2}\/|\.html(?:$|[?#]))/i.test(location.pathname || "")) return false;
    return !!indexHuArticleBody();
  }

  function indexHuArticleBody() {
    if (/^\/mindekozben\/poszt\//i.test(location.pathname || "")) {
      var currentPost = document.querySelector(".current-post .mindenkozben_post_content.content") ||
        document.querySelector(".current-post .post .content") ||
        document.querySelector(".current-post .post");
      if (currentPost) return currentPost;
    }

    return document.querySelector(".article-body") ||
      document.querySelector(".post-body") ||
      document.querySelector("#article") ||
      document.querySelector("article [itemprop='articleBody']") ||
      document.querySelector("article .content") ||
      document.querySelector("main article");
  }

  function indexHuArticleTitle(metadata) {
    return firstText([
      ".current-post .mindenkozben_post_content.content h1",
      ".current-post .mindenkozben_post_content.content h2",
      ".current-post .mindenkozben_post_content.content h3.title",
      ".current-post .post h1",
      ".current-post .post h2",
      ".current-post .post h3.title",
      "article h1",
      "h1",
      ".title"
    ]) || metadata.title;
  }

  function indexHuPublishedTime(metadata) {
    var pathDate = (location.pathname || "").match(/\/(\d{4})\/(\d{2})\/(\d{2})\//);
    if (pathDate) return pathDate[1] + "-" + pathDate[2] + "-" + pathDate[3] + "T00:00:00+02:00";
    return metadata.publishedTime;
  }

  registerHostAwareProfile(true, indexHuArticleContent);