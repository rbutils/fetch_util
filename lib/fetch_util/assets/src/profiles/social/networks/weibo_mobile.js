  function weiboMobileContent(metadata) {
    if (!hostMatches(/^m\.weibo\.cn$/)) return null;
    if (!/^\/status\/[^/]+\/?$/i.test(location.pathname || "")) return null;

    var textNode = weiboMobileStatusTextNode();
    if (!textNode) return null;

    var root = weiboMobileStatusRoot(textNode, metadata);
    if (!root) return null;

    var content = profileArticleContent(metadata, root, {
      title: weiboMobileStatusTitle(root, metadata),
      byline: firstText([".weibo-top .m-text-cut", ".weibo-top h3", "header .m-text-cut"]) || metadata.byline,
      minTextLength: 40,
      rewriteRoot: function(clone) {
        removeAll(clone, [
          ".m-followBtn",
          ".m-add-box",
          ".weibo-btn",
          ".toolbar",
          ".card-act",
          ".lite-page-tab",
          ".comments",
          ".comment",
          ".card-main",
          "[class*='comment']",
          "svg"
        ].join(", "));

        clone.querySelectorAll("p, div, span, h4").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(关注|转发\d*|评论\d*|赞\d*|\d{2}:\d{2})$/i.test(text)) el.remove();
        });
      },
      validateMarkdown: function(markdown) {
        return !/\n####\s+[^\n]+\n\n###\s+/.test(markdown);
      },
      extra: { docsLike: true }
    });
    if (!content) return null;

    var profileLink = document.querySelector(".weibo-top a[href^='/profile/']");
    var handle = profileLink && profileLink.getAttribute("href").split("/").filter(Boolean)[1];
    content.contentType = "social";
    content.socialKind = "post";
    content.platform = "Weibo";
    content.handle = handle || null;
    return content;
  }

  function weiboMobileStatusTextNode() {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(
      ".card-wrap .weibo-og .weibo-text, .card-wrap div.weibo-text, div.weibo-text, .weibo-text"
    ));

    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.closest(".card-main, .comments, .comment, [class*='comment']")) continue;
      var text = normalizeText(node.textContent || "");
      if (text.length >= 20) return node;
    }

    return null;
  }

  function weiboMobileStatusRoot(textNode, metadata) {
    var root = document.createElement("article");
    root.setAttribute("data-fetchutil-profile", "weibo-mobile");

    var header = document.querySelector(".card-wrap .weibo-top") || document.querySelector("header.weibo-top");
    if (header) root.appendChild(safeDeepClone(header, document));

    var bodyCard = textNode.closest(".card-wrap") || textNode.parentElement;
    var body = document.createElement("section");
    body.appendChild(safeDeepClone(textNode, document));

    if (bodyCard) {
      var media = bodyCard.querySelector(".weibo-media, .weibo-media-wraps, .card-video, video, .m-auto-list");
      if (media) body.appendChild(safeDeepClone(media, document));
    }

    root.appendChild(body);

    return root;
  }

  function weiboMobileStatusTitle(root, metadata) {
    var author = firstText([".weibo-top .m-text-cut", ".weibo-top h3", "header .m-text-cut"]);
    if (author && !/^(关注|微博正文)$/i.test(author)) return author + " - 微博正文";
    return (metadata && metadata.title && metadata.title !== "微博") ? metadata.title : "微博正文";
  }

  registerHostAwareProfile(true, weiboMobileContent);
