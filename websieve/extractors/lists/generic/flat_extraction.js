  function listElementHidden(node) {
    return elementSubtreeHidden(node);
  }

  function pruneHiddenListClone(source, clone) {
    if (!source || !clone) return;
    if (source.nodeType === 1 && listElementHidden(source)) {
      clone.remove();
      return;
    }

    var visibilityHidden = source.nodeType === 1 && elementVisuallyHidden(source);
    var sourceChildren = Array.prototype.slice.call(source.childNodes || []);
    var cloneChildren = Array.prototype.slice.call(clone.childNodes || []);
    sourceChildren.forEach(function(child, index) {
      var childClone = cloneChildren[index];
      if (!childClone) return;
      if (visibilityHidden && child.nodeType !== 1) {
        childClone.remove();
        return;
      }
      pruneHiddenListClone(child, childClone);
    });

    if (visibilityHidden) {
      ["aria-label", "title", "alt", "value"].forEach(function(attribute) {
        clone.removeAttribute(attribute);
      });
      if (!clone.children.length) clone.remove();
    }
  }

  function visibleListClone(node) {
    if (!node || listElementHidden(node)) return document.createElement("div");
    var clone = safeDeepClone(node, document);
    if (node.matches && node.matches("table")) tableIndexAnnotateClone(node, clone);
    pruneHiddenListClone(node, clone);
    return cleanClone(clone);
  }

  function extractListItems(root) {
    var itemSelector = [
      "tr.athing", "tr[data-id][data-url*='/remote-jobs/']", "article", "li", "section",
      ".item", ".story", ".post", ".entry", ".news", ".headline", ".feed-item",
      "[class*='card']", "[class*='result']", "[class*='teaser']", "[class*='news']",
      "[class*='headline']", "[class*='feed']", "[class*='thread']", "[class*='topic-list']",
      "[class*='job-card' i]", "[data-testid='slider_container']", "[data-test='jobListing']",
      "[data-jobid]", "[data-url*='/remote-jobs/']", ".structItem", ".discussionListItem"
    ].join(", ");
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll(itemSelector));
    var seen = {};
    var candidates = [];
    var context = listPageContext();
    var tableIndexSource = linkedTableIndexRoot();
    context.tableIndexPage = !!tableIndexSource;
    var pageIdentity = [location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ");
    var caseRecordContext = /\b(?:cases?|defendants?|records?|dockets?|matters?)\b/i.test(pageIdentity);

    function looksLikeMetaLink(text, href, container) {
      var tableRow = context.tableIndexPage && container && container.matches && container.matches("tr");
      return text.length < (tableRow ? 2 : (caseRecordContext ? 3 : 18)) ||
        /^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate || looksLikeMetaLink(candidate.text, candidate.url, container)) return;
      pushUniqueListCandidate(candidates, seen, candidate);
    }

    function bestLink(node) {
      var headingLink = node.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4");
      if (headingLink) return headingLink.closest("a[href]") || headingLink;

      var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
      links = links.filter(function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return text &&
          !looksLikeFooterLink(text, link.getAttribute("href") || "") &&
          !listChromeNode(link) &&
          !listChromeNode(link.parentElement) &&
          !listChromeAncestor(link);
      });
      links.sort(function(a, b) {
        var aText = normalizeText(a.textContent || a.getAttribute("aria-label") || "");
        var bText = normalizeText(b.textContent || b.getAttribute("aria-label") || "");
        return bText.length - aText.length;
      });
      return links[0] || null;
    }

    if (context.tableIndexPage && root.matches && root.matches("table")) {
      var primaryColumn = tableIndexPrimaryColumn(tableIndexSource);
      var dataRows = tableIndexMappedDataRows(tableIndexSource, root) || tableIndexDataRows(root);
      tableIndexClearCloneAnnotations(root);
      dataRows.forEach(function(dataRow) {
        var row = dataRow.row;
        var primary = tableIndexPrimaryLink(row, dataRow.cells, 2, primaryColumn);
        if (!primary) return;

        var text = normalizeText(primary.link.textContent || primary.link.getAttribute("aria-label") || "");
        var detail = listTableRowDetail(row, text, dataRow.cells);
        var candidate = {
          text: text,
          url: primary.url,
          detail: detail,
          rankScore: text.length + detail.length,
          card: row,
          canonicalKey: primary.url,
          dedupeKey: primary.url + "|row:" + normalizeText(detail).toLowerCase()
        };
        pushUniqueListCandidate(candidates, seen, candidate);
      });
      return candidates;
    }

    itemNodes.forEach(function(node) {
      if (!node.matches("tr") && node.querySelectorAll("tr a[href]").length >= 2) return;
      pushLink(bestLink(node), node);
    });

    if (candidates.length < 5) {
      var anchors = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent);
        var href = link.getAttribute("href");
        if (!href || href[0] === "#" || /^(javascript:|mailto:)/i.test(href)) return false;
        var tableRow = context.tableIndexPage && link.closest("tr");
        if (text.length < (tableRow ? 2 : minimumListTitleLength(text))) return false;
        if (looksLikeMetaLink(text, href, tableRow)) return false;
        return (tableRow || text.length >= minimumListTitleLength(text)) && text.length <= 220;
      });
      anchors.forEach(function(link) {
        var container = link.closest("tr, li, article, section, div") || link.parentElement;
        pushLink(link, container);
      });
    }

    return candidates;
  }

  function extractFallbackHeadlineItems(node) {
    if (!node || !node.querySelectorAll) return [];
    var seen = {};
    var ranked = [];
    var context = listPageContext();
    context.tableIndexPage = !!linkedTableIndexRoot();
    var selectors = [
      "h1 a[href]", "h2 a[href]", "h3 a[href]", "h4 a[href]", "article a[href]",
      "section a[href]", "[class*='headline'] a[href]", "[class*='story'] a[href]",
      "[class*='post'] a[href]", "[class*='news'] a[href]", "[class*='feed'] a[href]",
      "[class*='teaser'] a[href]", "[class*='result'] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("tr, article, section, li, div") || link.parentElement;
      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;
      var candidate = listLinkCandidate(link, container, context);
      if (candidate) pushUniqueListCandidate(ranked, seen, candidate);
    });
    return ranked;
  }

  function listItemsQualityScore(items) {
    return (items || []).reduce(function(total, item, index) {
      var value = Math.max(0, item && item.rankScore ? item.rankScore : textLength(item && item.text));
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
      if (text.length < 30 || text.length > 2000) return;
      if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (links <= 1 || (links / words) < 0.3) {
        var prefix = /^H[123]$/.test(el.tagName) ? "## " : "";
        descParts.push(prefix + text);
      }
    });
    return descParts.join("\n\n");
  }
