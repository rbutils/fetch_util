  var neteaseNewsArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)163\.com$/,
    pathPattern: /\/(?:news|dy|ent|sports|money|tech|auto|war|gov|local)\/article\/[A-Z0-9]+/i,
    bodySelectors: [
      ".post_body",
      ".post_content .post_body",
      "#endText",
      ".article-body",
      ".post_text",
      ".post_content"
    ],
    titleSelectors: [".post_title", "h1.post_main_icon", ".post_main h1", "h1"],
    bylineSelectors: [".post_info", ".post_time_source", ".post_source", ".post_author"],
    removalSelectors: [
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
    ],
    removalTextPatterns: [
      /^(相关推荐|热点推荐|分享至|跟贴|举报|本文来源[:：]|责任编辑[:：]|打开网易新闻|下载网易新闻客户端)/i
    ],
    minBodyTextLength: 80,
    extra: { docsLike: true }
  });

  registerHostAwareProfile(true, neteaseNewsArticleContent);
