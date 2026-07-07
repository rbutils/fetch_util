  function eenaduArticleRoot() {
    if (!hostMatches(/(^|\.)eenadu\.net$/)) return null;

    var fullstory = document.querySelector(".col-mid.general-fullstory") ||
      document.querySelector(".two-col-left-block.fullstory") ||
      document.querySelector(".telugu_uni_body.fullstory") ||
      document.querySelector("div.article-content, .story-content, .news-content, div.telugu-content");
    if (!fullstory) return null;

    return composeProfileArticleRoot({
      scope: fullstory,
      titleSelectors: [".center h1", "h1", ".title"],
      bodySelectors: [".text-justify", ".article-content", ".story-content", ".news-content", ".telugu-content"],
      minTextLength: 180
    });
  }

  function eenaduArticleContent(metadata) {
    var root = eenaduArticleRoot();
    if (!root) return null;

    return profileArticleContent(metadata, root, {
      title: firstText([".col-mid.general-fullstory h1", ".two-col-left-block.fullstory h1", ".telugu_uni_body.fullstory h1", ".title", "h1"]) || metadata.title,
      minTextLength: 180,
      cleanupMarkdown: true,
      rewriteRoot: function(cleanRoot) {
        removeAll(cleanRoot, [
          "[class*='ext-link']",
          "[class*='font-size']",
          ".gg-pref",
          ".sshare-c",
          ".whats-c",
          ".twt-c",
          ".fb-c",
          ".lnk-c",
          "[class*='pub-sec']",
          "[class*='mr-cls']",
          "div[data-nosnippet]",
          ".tags"
        ].join(", "));
      },
      extra: { docsLike: true }
    });
  }

  registerHostAwareProfile(true, eenaduArticleContent);
