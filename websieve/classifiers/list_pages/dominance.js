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
    if (!weatherPage && /\/(ve[ðd]ur|vedur|forecast|weather|spastod)\b/i.test(url) && weatherModuleText(text + " " + detail)) return null;
    if (/\/(tv|spored)\//i.test(url) && (/(vsak dan|poglej več|sezona|epizoda|oddaja)/i.test(text + " " + detail) || /\b\d{1,2}\.\d{2}\b/.test(text + " " + detail))) return null;
    var score = listCandidateScore(text, url, detail, container || link.parentElement, context);
    if (score === -Infinity) return null;

    return { text: text, url: url, detail: detail, score: score, card: listCardRoot(link, container) };
  }

  function listCardRoot(link, fallback) {
    var card = link && link.closest && link.closest("article, li, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']");
    return card || fallback || (link && link.parentElement);
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
      Array.prototype.forEach.call(node.querySelectorAll("a[href]"), function(link) {
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
