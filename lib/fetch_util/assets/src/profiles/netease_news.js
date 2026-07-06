  function neteaseNewsArticleContent(metadata) {
    if (!neteaseNewsArticlePage()) return null;

    var body = neteaseNewsArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".post_title", "h1.post_main_icon", ".post_main h1", "h1"]) || metadata.title,
      byline: firstText([".post_info", ".post_time_source", ".post_source", ".post_author"]) || metadata.byline,
      minTextLength: 80,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".post_top_tie_count",
          ".post_top_share",
          ".post_share",
          ".post_recommends",
          ".post_recommend",
          ".post_recommend_ad",
          ".post_statement",
          ".post_btmshare",
          ".post_comment",
          ".tie-area",
          "#tie",
          "#tieArea",
          "[class*='recommend' i]",
          "[class*='share' i]",
          "[class*='comment' i]",
          "[id*='comment' i]"
        ].join(", "));

        root.querySelectorAll("p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 120) return;
          if (/^(相关推荐|热点推荐|分享至|跟贴|举报|本文来源[:：]|责任编辑[:：]|打开网易新闻|下载网易新闻客户端)/i.test(text)) el.remove();
        });
      },
      postProcessMarkdown: function(markdown) {
        return markdown.split("\n").filter(function(line) {
          var text = normalizeText(line.replace(/^#+\s*/, ""));
          return !/^(相关推荐|热点推荐|分享至|跟贴|举报|本文来源[:：]|责任编辑[:：]|打开网易新闻|下载网易新闻客户端)/i.test(text);
        }).join("\n").trim();
      },
      extra: { docsLike: true }
    });
  }

  function neteaseNewsArticlePage() {
    if (!hostMatches(/(^|\.)163\.com$/)) return false;
    if (!/\/(?:news|dy|ent|sports|money|tech|auto|war|gov|local)\/article\/[A-Z0-9]+/i.test(location.pathname || "")) return false;
    return !!neteaseNewsArticleBody();
  }

  function neteaseNewsArticleBody() {
    return document.querySelector(".post_body") ||
      document.querySelector(".post_content .post_body") ||
      document.querySelector("#endText") ||
      document.querySelector(".article-body") ||
      document.querySelector(".post_text") ||
      document.querySelector(".post_content");
  }

  var neteaseNewsBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return neteaseNewsArticleContent(metadata) || neteaseNewsBaseHostAwareContent(metadata, pageText);
  };
