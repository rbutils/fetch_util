  function oxuContent(metadata) {
    if (!hostMatches(/(^|\.)oxu\.az$/)) return null;

    var body = document.querySelector(".post-detail");
    if (!body || !body.querySelector(".post-detail-content-inner, .post-detail-title h1, .post-detail-meta")) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".post-detail-title h1", "h1"]) || (metadata && metadata.title),
      minTextLength: 250,
      prependTitle: false,
      cleanupRoot: false,
      cleanupMarkdown: false,
      rewriteRoot: function(root) {
        removeAll(root, "button, script, style, .post-detail-actions, .m-share-block, .ad, .row.mt-3");
      }
    });
  }

  registerHostAwareProfile(true, oxuContent);
