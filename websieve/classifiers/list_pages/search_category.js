  function thinSearchOrCategoryPage(content) {
    if (!content || content.contentType !== "article" || articleRouteFocalContent(content)) return false;
    if (!queryOrCategoryPage()) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    var paragraphs = root.querySelectorAll("p").length;
    var longParagraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 180;
    }).length;
    var byline = normalizeText(content.byline || "");
    var publishedTime = normalizeText(content.publishedTime || "");
    var heading = document.querySelector("main h1, [role='main'] h1, h1");
    var context = normalizeText([document.title, heading && heading.textContent].join(" ")).toLowerCase();

    if (publishedTime || byline) return false;
    if (typeof consentWallDominates === "function" && consentWallDominates(text.toLowerCase())) return false;
    if (!/(search|results?|shop|browse|categor|catalog|keyword|wholesale|products?|collections?|marketplace)/.test(context)) return false;
    if (longParagraphs >= 4 && text.length >= 1200) return false;
    return text.length < 2400 || paragraphs <= 4;
  }

  function markdownIndexListPage(markdown, content) {
    if (!markdown || articleRouteFocalContent(content)) return false;
    if (legalJudgmentArticleContent(null, markdown) || legalStatuteArticleContent(null, markdown)) return false;
    if (legalTableOfContentsMarkdown(markdown)) return true;
    if (!likelyListPath() && !queryOrCategoryPage()) return false;
    if (normalizeText(content && (content.byline || content.publishedTime))) return false;

    var lines = String(markdown).split(/\n+/);
    var linkedHeadlineLines = lines.filter(function(line) {
      return /^\s*(?:(?:\d+\.|[-*])\s+)?#{1,4}\s+\[[^\]]{8,220}\]\(/.test(line) ||
        /^\s*(?:\d+\.|[-*])\s+\[[^\]]{8,220}\]\(/.test(line);
    }).length;
    var linkedHeadlineMatches = (String(markdown).match(/(?:^|\s)(?:(?:\d+\.|[-*])\s+)?#{1,4}\s+\[[^\]]{8,220}\]\(/g) || []).length +
      (String(markdown).match(/(?:^|\s)(?:\d+\.|[-*])\s+\[[^\]]{8,220}\]\(/g) || []).length;
    var proseLines = lines.filter(function(line) {
      var text = normalizeText(line).replace(/^#+\s*/, "");
      if (!text || text.length < 160) return false;
      return !/^\s*(?:(?:\d+\.|[-*])\s+)?#{0,4}\s*\[[^\]]+\]\(/.test(line);
    }).length;

    if (markdownArticleEntryLinks(markdown) >= 6) return true;
    return Math.max(linkedHeadlineLines, linkedHeadlineMatches) >= 4 && proseLines < 5;
  }

  function searchResultsListPage(content, markdown) {
    if (!content || content.contentType !== "article" || articleRouteFocalContent(content)) return false;

    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    var searchUrl = /\/(?:search|results?)(?:\.html?)?$/i.test(path) || /(?:^|[?&])(?:q|query|search|searchtext|keyword|k|text)=/.test(query);
    if (!searchUrl) return false;

    var root = document.createElement("div");
    root.innerHTML = (content && content.html) || document.body.innerHTML;
    var text = normalizeText([root.textContent || "", markdown || "", document.title || ""].join(" "));
    var countText = text.replace(/[*_`]+/g, "");
    var resultCountText = /\bresults?\s*\d+\s*[-–]\s*\d+\s*(?:of|sur|von|de)\s*\d+\b/i.test(countText) || /\b\d+\s+results?\b/i.test(countText);
    var resultLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var label = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (label.length < minimumListTitleLength(label) || label.length > 280 || looksLikeFooterLink(label, href)) return false;
      return /\/(?:legal-content|eli|LexUriServ|resource|document|doc|case-law|summary)\b|[?&](?:uri|celex|qid|docid)=/i.test(href);
    }).length;
    var resultContainers = root.querySelectorAll("[class*='result' i], [id*='result' i], article, li, tr").length;
    var markdownResultLinks = (String(markdown || "").match(/^\s*#{1,4}\s+\[[^\]]{8,280}\]\(/gm) || []).length;

    return resultCountText && (resultLinks >= 3 || markdownResultLinks >= 3) && (resultContainers >= 3 || markdownResultLinks >= 3);
  }
