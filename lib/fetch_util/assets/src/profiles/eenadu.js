  function eenaduArticleRoot() {
    if (!hostMatches(/(^|\.)eenadu\.net$/)) return null;

    var fullstory = document.querySelector(".col-mid.general-fullstory") ||
      document.querySelector(".two-col-left-block.fullstory") ||
      document.querySelector(".telugu_uni_body.fullstory") ||
      document.querySelector("div.article-content, .story-content, .news-content, div.telugu-content");
    if (!fullstory) return null;

    var titleNode = fullstory.querySelector(".center h1, h1, .title");
    var bodyNode = fullstory.querySelector(".text-justify") ||
      fullstory.querySelector(".article-content, .story-content, .news-content, .telugu-content");
    if (!titleNode || !bodyNode) return null;

    var root = document.createElement("article");
    root.appendChild(safeDeepClone(titleNode, document));

    var content = safeDeepClone(bodyNode, document);
    if (!content) return null;

    removeAll(content, [
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

    root.appendChild(content);
    return normalizeText(root.textContent || "").length >= 180 ? root : null;
  }

  function eenaduArticleContent(metadata) {
    var root = eenaduArticleRoot();
    if (!root) return null;

    return profileArticleContent(metadata, root, {
      title: firstText([".col-mid.general-fullstory h1", ".two-col-left-block.fullstory h1", ".telugu_uni_body.fullstory h1", ".title", "h1"]) || metadata.title,
      minTextLength: 180,
      cleanupMarkdown: true,
      extra: { docsLike: true }
    });
  }

  var eenaduBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return eenaduArticleContent(metadata) || eenaduBaseHostAwareContent(metadata, pageText);
  };
