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

  function listCandidateLosesArticleMaterial(content, candidate) {
    if (!content || !candidate || content.contentType !== "article" || candidate.contentType !== "list") return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var seen = Object.create(null);
    var paragraphs = [];
    var substantialParagraphs = 0;
    var paragraphChars = 0;

    Array.prototype.forEach.call(root.querySelectorAll("p"), function(paragraph) {
      var text = normalizeText(paragraph.textContent || "");
      if (!text || seen[text]) return;

      seen[text] = true;
      paragraphs.push(text);
      paragraphChars += text.length;
      if (text.length >= 80) substantialParagraphs += 1;
    });

    if (substantialParagraphs < 3 || paragraphChars < 1200) return false;

    var articleText = normalizeText(content.textContent || content.markdown || "");
    var candidateMarkdown = candidate.markdown || candidate.textContent || "";
    var candidateText = normalizeText(candidateMarkdown
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/[`*_~#>|]/g, " "));
    if (candidateText.length >= articleText.length * 0.75) return false;

    // Compare article-owned prose, not page-wide records that can include navigation and footer links.
    var missingParagraphChars = paragraphs.reduce(function(total, paragraph) {
      return total + (candidateText.indexOf(paragraph) === -1 ? paragraph.length : 0);
    }, 0);
    return missingParagraphChars >= 900;
  }

  function listCandidateLosesArticleListMaterial(content, candidate) {
    if (!content || !candidate || content.contentType !== "article" || candidate.contentType !== "list") return false;

    var articleText = normalizeText(content.textContent || content.markdown || "");
    var candidateMarkdown = candidate.markdown || candidate.textContent || "";
    var candidateText = normalizeText(candidateMarkdown
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/[`*_~#>|]/g, " "));
    if (articleText.length < 1800 || candidateText.length < articleText.length * 0.5 || candidateText.length >= articleText.length) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    return Array.prototype.some.call(root.querySelectorAll("ul, ol"), function(list) {
      if (list.closest("nav, footer, aside, [role='navigation'], [role='menu'], [aria-hidden='true']")) return false;

      var seen = Object.create(null);
      var items = [];
      Array.prototype.forEach.call(list.children, function(item) {
        if (!item || item.tagName !== "LI") return;

        var text = normalizeText(item.textContent || "");
        if (text.length < 20 || text.length > 500 || seen[text]) return;
        var linkedText = Array.prototype.reduce.call(item.querySelectorAll("a[href]"), function(total, link) {
          return total + textLength(link);
        }, 0);
        if (linkedText >= text.length * 0.5) return;

        seen[text] = true;
        items.push(text);
      });
      if (items.length < 3) return false;

      var missingItems = items.filter(function(item) { return candidateText.indexOf(item) === -1; });
      var missingChars = missingItems.reduce(function(total, item) { return total + item.length; }, 0);
      return missingItems.length >= 3 && missingItems.length >= Math.ceil(items.length / 2) && missingChars >= 120;
    });
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

    return /(sidebar|side-bar|rail|utility|complementary|secondary|trending|popular|most-read|mostread|video|videos|photo|photos|gallery|galleries|web.?stor|newsletter|subscribe|social|share|follow|language|edition|top[_-]?nav|secondary-navbar|first-level-menu|second-level-menu|header-menu|side-nav|top-trending|wdt-trending|recommended|related|login|signup|register|account|forum[_-]?stats|online[_-]?users|who[_-]?is[_-]?online|board[_-]?stats|members[_-]?online|active[_-]?users|forum[_-]?rules|quick[_-]?reply|new[_-]?thread|moderator[_-]?panel|subforum[_-]?list)/.test(attrs) || listNoiseText(text);
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

    if (url.replace(/[?#].*$/, "") === context.currentUrl) return -Infinity;
    if (container && container.matches("article, section, li")) score += 120;

    var heading = container && container.querySelector("h1, h2, h3, h4");
    if (heading && normalizeText(heading.textContent || "") === text) score += 180;

    score += matchInfo.keywordMatches * 70;
    score += matchInfo.sectionMatches * 220;

    if (listNoiseNode(container) || listNoiseNode(container && container.parentElement)) score -= 260;
    if (listNoiseText(text) || listNoiseText(detail)) score -= 220;

    return score;
  }

  function listLinkCandidate(link, container, context, retainUnsafeLink) {
    if (!link) return null;

    var href = link.getAttribute("href");
    var headings = Array.prototype.slice.call(link.querySelectorAll("h1, h2, h3, h4"));
    var headingText = headings.map(function(heading) { return normalizeText(heading.textContent); }).filter(Boolean).join(" - ");
    var directAnchorTitle = genericListDirectAnchorTitle(link, container);
    var text = normalizeText(headingText || directAnchorTitle || link.textContent || link.getAttribute("aria-label") || "");
    var resolvedPath = "";
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);
    if (!href || href[0] === "#") return null;
    var tableIndexRow = context && context.tableIndexPage && container && container.matches && container.matches("tr");
    var group = genericListLinkGroup(link, context.linkGroups);
    var minimumTitleLength = minimumListTitleLength(text);
    if (group) minimumTitleLength = 1;
    else if (tableIndexRow) minimumTitleLength = 2;
    else if (directAnchorTitle && genericListWrappedAnchorCard(link)) minimumTitleLength = Math.min(6, minimumTitleLength);
    if (text.length < minimumTitleLength || text.length > 220) return null;

    var url = materializedHttpUrl(href);
    if (!url && !retainUnsafeLink) return null;
    if (url) {
      try {
        resolvedPath = new URL(url, location.href).pathname;
      } catch (_error) {
        return null;
      }
      if (url.replace(/[?#].*$/, "") === context.currentUrl) return null;
    }
    if (genericListControlText(text)) return null;
    if (/\/(subscribe|subscription|abonnement|login|register|newsletter|account|instellingen|settings)\b/i.test(resolvedPath || href)) return null;
    if (/\/(privacycontrols?|privacy|cookies?|consent)\b/i.test(resolvedPath || href) && text.length < 80) return null;
    if ((!group && looksLikeFooterLink(text, href)) || listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return null;
    if (genericListFigureCollectionRejectsLink(link, container, context.figureCollections)) return null;

    var card = listCardRoot(link, container, group, context.figureCollections);
    if (genericListSupportingCard(link, card, context.supportingCards)) return null;
    var detailSource = link.querySelector("h1, h2, h3, h4, p") ? link : card;
    var detailText;
    if (context.cardText && detailSource && context.cardText.has(detailSource)) {
      detailText = context.cardText.get(detailSource);
    } else {
      detailText = genericListCardText(detailSource);
      if (context.cardText && detailSource) context.cardText.set(detailSource, detailText);
    }
    if (headings.length > 1) {
      headings.forEach(function(heading) { detailText = detailText.replace(normalizeText(heading.textContent), ""); });
    } else detailText = detailText.replace(text, "");
    var detail = card && card.matches && card.matches("tr") ?
      listTableRowDetail(card, text) :
      detailText.replace(/\s*[|·]\s*/g, " - ");
    detail = stripGenericListControlPhrases(detail);
    if (!weatherPage && /\/(ve[ðd]ur|vedur|forecast|weather|spastod)\b/i.test(resolvedPath || href) && weatherModuleText(text + " " + detail)) return null;
    if (/\/(tv|spored)\//i.test(resolvedPath || href) && (/(vsak dan|poglej več|sezona|epizoda|oddaja)/i.test(text + " " + detail) || /\b\d{1,2}\.\d{2}\b/.test(text + " " + detail))) return null;
    var score = url ? listCandidateScore(text, url, detail, container || link.parentElement, context) : text.length + detail.length;
    if (score === -Infinity) return null;

    var candidate = { text: text, url: url, detail: detail, rankScore: score, card: card };
    if (card && card.matches && card.matches("tr")) candidate.tableRowDetail = true;
    if (headings.length > 1) candidate.titleHeadings = headings;
    if (group) {
      candidate.groupLabel = group.label;
      candidate.dedupeKey = listCanonicalKey(url) + "|label:" + text.toLowerCase();
    }
    var contentCard = closestGenericListCard(link);
    if (contentCard && contentCard !== card && !(card && card.matches && card.matches("tr"))) {
      candidate.contentCard = contentCard;
    }
    if (!url) {
      candidate.canonicalKey = "unlinked:" + text.toLowerCase() + "|href:" + href;
      candidate.dedupeKey = candidate.canonicalKey + "|detail:" + detail.toLowerCase();
    }
    if (container && container.matches && container.matches("tr") && detail) {
      candidate.dedupeKey = (candidate.canonicalKey || listCanonicalKey(url)) + "|row:" + normalizeText(detail).toLowerCase();
    }
    return candidate;
  }

  function scoreListContainer(node, context) {
    if (listChromeNode(node) || listNoiseNode(node)) return -Infinity;

    var links = node.querySelectorAll("a[href]").length;
    var items = node.querySelectorAll("li, tr, article, section").length;
    var cards = node.querySelectorAll("article, section, [class*='card' i], [class*='item' i], [class*='story' i], [class*='post' i], [class*='news' i], [class*='headline' i], [class*='feed' i], [class*='thread' i], [class*='topic' i], .structItem, .discussionListItem").length;
    var headings = node.querySelectorAll("h2, h3, h4").length;
    var headlineLinks = Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var href = link.getAttribute("href") || "";
      return href[0] !== "#" && materializedHttpUrl(href) && text.length >= minimumListTitleLength(text) && !looksLikeFooterLink(text, href) && !listChromeNode(link.parentElement) && !listChromeNode(link.closest("div, section, article, li"));
    }).length;
    var text = textLength(node);
    if (headlineLinks < 4 || text < 120) return -Infinity;
    if (/copyright|all rights reserved|privacy policy|terms of use/i.test(normalizeText(node.textContent || "")) && headings < 2) return -Infinity;

    var contextBonus = 0;
    if (context && (context.sectionFragments.length || context.keywords.length)) {
      Array.prototype.forEach.call(node.querySelectorAll("a[href]"), function(link) {
        var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        if (title.length < minimumListTitleLength(title)) return;

        var url = materializedHttpUrl(link.getAttribute("href"));
        if (!url) return;

        var matchInfo = listContextMatchInfo(title, url, "", context);
        contextBonus += (matchInfo.sectionMatches * 140) + (matchInfo.keywordMatches * 30);
      });
    }

    return (links * 10) + (headlineLinks * 30) + (items * 20) + (cards * 45) + (headings * 20) + contextBonus - Math.round(text / 40);
  }
