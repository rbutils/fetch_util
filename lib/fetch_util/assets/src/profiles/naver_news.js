  var naverNewsArticleContent = simpleArticleProfile({
    hostPattern: /^(?:n\.)?news\.naver\.com$/,
    pathPattern: /^\/article\/\d+\/\d+/i,
    bodySelectors: [
      "#dic_area",
      "#newsctArticle article",
      "#newsct_article article",
      ".newsct_article article",
      "#newsctArticle",
      "#newsct_article",
      ".newsct_article",
      "#articleBody",
      ".go_news_box",
      "#artcBody"
    ],
    titleSelectors: [
      ".media_end_head_title",
      "#title_area",
      "#articleTitle",
      "h1"
    ],
    bylineSelectors: [
      ".media_end_head_journalist_name",
      ".media_end_head_info_datestamp_bunch",
      ".journalistcard_summary_name"
    ],
    removalSelectors: [
      ".media_end_categorize",
      ".media_end_linked_more",
      ".media_end_linked_more_point",
      ".media_end_recommend",
      ".media_end_recommend_more",
      ".media_end_series",
      ".media_end_sponsor",
      ".media_end_tail",
      ".media_end_tool",
      ".media_end_head_autosummary",
      ".media_end_head_fontsize",
      ".media_end_head_share",
      ".u_likeit",
      ".u_cbox",
      ".rankingnews",
      ".section_subject",
      ".promotion",
      ".ad_area",
      ".end_ad",
      ".vod_area",
      ".video_area",
      "[class*='comment' i]",
      "[class*='share' i]",
      "[id*='comment' i]",
      "[data-module='moreNews']"
    ],
    removalTextPatterns: [
      /^(기사제보|뉴스 구독|구독|좋아요|공유|댓글|본문 듣기|텍스트 음성 변환 서비스|무단 전재|재배포 금지|Copyright)/i
    ],
    minBodyTextLength: 60
  });

  registerHostAwareProfile(true, naverNewsArticleContent);
