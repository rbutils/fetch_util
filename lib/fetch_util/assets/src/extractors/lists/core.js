  function pushUniqueListCandidate(candidates, seen, candidate) {
    if (!candidate) return false;

    var key = candidate.text + "|" + candidate.url;
    if (seen[key] || seen["url:" + candidate.url]) return false;
    seen[key] = true;
    seen["url:" + candidate.url] = true;
    candidates.push(candidate);
    return true;
  }
  function listCandidateRank(a, b) {
    return b.score - a.score || b.text.length - a.text.length;
  }

  function listCandidateScoreRank(a, b) {
    return b.score - a.score;
  }
  function collectCardLinkCandidates(root, options) {
    options = options || {};
    root = root || document;

    var cards = [];
    var selectors = options.cardSelectors || [];
    var seenCards = [];
    var seenCandidates = {};
    var items = [];
    var maxItems = options.maxItems || Infinity;
    var minTitleLength = options.minTitleLength || 0;
    var maxTitleLength = options.maxTitleLength || Infinity;
    var dedupe = options.dedupe !== false;

    if (typeof selectors === "string") selectors = [selectors];

    function pushCard(node) {
      if (!node || seenCards.indexOf(node) !== -1) return;
      seenCards.push(node);
      cards.push(node);
    }

    function candidateKeys(candidate, card, link) {
      var keys;
      if (options.keyBuilder) keys = options.keyBuilder(candidate, card, link);
      if (keys === null || keys === undefined) keys = [candidate.text + "|" + (candidate.url || "")];
      if (!Array.isArray(keys)) keys = [keys];
      return keys.filter(Boolean);
    }

    selectors.forEach(function(selector) {
      Array.prototype.forEach.call(root.querySelectorAll(selector), pushCard);
    });

    if (!selectors.length && root.querySelectorAll) pushCard(root);

    cards.forEach(function(card) {
      if (items.length >= maxItems) return;

      var link = options.linkBuilder ? options.linkBuilder(card) : (options.linkSelector ? card.querySelector(options.linkSelector) : null);
      var candidate = options.candidateBuilder ? options.candidateBuilder(card, link) : null;
      var keys;

      if (!candidate) return;
      candidate.text = normalizeText(candidate.text || "");
      candidate.url = candidate.url || "";
      var candidateMinTitleLength = typeof minTitleLength === "function" ? minTitleLength(candidate.text) : minTitleLength;
      if (!candidate.text || candidate.text.length < candidateMinTitleLength || candidate.text.length > maxTitleLength) return;
      if (!options.allowMissingUrl && !candidate.url) return;
      if (options.rejectCandidate && options.rejectCandidate(candidate, card, link)) return;
      if (candidate.detail === undefined && options.detailBuilder) candidate.detail = options.detailBuilder(card, candidate, link);

      keys = candidateKeys(candidate, card, link);
      if (dedupe && keys.some(function(key) { return seenCandidates[key]; })) return;
      if (dedupe) keys.forEach(function(key) { seenCandidates[key] = true; });
      items.push(candidate);
    });

    return items;
  }

  function extractListItems(root) {
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll("tr.athing, tr[data-id][data-url*='/remote-jobs/'], article, li, section, .item, .story, .post, .entry, .news, .headline, .feed-item, [class*='card'], [class*='result'], [class*='teaser'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic-list'], [class*='job-card' i], [data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-url*='/remote-jobs/'], .structItem, .discussionListItem"));
    var seen = {};
    var candidates = [];
    var context = listPageContext();
    var caseRecordContext = /\b(?:cases?|defendants?|records?|dockets?|matters?)\b/i.test([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" "));

    function looksLikeMetaLink(text, href) {
      return text.length < (caseRecordContext ? 3 : 18) ||
        /^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;
      if (looksLikeMetaLink(candidate.text, candidate.url)) return;

      pushUniqueListCandidate(candidates, seen, candidate);
    }

    function bestLink(node) {
      var headingLink = node.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4");
      if (headingLink) return headingLink.closest("a[href]") || headingLink;

      var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
      links = links.filter(function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return text && !looksLikeFooterLink(text, link.getAttribute("href") || "") && !listChromeNode(link) && !listChromeNode(link.parentElement) && !listChromeAncestor(link);
      });
      links.sort(function(a, b) {
        var aText = normalizeText(a.textContent || a.getAttribute("aria-label") || "");
        var bText = normalizeText(b.textContent || b.getAttribute("aria-label") || "");
        return bText.length - aText.length;
      });
      return links[0] || null;
    }

    itemNodes.forEach(function(node) {
      pushLink(bestLink(node), node);
    });

    if (candidates.length < 5) {
      var anchors = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent);
        var href = link.getAttribute("href");
        if (!href || href[0] === "#") return false;
        if (/^(javascript:|mailto:)/i.test(href)) return false;
        if (looksLikeMetaLink(text, href)) return false;
        return text.length >= minimumListTitleLength(text) && text.length <= 220;
      });

      anchors.forEach(function(link) {
        pushLink(link, link.closest("tr, li, article, section, div") || link.parentElement);
      });
    }

    candidates.sort(listCandidateRank);

    return candidates;
  }

  function extractFallbackHeadlineItems(node) {
    if (!node || !node.querySelectorAll) return [];

    var seen = {};
    var ranked = [];
    var context = listPageContext();
    var selectors = [
      "h1 a[href]",
      "h2 a[href]",
      "h3 a[href]",
      "h4 a[href]",
      "article a[href]",
      "section a[href]",
      "[class*='headline'] a[href]",
      "[class*='story'] a[href]",
      "[class*='post'] a[href]",
      "[class*='news'] a[href]",
      "[class*='feed'] a[href]",
      "[class*='teaser'] a[href]",
      "[class*='result'] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("article, section, li, div") || link.parentElement;

      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;

      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;

      pushUniqueListCandidate(ranked, seen, candidate);
    });

    ranked.sort(listCandidateScoreRank);

    return ranked;
  }

  function listItemsQualityScore(items) {
    return (items || []).reduce(function(total, item, index) {
      var value = Math.max(0, item && item.score ? item.score : textLength(item && item.text));
      value = Math.min(value, 1200);
      if (index >= 8) value = Math.round(value / 2);
      return total + value;
    }, 0);
  }
  function cleanupListRoot(root) {
    cleanupCookieChrome(root);
    stripTrackingPixels(root);
    resolveLazyImages(root);
    stripUIWidgets(root);
    stripNavigationLeaks(root);

    root.querySelectorAll("header, footer, nav, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("section, div, aside, form, ul, ol").forEach(function(el) {
      if (listChromeNode(el)) el.remove();
    });

    root.querySelectorAll('a[href^="#"]').forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text || /^skip\s+(to\s+)?/i.test(text)) el.remove();
    });

    root.querySelectorAll("a, button").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(sign in|log in|login|register|subscribe|newsletter|follow us|follow|join now|create account|my account|account|menu|search)$/i.test(text)) el.remove();
    });

    return root;
  }
  function listDescriptionMarkdown(root) {
    var descParts = [];
    root.querySelectorAll("h1, h2, h3, p").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (text.length >= 30 && text.length <= 2000) {
        if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
        var links = el.querySelectorAll("a[href]").length;
        var words = text.split(/\s+/).length;
        if (links <= 1 || (links / words) < 0.3) {
          var prefix = /^H[123]$/.test(el.tagName) ? "## " : "";
          descParts.push(prefix + text);
        }
      }
    });
    return descParts.slice(0, 8).join("\n\n");
  }
  function buildListExtraction(node) {
    var root = cleanClone(node);
    cleanupListRoot(root);
    var items = extractListItems(root);
    var itemQuality = listItemsQualityScore(items);
    var descText = listDescriptionMarkdown(root);
    var fallbackItems = extractFallbackHeadlineItems(node);
    var fallbackQuality = listItemsQualityScore(fallbackItems);
    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
    }
    var linkMarkdown = listMarkdown(items);
    var markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;

    if (normalizeText(markdown).length < 120) {
      if (fallbackItems.length > items.length || fallbackQuality > itemQuality) {
        items = fallbackItems;
        itemQuality = fallbackQuality;
        linkMarkdown = listMarkdown(items);
        markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
      }
    }

    return {
      root: root,
      items: items,
      descText: descText,
      markdown: markdown,
      score: itemQuality + (items.length * 80) + Math.min(descText.length, 4000)
    };
  }

  function listMarkdown(items) {
    return items.map(function(item) {
      var line = item.url ? "- [" + item.text + "](" + item.url + ")" : "- " + item.text;
      if (item.detail) line += " - " + item.detail;
      return line;
    }).join("\n");
  }
  function listContent(metadata) {
    var candidates = [];

    function pushCandidate(node) {
      if (!node || candidates.indexOf(node) !== -1) return;
      candidates.push(node);
    }

    pushCandidate(listCandidateRoot(metadata));
    contextualListCandidates(metadata).forEach(pushCandidate);
    pushCandidate(document.querySelector("main, [role='main']"));
    pushCandidate(document.body);

    var best = candidates.reduce(function(current, node) {
      var result = buildListExtraction(node);
      if (!current || result.score > current.score) return result;
      return current;
    }, null) || buildListExtraction(document.body);

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items
    });
  }
