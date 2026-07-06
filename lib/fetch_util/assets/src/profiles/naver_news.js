  function naverNewsArticleContent(metadata) {
    if (!naverNewsArticlePage()) return null;

    var body = naverNewsArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([
        ".media_end_head_title",
        "#title_area",
        "#articleTitle",
        "h1"
      ]) || metadata.title,
      byline: firstText([
        ".media_end_head_journalist_name",
        ".media_end_head_info_datestamp_bunch",
        ".journalistcard_summary_name"
      ]) || metadata.byline,
      minTextLength: 60,
      rewriteRoot: function(root) {
        removeAll(root, [
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
        ].join(", "));

        root.querySelectorAll("p, div, span, strong").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 160) return;
          if (/^(기사제보|뉴스 구독|구독|좋아요|공유|댓글|본문 듣기|텍스트 음성 변환 서비스|무단 전재|재배포 금지|Copyright)/i.test(text)) el.remove();
        });
      }
    });
  }

  function naverNewsArticlePage() {
    if (!hostMatches(/^(?:n\.)?news\.naver\.com$/)) return false;
    if (!/^\/article\/\d+\/\d+/i.test(location.pathname || "")) return false;
    return !!naverNewsArticleBody();
  }

  function naverNewsArticleBody() {
    return document.querySelector("#dic_area") ||
      document.querySelector("#newsctArticle article") ||
      document.querySelector("#newsct_article article") ||
      document.querySelector(".newsct_article article") ||
      document.querySelector("#newsctArticle") ||
      document.querySelector("#newsct_article") ||
      document.querySelector(".newsct_article") ||
      document.querySelector("#articleBody") ||
      document.querySelector(".go_news_box") ||
      document.querySelector("#artcBody");
  }

  var naverNewsBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return naverNewsArticleContent(metadata) || naverNewsBaseHostAwareContent(metadata, pageText);
  };
