  function listElementHidden(node) {
    return elementSubtreeHidden(node);
  }

  function visibleListClone(node, preservedRoots) {
    if (!node || listElementHidden(node)) return document.createElement("div");
    var clone = safeDeepClone(node, document);
    if (node.matches && node.matches("table")) tableIndexAnnotateClone(node, clone);
    pruneHiddenClone(node, clone, preservedRoots);
    return cleanClone(clone);
  }

  function extractListItems(root) {
    var itemSelector = [
      "tr.athing", "tr[data-id][data-url*='/remote-jobs/']", "article", "li", "section",
      ".item", ".story", ".post", ".entry", ".news", ".headline", ".feed-item",
      "[class*='card' i]", "[class*='result' i]", "[class*='teaser' i]", "[class*='news' i]",
      "[class*='headline' i]", "[class*='feed' i]", "[class*='thread' i]", "[class*='topic-list' i]",
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

    function looksLikeMetaLink(text, href, container, directAnchorCard, link) {
      var tableRow = context.tableIndexPage && container && container.matches && container.matches("tr");
      var chromeOwnedCard = !!(link && container && container.parentElement &&
        container.parentElement.__fetchUtilChromeOwnedListRecords && genericListStructuredCardLink(container) === link);
      var minimumLength = tableRow ? 2 : (directAnchorCard || chromeOwnedCard ? minimumListTitleLength(text) : (caseRecordContext ? 3 : 18));
      return text.length < minimumLength ||
        genericListControlText(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      var candidate = listLinkCandidate(link, container, context, true);
      var href = candidate && (candidate.url || (link && link.getAttribute("href")) || "");
      var directAnchorCard = genericListDirectAnchorCard(link, container);
      if (!candidate || looksLikeMetaLink(candidate.text, href, container, directAnchorCard, link)) return;
      addCardContext(candidate, candidate.card);
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
        var aSafe = !!materializedHttpUrl(a.getAttribute("href"));
        var bSafe = !!materializedHttpUrl(b.getAttribute("href"));
        if (aSafe !== bSafe) return bSafe - aSafe;
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
        var primary = tableIndexPrimaryLink(row, dataRow.cells, 2, primaryColumn, true);
        if (!primary) return;

        var text = normalizeText(primary.link.textContent || primary.link.getAttribute("aria-label") || "");
        var detail = stripGenericListControlPhrases(listTableRowDetail(row, text, dataRow.cells));
        var candidate = {
          text: text,
          url: primary.url,
          detail: detail,
          rankScore: text.length + detail.length,
          card: row,
          canonicalKey: primary.url || "unlinked:" + text.toLowerCase() + "|href:" + primary.href,
          dedupeKey: (primary.url || "unlinked:" + text.toLowerCase() + "|href:" + primary.href) + "|row:" + normalizeText(detail).toLowerCase()
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
        if (!href || href[0] === "#") return false;
        var tableRow = context.tableIndexPage && link.closest("tr");
        if (text.length < (tableRow ? 2 : minimumListTitleLength(text))) return false;
        if (looksLikeMetaLink(text, href, tableRow)) return false;
        return (tableRow || text.length >= minimumListTitleLength(text)) && text.length <= 220;
      });
      anchors.forEach(function(link) {
        var container = link.closest("tr, li, article, figure, section, div") || link.parentElement;
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
      "section a[href]", "[class*='headline' i] a[href]", "[class*='story' i] a[href]",
      "[class*='post' i] a[href]", "[class*='news' i] a[href]", "[class*='feed' i] a[href]",
      "[class*='teaser' i] a[href]", "[class*='result' i] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("tr, article, section, li, div") || link.parentElement;
      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;
      var candidate = listLinkCandidate(link, container, context, true);
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
      if (!listChromeNode(el)) return;
      var recordRoots = genericListChromeOwnedRecordRoots(el);
      if (recordRoots.length && el.parentNode) {
        recordRoots.forEach(function(recordRoot) {
          recordRoot.__fetchUtilChromeOwnedListRecords = true;
          el.parentNode.insertBefore(recordRoot, el);
        });
      }
      el.remove();
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

  function listDescriptionItemValues(item) {
    if (!item) return [];
    return [item.text].concat(listItemContextValues(item)).map(normalizeText).filter(Boolean);
  }

  function listDescriptionDuplicateCard(node, items) {
    var card = closestGenericListCard(node);
    if (!card || items.some(function(item) { return item && item.card === card; })) return null;

    var retained = new Set(items.map(function(item) {
      if (item && item.url) return listCanonicalKey(item.url);
      return item && item.canonicalKey;
    }).filter(Boolean));
    var duplicate = cardOwnedNodes(card, "a[href]").some(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      return url && retained.has(listCanonicalKey(url));
    });
    return duplicate ? card : null;
  }

  function listDescriptionRecordClass(node) {
    return Array.prototype.some.call(node.classList || [], function(className) {
      return /(?:^|[-_])(?:card|story|teaser|item|result|news|post|entry)(?:$|[-_])/i.test(className) ||
        /(?:Card|Story|Teaser|Item|Result|News)(?:$|[A-Z])/.test(className);
    });
  }

  function listDescriptionCardNode(node, items, options, itemValues) {
    if (!items) return closestGenericListCard(node);

    var text = normalizeText(node.textContent || "");
    var represented = text && items.find(function(item, index) {
      return itemValues[index].some(function(value) {
        return value === text || value.indexOf(text) >= 0;
      });
    });
    var recordCard;
    var sectionLabels;

    if (represented) {
      if (represented.card) return represented.card;
      if (options && options.suppressRepresentedText) return node;
    }

    if (options && options.excludeRecordCards) {
      recordCard = closestGenericListCard(node);
      if (recordCard && (recordCard !== node || listDescriptionRecordClass(node))) return recordCard;
    }

    if (options && options.sectionLabels && /^H[1-6]$/.test(node.tagName || "")) {
      sectionLabels = options.sectionLabels.map(function(label) {
        return normalizeText(label).toLowerCase();
      });
      if (sectionLabels.indexOf(text.toLowerCase()) !== -1) return node;
      if (itemValues.some(function(values) {
        return values.some(function(value) {
          return value.length >= 12 && text.indexOf(value) !== -1;
        });
      })) return node;
    }

    return listDescriptionDuplicateCard(node, items);
  }

  function listDescriptionParts(root, items, options) {
    var descParts = [];
    var hasItems = items && items.length > 0;
    var itemValues = items && items.map(listDescriptionItemValues);
    var pageTitles = (options && options.pageTitles || []).map(function(title) {
      return normalizeText(title).toLowerCase();
    }).filter(Boolean);
    root.querySelectorAll(hasItems ? "h1, h2, h3, h4, h5, h6, p" : "h1, h2, h3, p").forEach(function(el) {
      if (listDescriptionCardNode(el, items, options, itemValues)) return;
      var text = normalizeText(el.textContent);
      var heading = /^H[1-6]$/.test(el.tagName);
      var pageHeading = heading && !el.closest("a[href]") && !el.querySelector("a[href]");
      var weatherOwner = pageHeading && el.closest("[class*='weather' i], [id*='weather' i]");
      if (weatherOwner && weatherModuleText(weatherOwner.textContent)) pageHeading = false;
      // Linked record titles keep their existing admission, not page-label treatment.
      if (heading && !pageHeading && !/^H[1-3]$/.test(el.tagName)) return;
      if (heading && pageTitles.indexOf(text.toLowerCase()) !== -1) return;
      if (!(hasItems && pageHeading) && !(options && options.preserveTextLengths) && (text.length < 30 || text.length > 2000)) return;
      if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (links <= 1 || (links / words) < 0.3) {
        var prefix = heading ? "## " : "";
        descParts.push({ node: el, markdown: prefix + text });
      }
    });
    return descParts;
  }

  function listDescriptionMarkdown(root, items, options) {
    return listDescriptionParts(root, items, options).map(function(part) {
      return part.markdown;
    }).join("\n\n");
  }

  function listMarkdownWithDescription(descText, items) {
    var linkMarkdown = listMarkdown(items);
    return descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
  }
