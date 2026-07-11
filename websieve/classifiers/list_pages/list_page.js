  function isProbablyListPage(content) {
    if (!document.body) return false;
    if (medicalArticlePage(null, content)) return false;
    if (articleRouteFocalContent(content)) return false;

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
    if (!document.body || articleRouteFocalContent(content)) return false;
    if (medicalArticlePage(null, content)) return false;
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

    if (legalJudgmentArticleContent(root, text) || legalStatuteArticleContent(root, text)) return false;
    if (institutionalCaseRecordListPage(root, text) || institutionalCaseRecordListPage(pageRoot)) return true;
    if (longParagraphs >= 5 && longParagraphText.length >= 1200 && linkDensity < 0.35) return false;
    return headlineLinks >= 6 && cards >= 6 && links >= 8 && (headings >= 4 || linkDensity >= 0.22) || articleFeedLinks >= 6 || jobResultsPage(root);
  }

  function crediblePortalRootListContent(metadata, content) {
    if (!document.body) return null;
    if (content && content.contentType !== "article" && content.contentType !== "list") return null;
    if (content && content.contentType === "list") {
      if (!homepageRootPath()) return null;
      if (content.docsLike) return null;
      var listRootContent = listContent(metadata, { portalRoot: true });
      if (!listRootContent.portalRootEvidence) return null;
      content.portalRootEvidence = listRootContent.portalRootEvidence;
      return content;
    }
    if (!content && !homepageRootPath()) return null;
    if (content && (content.hostAware || content.docsLike)) return null;
    if (typeof consentWallDominates === "function" && consentWallDominates(document.body.textContent || "")) return null;
    if (content && typeof notFoundInterstitialEvidence === "function" && notFoundInterstitialEvidence(content.title || document.title || "", document.body.textContent || "", { maxTextLength: 1400 })) return null;
    if (content && document.querySelector("article h1, article [itemprop='articleBody']") &&
        (normalizeText(content.byline || visibleByline() || "") || normalizeText(content.publishedTime || visiblePublishedTime() || ""))) return null;

    var extracted = listContent(metadata, { portalRoot: true });
    return extracted.portalRootEvidence ? extracted : null;
  }

  function institutionalCaseRecordListPage(root, text) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || articleRouteFocalContent()) return false;

    var context = normalizeText([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ")).toLowerCase();
    if (!/\b(?:cases?|defendants?|records?|dockets?|matters?)\b/.test(context)) return false;

    var caseCards = collectCardLinkCandidates(root, {
      cardSelectors: ".card, [class*='case-card' i], [class*='record-card' i], [class*='result-card' i], article, li",
      allowMissingUrl: true,
      dedupe: false,
      minTitleLength: 3,
      maxTitleLength: 180,
      linkBuilder: function(card) {
        return card.querySelector(".card-header, h2, h3, h4, a[href]");
      },
      candidateBuilder: function(card, titleNode) {
        var cardText = normalizeText(card.textContent || "");
        if (!/\b(?:case|defendant|prosecutor|trial|charges?|warrant|summons|custody|convicted|acquitted|closed|at large|court|record|docket|matter)\b/i.test(cardText)) return null;
        return { text: normalizeText((titleNode || {}).textContent || "") };
      }
    });
    var filterBlocks = root.querySelectorAll("form, [class*='filter' i], [class*='facet' i], [class*='exposed' i], [class*='search' i]").length;
    var countLabel = /\b\d{1,4}\s+(?:cases?|defendants?|records?|matters?|results?)\b/i.test(text);

    return caseCards.length >= 4 && (filterBlocks >= 1 || countLabel);
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

    if (legalTableOfContentsPage(root, text)) return false;
    if (legalJudgmentArticleContent(root, text) || legalStatuteArticleContent(root, text)) return true;
    if (!likelyListPath() && text.length >= 280 && linkDensity < 0.5) return true;
    if (likelyListPath() && linkDensity > 0.5) return false;
    if (likelyListPath() && headings >= 5 && headings >= paragraphs * 0.6) return false;

    if (text.length < 280) return false;
    if (paragraphs < 3 && headings < 1 && !articlePath) return false;
    if (listLinks.length >= 8 && paragraphs < 5) return false;
    if (linkDensity > 0.33 && paragraphs < 6) return false;

    return (articlePath && text.length >= 280 && linkDensity < 0.5) || paragraphs >= 5 || (content.readerMode && paragraphs >= 3 && linkDensity < 0.28);
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
      if (links < 3) return;
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
