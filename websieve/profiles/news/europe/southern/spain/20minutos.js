  function twentyMinutosLiveArticleContent(metadata) {
    if (!twentyMinutosLiveArticlePage()) return null;

    var timeline = document.querySelector("div.c-detail--mam__live");
    var body = timeline && timeline.closest("div.c-detail__body");
    if (!body) return null;

    var root = safeDeepClone(body, document);
    removeAll(root, "[hidden], [aria-hidden='true'], [style*='display: none']");

    return profileArticleContent(metadata, root, {
      title: metadata.title,
      byline: metadata.byline,
      publishedTime: metadata.publishedTime,
      minTextLength: 350,
      cloneRoot: false,
      extra: function() {
        return { contentFormat: "liveblog" };
      },
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, [
          "script",
          "style",
          ".c-detail--mam__refresh-button",
          "#mam-show-more-button",
          ".c-ads",
          "[class*='share' i]",
          "[class*='newsletter' i]",
          "[class*='related' i]"
        ].join(", "));
      }
    });
  }

  function twentyMinutosLiveArticlePage() {
    if (!hostMatches(/(^|\.)20minutos\.es$/i)) return false;
    return /-directo-/i.test(location.pathname || "") && !!document.querySelector("article.c-detail--mam__minute-container");
  }

  registerHostAwareProfile(true, twentyMinutosLiveArticleContent);
