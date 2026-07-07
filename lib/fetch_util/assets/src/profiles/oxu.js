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

        var share = document.createElement("p");
        share.textContent = "Xəbər maraqlı gəlib? Sosial şəbəkələrdə paylaşın Facebook Telegram X oxu.az/1078092";
        root.appendChild(share);

        var shareLink = document.createElement("p");
        shareLink.textContent = "Paylaş linki: https://oxu.az/1078092";
        root.appendChild(shareLink);
      }
    });
  }

  registerHostAwareProfile(true, oxuContent);
