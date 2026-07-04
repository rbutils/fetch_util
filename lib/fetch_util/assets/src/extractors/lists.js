  function searchItemTitle(link) {
    var heading = link.querySelector("h1, h2, h3, h4");
    return normalizeText(heading ? heading.textContent : link.textContent);
  }

  function cjkLikeText(text) {
    return /[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/.test(text || "");
  }

  function minimumListTitleLength(text) {
    return cjkLikeText(text) ? 4 : 8;
  }

  function searchItemDetail(node, title) {
    var detail = normalizeText(node && node.textContent).replace(normalizeText(title), "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail
      .replace(/Only include results for this site.*$/i, "")
      .replace(/This search result is provided by Google Learn more Report result/gi, "")
      .replace(/Learn more Report result/gi, "")
      .replace(/Report Ad/gi, "")
      .replace(/\bhttps?:\/\/\S+/gi, "")
      .replace(/\s{2,}/g, " ");
    return normalizeText(detail);
  }

  function isProbablyListPage(content) {
    if (!document.body) return false;

    function listSignals(root) {
      var links = root.querySelectorAll("a").length;
      var paragraphs = root.querySelectorAll("p").length;
      var rows = root.querySelectorAll("tr, li, article, section").length;
      var listItems = root.querySelectorAll("li").length;
      var listish = root.querySelectorAll("table, ul, ol, .itemlist, .items, .stories, .posts, .news, .headlines, .feed, .threads, .topic-list, .forumlist, .discussionList").length;
      var headings = root.querySelectorAll("h1, h2, h3, h4").length;
      var cards = root.querySelectorAll("article, section, [class*='card'], [class*='item'], [class*='story'], [class*='post'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic-list'], .structItem, .discussionListItem").length;
      var headlineLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return text.length >= minimumListTitleLength(text) && text.length <= 220 && !looksLikeFooterLink(text, link.getAttribute("href") || "");
      }).length;
      var text = normalizeText(root.textContent);
      var title = normalizeText(document.title).toLowerCase();
      var path = (location.pathname || "").toLowerCase();
      var homepage = path === "/" || path === "" || /^\/(index|default|home)\b/i.test(path) || /^\/\d+(,\d+)*\.html?$/i.test(path);

      return {
        links: links,
        paragraphs: paragraphs,
        rows: rows,
        listItems: listItems,
        listish: listish,
        headings: headings,
        cards: cards,
        headlineLinks: headlineLinks,
        text: text,
        title: title,
        homepage: homepage
      };
    }

    function homepageLike(signals) {
      // High-confidence portal detection: overwhelmingly list-like signals
      // bypass text length cap entirely (e.g. news portals with 40K-200K DOM text)
      if (signals.homepage && signals.headlineLinks >= 20 && signals.cards >= 15 && (signals.headings >= 8 || signals.cards >= 40)) return true;
      if (signals.headlineLinks >= 30 && signals.cards >= 20 && (signals.headings >= 10 || signals.cards >= 40)) return true;
      if (signals.homepage && signals.headlineLinks >= 16 && signals.headings >= 8 && signals.links >= 80 && signals.text.length <= 240000) return true;
      if (signals.headlineLinks >= 24 && signals.headings >= 10 && signals.links >= 120 && (signals.homepage || signals.rows >= 20 || signals.listish >= 2) && signals.text.length <= 240000) return true;

      return ((signals.links >= 8 && signals.rows >= 6) || (signals.listish > 0 && signals.links >= 6)) && signals.paragraphs <= 8 && signals.text.length <= 14000 ||
        ((signals.rows >= 6 && signals.headlineLinks >= 6 && signals.headings >= 6) && signals.text.length <= 36000) ||
        (signals.homepage && signals.headlineLinks >= 4 && signals.headings >= 3 && signals.text.length <= 36000 && (signals.listItems >= 4 || signals.cards >= 4 || /top stories|breaking news|latest news|headlines|ultime notizie|in evidenza|primo piano/.test(signals.title + " " + signals.text.slice(0, 400)))) ||
        (signals.cards >= 4 && signals.headlineLinks >= 4 && signals.headings >= 3 && signals.text.length <= 36000);
    }

    var pageRoot = document.createElement("div");
    pageRoot.innerHTML = document.body.innerHTML;
    var pageSignals = listSignals(pageRoot);

    if (homepageLike(pageSignals)) return true;

    var root = document.createElement("div");
    root.innerHTML = content && content.html ? content.html : document.body.innerHTML;
    return homepageLike(listSignals(root));
  }

  function dominantIndexListPage(content) {
    if (!document.body || articleLikePath()) return false;
    if (!likelyListPath() && !queryOrCategoryPage() && !jobResultsPage()) return false;

    var root = document.createElement("div");
    root.innerHTML = (content && content.html) || document.body.innerHTML;
    var links = root.querySelectorAll("a[href]").length;
    var cards = root.querySelectorAll("article, li, section, [class*='card'], [class*='item'], [class*='story'], [class*='product'], [class*='tile'], [class*='job'], [data-testid*='card'], [data-testid*='product'], [data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-url*='/remote-jobs/']").length;
    var headings = root.querySelectorAll("h2, h3, h4").length;
    var headlineLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      return text.length >= minimumListTitleLength(text) && text.length <= 220 && !looksLikeFooterLink(text, link.getAttribute("href") || "");
    }).length;
    var paragraphTexts = Array.prototype.map.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(Boolean);
    var longParagraphs = paragraphTexts.filter(function(text) { return text.length >= 180; }).length;
    var longParagraphText = paragraphTexts.filter(function(text) { return text.length >= 120; }).join(" ");
    var text = normalizeText(root.textContent || (content && (content.textContent || content.markdown)) || "");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;
    var pageRoot = document.createElement("div");
    pageRoot.innerHTML = document.body.innerHTML;
    var articleFeedLinks = Math.max(sectionFeedArticleLinks(root), sectionFeedArticleLinks(pageRoot));

    if (legalJudgmentArticleContent(root, text)) return false;
    if (institutionalCaseRecordListPage(root, text) || institutionalCaseRecordListPage(pageRoot)) return true;
    if (longParagraphs >= 5 && longParagraphText.length >= 1200 && linkDensity < 0.35) return false;
    return headlineLinks >= 6 && cards >= 6 && links >= 8 && (headings >= 4 || linkDensity >= 0.22) || articleFeedLinks >= 6 || jobResultsPage(root);
  }

  function institutionalCaseRecordListPage(root, text) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || articleLikePath()) return false;

    var context = normalizeText([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ")).toLowerCase();
    if (!/\b(?:cases?|defendants?|records?|dockets?|matters?)\b/.test(context)) return false;

    var cards = Array.prototype.slice.call(root.querySelectorAll(".card, [class*='case-card' i], [class*='record-card' i], [class*='result-card' i], article, li"));
    var caseCards = cards.filter(function(card) {
      var cardText = normalizeText(card.textContent || "");
      var title = normalizeText(((card.querySelector(".card-header, h2, h3, h4, a[href]") || {}).textContent) || "");
      return title.length >= 3 && title.length <= 180 &&
        /\b(?:case|defendant|prosecutor|trial|charges?|warrant|summons|custody|convicted|acquitted|closed|at large|court|record|docket|matter)\b/i.test(cardText);
    });
    var filterBlocks = root.querySelectorAll("form, [class*='filter' i], [class*='facet' i], [class*='exposed' i], [class*='search' i]").length;
    var countLabel = /\b\d{1,4}\s+(?:cases?|defendants?|records?|matters?|results?)\b/i.test(text);

    return caseCards.length >= 4 && (filterBlocks >= 1 || countLabel);
  }

  function jobResultsPage(root) {
    root = root || document.body;
    if (!root || articleLikePath()) return false;

    var context = normalizeText([location.pathname, location.search, document.title].join(" ")).toLowerCase();
    if (!/(\bjobs?\b|employment|careers?|jobsearch|job-list|job results?|hiring|remote-[a-z0-9+-]+-jobs|q-[a-z0-9-]+-jobs)/i.test(context)) return false;

    var jobCards = root.querySelectorAll("[data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-testid*='job' i], [class*='job-card' i], [class*='jobCard'], tr[data-id][data-url*='/remote-jobs/'], [data-url*='/remote-jobs/']").length;
    var jobLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (text.length < minimumListTitleLength(text) || text.length > 220) return false;
      return /(\/job-listing\/|\/remote-jobs\/|\/viewjob\b|\/rc\/clk\b|[?&](?:jk|jl)=)/i.test(href);
    }).length;

    return jobCards >= 4 || jobLinks >= 4;
  }

  function sectionFeedArticleLinks(root) {
    var currentUrl = currentListPageUrl();
    var seen = [];

    Array.prototype.forEach.call(root.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var url = absoluteUrl(link.getAttribute("href"));
      var parsed;

      if (text.length < minimumListTitleLength(text) || text.length > 220 || looksLikeFooterLink(text, url || "")) return;
      if (!url) return;

      try {
        parsed = new URL(url, location.href);
      } catch (_error) {
        return;
      }

      if (parsed.origin !== location.origin || (parsed.origin + parsed.pathname) === currentUrl) return;
      if (!articleEntryPath(parsed.pathname)) return;
      if (seen.indexOf(parsed.origin + parsed.pathname) === -1) seen.push(parsed.origin + parsed.pathname);
    });

    return seen.length;
  }

  function thinSearchOrCategoryPage(content) {
    if (!content || content.contentType !== "article" || articleLikePath()) return false;
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
    if (!markdown || articleLikePath()) return false;
    if (legalJudgmentArticleContent(null, markdown)) return false;
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
    if (!content || content.contentType !== "article" || articleLikePath()) return false;

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

  function markdownArticleEntryLinks(markdown) {
    var seen = [];
    var pattern = /\[[^\]]{8,220}\]\(([^\s)]+)\)|https?:\/\/[^\s)]+/g;
    var match;

    while ((match = pattern.exec(String(markdown || "")))) {
      var raw = match[1] || match[0];
      var parsed;

      try {
        parsed = new URL(raw, location.href);
      } catch (_error) {
        continue;
      }

      if (parsed.origin !== location.origin || (parsed.origin + parsed.pathname) === currentListPageUrl()) continue;
      if (!articleEntryPath(parsed.pathname)) continue;
      if (seen.indexOf(parsed.origin + parsed.pathname) === -1) seen.push(parsed.origin + parsed.pathname);
    }

    return seen.length;
  }

  function relabelAsListContent(content) {
    if (content) content.contentType = "list";
    return content;
  }

  function substantialArticleContent(content) {
    if (!content || content.contentType !== "article") return false;
    var homePath = (location.pathname || "").toLowerCase();
    if (homePath === "/" || homePath === "" || /^\/(index|default|home)\b/i.test(homePath) || /^\/\d+(,\d+)*\.html?$/i.test(homePath)) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";

    var text = normalizeText(root.textContent || content.textContent || "");
    var paragraphs = root.querySelectorAll("p").length;
    var headings = root.querySelectorAll("h1, h2, h3").length;
    var listLinks = (content.markdown || "").match(/^\s*- \[/gm) || [];
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;
    var articlePath = articleLikePath();

    if (legalJudgmentArticleContent(root, text)) return true;
    if (!likelyListPath() && text.length >= 280 && linkDensity < 0.5) return true;
    if (likelyListPath() && linkDensity > 0.5) return false;
    if (likelyListPath() && headings >= 5 && headings >= paragraphs * 0.6) return false;

    if (text.length < 280) return false;
    if (paragraphs < 3 && headings < 1 && !articlePath) return false;
    if (listLinks.length >= 8 && paragraphs < 5) return false;
    if (linkDensity > 0.33 && paragraphs < 6) return false;

    return (articlePath && text.length >= 280 && linkDensity < 0.5) || paragraphs >= 5 || (content.readerMode && paragraphs >= 3 && linkDensity < 0.28);
  }

  function legalJudgmentArticleContent(root, text) {
    text = normalizeText(text || "");
    if (text.length < 5000) return false;

    if (/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i.test(text)) return false;
    if (root && root.querySelector("[class*='result' i], [id*='result' i]")) return false;

    var signals = 0;
    if (/\b(?:high court|supreme court|court of appeal|federal court|district court|court of justice|tribunal)\b/i.test(text)) signals += 1;
    if (/\b(?:judg(?:e)?ment|opinion of the court|reasons for judgment|delivered by|per curiam)\b/i.test(text)) signals += 1;
    if (/\b(?:appellant|respondent|plaintiff|defendant|petitioner|counsel|solicitor|amicus|certiorari)\b/i.test(text)) signals += 1;
    if (/\b[A-Z][A-Za-z'.-]+\s+v\.?\s+[A-Z][A-Za-z'.-]+\b/.test(text)) signals += 1;
    if (/\[[12][0-9]{3}\]\s+[A-Z][A-Z0-9.]{1,12}\s+\d+|\([12][0-9]{3}\)\s+\d+\s+[A-Z][A-Z0-9.]{1,12}\s+\d+/i.test(text)) signals += 1;
    if (signals < 3) return false;

    var longBlocks = root ? Array.prototype.filter.call(root.querySelectorAll("p, div, section, article, pre, blockquote"), function(node) {
      return normalizeText(node.textContent || "").length >= 180;
    }).length : 0;
    var sentenceRuns = (text.match(/[.;:]\s+[A-Z][a-z]{2,}/g) || []).length;

    return longBlocks >= 5 || sentenceRuns >= 35 || text.length >= 20000;
  }

  function strongArticleMetadata(metadata, content) {
    metadata = metadata || {};
    content = content || {};

    var title = normalizeText(content.title || metadata.title || "");
    var excerpt = normalizeText(content.excerpt || metadata.excerpt || "");
    var publishedTime = normalizeText(content.publishedTime || metadata.publishedTime || "");
    var byline = normalizeText(content.byline || metadata.byline || "");
    var text = normalizeText(content.textContent || content.markdown || "");

    if (title.length < minimumListTitleLength(title) || text.length < 220) return false;
    if (publishedTime && excerpt.length >= 40) return true;
    if (publishedTime && byline) return true;
    return !!(publishedTime && text.length >= 320);
  }

  function likelyListPath() {
    var path = (location.pathname || "").toLowerCase();
    var segments = path.split("/").filter(Boolean);
    var last = segments[segments.length - 1] || "";

    if (!segments.length) return true;
    if (/^\/(index|default|home)\b/i.test(path) || /^\/\d+(,\d+)*\.html?$/i.test(path)) return true;
    if (/\/(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|notizie|calciomercato|mercato|forums?|boards?|community|discussions?|threads)\/?$/.test(path)) return true;
    if (segments.length <= 2 && !/\d{4}[-/]\d{2}[-/]\d{2}/.test(path) && !/-/.test(last) && !/\.(html?|php|aspx?|jsp|shtml)$/i.test(last)) return true;
    return false;
  }

  function opaqueDetailPath() {
    return opaqueDetailIdPath((location.pathname || "").toLowerCase().split("/").filter(Boolean));
  }

  function opaqueDetailIdPath(segments) {
    if (!segments || segments.length !== 2) return false;

    var first = segments[0] || "";
    var last = segments[1] || "";
    if (/^(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|forums?|boards?|community|discussions?|threads)$/.test(first)) return false;
    return last.length >= 6 && /[a-z]/i.test(last) && /\d/.test(last) && /^[a-z0-9_-]+$/i.test(last);
  }

  function queryOrCategoryPage() {
    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    return /(?:^|[?&])(q|query|search|searchtext|keyword|k)=/.test(query) ||
      /\/(search|s|shop|browse|category|categories|collections?|catalog|keyword|wholesale|products?|jobs?)\b/.test(path) ||
      /\b(category|categories|collection|catalog|search results?|shop|jobs?\s+(?:in|matching|for)|job results?)\b/i.test(document.title || "");
  }

  function articleLikePath() {
    return /\/(20\d{2}|\d{4}\/\d{2}\/\d{2}|article|articles|blog|blogs|column|columns|archive|archives|news\/[\w-]+|entry|entries|post|posts|\d{5,}[\w-]*\.html?)\b/i.test(location.pathname || "");
  }

  function articleEntryPath(path) {
    return /\/(?:20\d{2}|\d{4}\/\d{2}|[a-z0-9-]+\/\d{5,}(?:\/|$)|\d{5,}(?:\/|$)|[^\/]+-[^\/]+-[^\/]+)/i.test(path || "");
  }

  function looksLikeFooterLink(text, href) {
    return /^(privacy|cookies?|terms|chi siamo|about us|contact|contatti|redazione|advertising|newsletter|subscribe|login|sign in|register|cookie settings|manage preferences)$/i.test(text) ||
      /\/(privacy|cookie|cookies|terms|about|contatti|contact|redazione|login|register)\b/i.test(href || "");
  }

  function currentListPageUrl() {
    return location.origin + location.pathname;
  }

  function tokenizeListText(text) {
    return safeDecodeURI(text || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").split(/\s+/).filter(Boolean);
  }

  function listPageContext(metadata) {
    metadata = metadata || {};

    var heading = document.querySelector("main h1, [role='main'] h1, h1");
    var siteTokens = tokenizeListText((metadata.siteName || location.hostname || "").replace(/^www\./i, ""));
    var generic = /^(latest|news|article|articles|articlelist|story|stories|home|homepage|index|default|today|more|page|pages|section|sections|category|categories|topic|topics|read|view|photo|photos|video|videos|gallery|galleries|live|blog|blogs|web|english|telugu|samayam|newsweb|edition)$/;
    var tokens = tokenizeListText([
      location.pathname || "",
      metadata.title || "",
      document.title || "",
      heading ? heading.textContent : ""
    ].join(" ")).filter(function(token) {
      return token.length >= 3 && !/^\d+$/.test(token) && !generic.test(token) && siteTokens.indexOf(token) === -1;
    });

    var keywords = [];
    tokens.forEach(function(token) {
      if (keywords.indexOf(token) === -1 && keywords.length < 12) keywords.push(token);
    });

    var sectionFragments = [];
    (location.pathname || "").split("/").filter(Boolean).forEach(function(segment) {
      var value = safeDecodeURI(segment || "").toLowerCase();
      if (!value || /^\d/.test(value) || /\.(html?|php|aspx?|jsp|cms)$/i.test(value)) return;
      if (/^(news|latest-news|latest|articlelist|articles?|read|view|topic|topics|section|sections|home|index|default|world|india-news|international-news|english|telugu)$/.test(value)) return;
      if (sectionFragments.indexOf(value) === -1) sectionFragments.push(value);
    });

    return {
      currentUrl: currentListPageUrl(),
      keywords: keywords,
      sectionFragments: sectionFragments.slice(0, 4)
    };
  }

  function listNoiseText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text) return false;

    return /(trending topics|latest videos|latest photos|లేటెస్ట్ వీడియోలు|లేటెస్ట్ ఫోటోలు|video gallery|photo gallery|web stories|most read|best gelezen|newsletter|subscribe|abonneren|log in|login|sign in|register|create account|maak een account|u bent niet|settings|instellingen|tip ons|nieuwstip|belangrijke informatie delen|copyright|all rights reserved|privacy preference center|manage cookie preferences|manage consent preferences|manage privacy preferences|your privacy settings|your privacy choices|cookie list|cookie information|list of partners \(vendors\)|this website uses cookies|by accepting cookies|cookie declaration last updated|consent id|change your consent|your current state|vsak dan|poglej več|mark forums? read|forum statistics|members online|who is online|users browsing|forum rules|new posts since last visit|currently active users|forum contains no new|board statistics|mark all forums? read|what's going on|users online|active threads|active users)/i.test(text) || (/\b\d{1,2}\.\d{2}\b/.test(text) && /(vsak dan|sezona|oddaja|epizoda|premiera)/i.test(text));
  }

  function weatherModuleText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (!/(ve[ðd]ursp[áa]( næsta s[óo]larhring)?|weather forecast|uppl[ýy]singar um ve[ðd]ur)/i.test(normalized)) return false;
    var hits = normalized.match(/\b(ve[ðd]ursp[áa]|hiti|[úu]rkoma|vindur|frost|rigning|sk[ýy]ja[ðd]|temperature|precipitation|wind|rain|snow|storm)\b/ig) || [];
    return hits.length >= 3;
  }

  function listNoiseNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();
    var text = normalizeText(node.textContent || "").slice(0, 280);

    return /(trending|popular|most-read|mostread|video|videos|photo|photos|gallery|galleries|web.?stor|newsletter|subscribe|social|share|follow|language|edition|top[_-]?nav|secondary-navbar|first-level-menu|second-level-menu|header-menu|side-nav|top-trending|wdt-trending|recommended|related|login|signup|register|account|forum[_-]?stats|online[_-]?users|who[_-]?is[_-]?online|board[_-]?stats|members[_-]?online|active[_-]?users|forum[_-]?rules|quick[_-]?reply|new[_-]?thread|moderator[_-]?panel|subforum[_-]?list)/.test(attrs) || listNoiseText(text);
  }

  function listContextMatchInfo(text, url, detail, context) {
    var path = "";
    var combined = (text + " " + (detail || "")).toLowerCase();
    var keywordMatches = 0;
    var sectionMatches = 0;

    try {
      path = new URL(url, location.href).pathname.toLowerCase();
    } catch (_error) {
      path = "";
    }

    context.keywords.forEach(function(token) {
      if ((combined + " " + path).indexOf(token) !== -1) keywordMatches += 1;
    });

    context.sectionFragments.forEach(function(fragment) {
      if (path.indexOf(fragment) !== -1) sectionMatches += 1;
    });

    return {
      path: path,
      keywordMatches: keywordMatches,
      sectionMatches: sectionMatches
    };
  }

  function listCandidateScore(text, url, detail, container, context) {
    if (!url) return -Infinity;

    var score = text.length;
    var matchInfo = listContextMatchInfo(text, url, detail, context);
    var path = matchInfo.path;

    if ((location.origin + path) === context.currentUrl) return -Infinity;
    if (container && container.matches("article, section, li")) score += 120;

    var heading = container && container.querySelector("h1, h2, h3, h4");
    if (heading && normalizeText(heading.textContent || "") === text) score += 180;

    score += matchInfo.keywordMatches * 70;
    score += matchInfo.sectionMatches * 220;

    if (listNoiseNode(container) || listNoiseNode(container && container.parentElement)) score -= 260;
    if (listNoiseText(text) || listNoiseText(detail)) score -= 220;

    return score;
  }

  function listLinkCandidate(link, container, context) {
    if (!link) return null;

    var href = link.getAttribute("href");
    var heading = link.querySelector("h1, h2, h3, h4");
    var text = normalizeText((heading && heading.textContent) || link.textContent || link.getAttribute("aria-label") || "");
    var resolvedPath = "";
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);
    if (!href || href[0] === "#" || /^(javascript:|mailto:)/i.test(href)) return null;
    if (text.length < minimumListTitleLength(text) || text.length > 220) return null;

    var url = absoluteUrl(href);
    if (!url) return null;
    try {
      resolvedPath = new URL(url, location.href).pathname;
    } catch (_error) {
      return null;
    }
    if ((location.origin + resolvedPath) === context.currentUrl) return null;
    if (/^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(text)) return null;
    if (/\/(subscribe|subscription|abonnement|login|register|newsletter|account|instellingen|settings)\b/i.test(url)) return null;
    if (/\/(privacycontrols?|privacy|cookies?|consent)\b/i.test(url) && text.length < 80) return null;
    if (looksLikeFooterLink(text, href) || listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return null;

    var detailSource = link.querySelector("h1, h2, h3, h4, p") ? link : container;
    var detail = normalizeText(((detailSource && detailSource.textContent) || "")).replace(text, "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail.replace(/\b(last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)\b/gi, "").replace(/\s{2,}/g, " ").trim();
    if (detail.length > 420) detail = detail.slice(0, 417).replace(/\s+\S*$/, "") + "...";
    if (!weatherPage && /\/(ve[ðd]ur|vedur|forecast|weather|spastod)\b/i.test(url) && weatherModuleText(text + " " + detail)) return null;
    if (/\/(tv|spored)\//i.test(url) && (/(vsak dan|poglej več|sezona|epizoda|oddaja)/i.test(text + " " + detail) || /\b\d{1,2}\.\d{2}\b/.test(text + " " + detail))) return null;
    var score = listCandidateScore(text, url, detail, container || link.parentElement, context);
    if (score === -Infinity) return null;

    return { text: text, url: url, detail: detail, score: score };
  }

  function listAncestorOfType(link, nodeChecker) {
    var node = link && link.parentElement;

    while (node && node !== document.body) {
      if (node.matches && node.matches("article, li, main, [role='main']")) return null;
      if (node.matches && node.matches("header") && link.closest("article, section, main, [role='main']")) {
        node = node.parentElement;
        continue;
      }
      if (nodeChecker(node)) return node;
      node = node.parentElement;
    }

    return null;
  }

  function listChromeAncestor(link) {
    return listAncestorOfType(link, listChromeNode);
  }

  function listNavigationAncestor(link) {
    return listAncestorOfType(link, listNavigationNode);
  }

  function listChromeOrNavigationNode(node, includeSocial) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return true;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();

    if (!attrs) return false;
    if (/(news|headline|story|article|post|feed|stream|content|result|listing|archive|topic|thread|discussion|feature)/.test(attrs)) return false;
    if (includeSocial) return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer|utility|meta|social|share|follow|account|login|signup|register)/.test(attrs);
    return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer)/.test(attrs);
  }

  function listChromeNode(node) {
    return listChromeOrNavigationNode(node, true);
  }

  function listNavigationNode(node) {
    return listChromeOrNavigationNode(node, false);
  }

  function scoreListContainer(node, context) {
    if (listChromeNode(node) || listNoiseNode(node)) return -Infinity;

    var links = node.querySelectorAll("a[href]").length;
    var items = node.querySelectorAll("li, tr, article, section").length;
    var cards = node.querySelectorAll("article, section, [class*='card'], [class*='item'], [class*='story'], [class*='post'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic'], .structItem, .discussionListItem").length;
    var headings = node.querySelectorAll("h2, h3, h4").length;
    var headlineLinks = Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      return text.length >= minimumListTitleLength(text) && !looksLikeFooterLink(text, link.getAttribute("href") || "") && !listChromeNode(link.parentElement) && !listChromeNode(link.closest("div, section, article, li"));
    }).length;
    var text = textLength(node);
    if (headlineLinks < 4 || text < 120) return -Infinity;
    if (/copyright|all rights reserved|privacy policy|terms of use/i.test(normalizeText(node.textContent || "")) && headings < 2) return -Infinity;

    var contextBonus = 0;
    if (context && (context.sectionFragments.length || context.keywords.length)) {
      Array.prototype.slice.call(node.querySelectorAll("a[href]"), 0, 80).forEach(function(link) {
        var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        if (title.length < minimumListTitleLength(title)) return;

        var url = absoluteUrl(link.getAttribute("href"));
        if (!url) return;

        var matchInfo = listContextMatchInfo(title, url, "", context);
        contextBonus += (matchInfo.sectionMatches * 140) + (matchInfo.keywordMatches * 30);
      });
    }

    return (links * 10) + (headlineLinks * 30) + (items * 20) + (cards * 45) + (headings * 20) + contextBonus - Math.round(text / 40);
  }

  function listCandidateRoot(metadata) {
    var context = listPageContext(metadata);
    var selectors = ["main", "[role='main']", ".itemlist", "table", "ol", "ul", ".posts", ".stories", ".items", ".news", ".feed", ".headlines", ".view-case-listing", "[class*='case-listing' i]", "[class*='record-listing' i]", "[class*='news']", "[class*='feed']", "[class*='headline']", ".threads", ".topic-list", ".forumlist", ".discussionList", "[class*='threadlist']", "[class*='thread-list']", "[class*='topic-list']", "body"];
    var candidates = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        candidates.push(node);
      });
    });

    var best = candidates.reduce(function(current, node) {
      var score = scoreListContainer(node, context);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    return best && best.score > -Infinity ? best.node : document.body;
  }

  function contextualListCandidates(metadata) {
    var context = listPageContext(metadata);
    var candidates = [];

    if (!context.sectionFragments.length && !context.keywords.length) return candidates;

    function push(node) {
      if (!node || node === document.body || node === document.documentElement || candidates.indexOf(node) !== -1) return;
      if (listChromeNode(node) || listNoiseNode(node)) return;

      var links = node.querySelectorAll("a[href]").length;
      if (links < 3 || links > 250) return;
      if (textLength(node) < 140) return;

      candidates.push(node);
    }

    Array.prototype.forEach.call(document.querySelectorAll("a[href]"), function(link) {
      var container = link.closest("article, section, div, li, ul, ol, main") || link.parentElement;
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;
      if (candidate.score < 260) return;

      var node = container;
      var depth = 0;
      while (node && depth < 4) {
        push(node);
        if (node.matches && node.matches("main, [role='main']")) break;
        node = node.parentElement;
        depth += 1;
      }
    });

    return candidates;
  }
