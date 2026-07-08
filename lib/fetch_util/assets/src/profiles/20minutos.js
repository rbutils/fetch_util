  function twentyMinutosLiveArticleContent(metadata) {
    if (!twentyMinutosLiveArticlePage()) return null;

    return liveblogSingleEntryContent(metadata, {
      entrySelector: "article.c-detail--mam__minute-container",
      titleSelector: [".c-detail--mam__live__title", "h2"],
      minTextLength: 350,
      rootBuilder: function(entry) {
        var body = entry.closest("div.c-detail__body");
        if (!body) return entry;

        var root = body.cloneNode(true);
        var first = root.querySelector("article.c-detail--mam__minute-container");
        root.querySelectorAll("article.c-detail--mam__minute-container").forEach(function(node) {
          if (node !== first) node.remove();
        });
        root.querySelectorAll("script, style, [class*='share' i], [class*='ad' i], [class*='newsletter' i], [class*='related' i]").forEach(function(node) {
          node.remove();
        });
        return root;
      }
    });
  }

  function twentyMinutosLiveArticlePage() {
    if (!hostMatches(/(^|\.)20minutos\.es$/i)) return false;
    return /-directo-/i.test(location.pathname || "") && !!document.querySelector("article.c-detail--mam__minute-container");
  }

  registerHostAwareProfile(true, twentyMinutosLiveArticleContent);
