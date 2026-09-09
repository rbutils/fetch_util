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
      genericListAnchorCardSelector(),
      "tr.athing", "tr[data-id][data-url*='/remote-jobs/']", "article", "li", "section",
      ".item", ".story", ".post", ".entry", ".news", ".headline", ".feed-item",
      "[class*='card' i]", "a[href][class*='item' i]", "[class*='result' i]", "[class*='teaser' i]", "[class*='news' i]",
      "[class*='headline' i]", "[class*='feed' i]", "[class*='thread' i]", "[class*='topic-list' i]",
      "[class*='job-card' i]", "[data-testid='slider_container']", "[data-test='jobListing']",
      "[data-jobid]", "[data-url*='/remote-jobs/']", ".structItem", ".discussionListItem"
    ].join(", ");
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll(itemSelector));
    var seen = {};
    var candidates = [];
    var sourceNodes = new Map();
    var acceptedLinks = new Set();
    var context = listPageContext();
    var tableIndexSource = linkedTableIndexRoot();
    context.tableIndexPage = !!tableIndexSource;
    var pageIdentity = [location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ");
    var caseRecordContext = /\b(?:cases?|defendants?|records?|dockets?|matters?)\b/i.test(pageIdentity);

    function looksLikeMetaLink(text, href, container, directAnchorCard, link) {
      var tableRow = context.tableIndexPage && container && container.matches && container.matches("tr");
      var chromeOwnedCard = !!(link && container && container.parentElement &&
        container.parentElement.__fetchUtilChromeOwnedListRecords && genericListStructuredCardLink(container) === link);
      var anchorMinimum = minimumListTitleLength(text);
      if (directAnchorCard && genericListWrappedAnchorCard(link)) anchorMinimum = Math.min(6, anchorMinimum);
      var minimumLength = tableRow ? 2 : (directAnchorCard || chromeOwnedCard ? anchorMinimum : (caseRecordContext ? 3 : 18));
      if (link && genericListLinkGroup(link, context.linkGroups)) minimumLength = 1;
      return text.length < minimumLength ||
        genericListControlText(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      if (acceptedLinks.has(link)) return;
      var candidate = listLinkCandidate(link, container, context, true);
      var href = candidate && (candidate.url || (link && link.getAttribute("href")) || "");
      var directAnchorCard = genericListDirectAnchorCard(link, container) ||
        !!(candidate && genericListPairedMediaCard(link) === candidate.card);
      if (!candidate || looksLikeMetaLink(candidate.text, href, container, directAnchorCard, link)) return;
      candidate.sourceNode = link;
      addCardContext(candidate, candidate.card);
      if (pushUniqueListCandidate(candidates, seen, candidate)) {
        sourceNodes.set(candidate, link);
        acceptedLinks.add(link);
      }
    }

    function bestLink(node) {
      if (node.matches("a[href]")) return genericListCardBoundary(node) ? node : null;
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
          tableCells: dataRow.cells,
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

    // Recognizing one collection must not disable discovery of the other records.
    var anchors = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent);
      var href = link.getAttribute("href");
      if (!href || href[0] === "#") return false;
      var tableRow = context.tableIndexPage && link.closest("tr");
      if (looksLikeMetaLink(text, href, tableRow, false, link)) return false;
      return text.length <= 220;
    });
    anchors.forEach(function(link) {
      var container = link.closest("tr, li, article, figure, section, div") || link.parentElement;
      pushLink(link, container);
    });
    extractFallbackHeadlineItems(root, context).forEach(function(candidate) {
      if (acceptedLinks.has(candidate.sourceNode)) return;
      if (pushUniqueListCandidate(candidates, seen, candidate)) sourceNodes.set(candidate, candidate.sourceNode);
    });
    candidates.sort(function(a, b) {
      var position = sourceNodes.get(a).compareDocumentPosition(sourceNodes.get(b));
      return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0;
    });

    Object.defineProperty(candidates, "__fetchUtilSupportingLinks", { value: context.supportingLinks });
    return candidates;
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
          if (!homepageRootPath()) recordRoot.querySelectorAll("ul, ol, [role='list'], [class*='listing' i], [class*='grid' i], [class*='feed' i], [class*='results' i]").forEach(function(collection) {
            if (!listNoiseNode(collection)) return;
            var nestedRecords = Array.prototype.some.call(collection.querySelectorAll(genericListCardSelector()), function(card) {
              return !!genericListStructuredCardLink(card);
            });
            if (nestedRecords) collection.remove();
          });
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

  function listDescriptionOwnerCard(item) {
    var card = item && item.card;
    var itemUrl = materializedHttpUrl(item && item.url);
    if (!card || !itemUrl) return null;
    var primary = genericListStructuredCardLink(card);
    if (!primary || listCanonicalKey(materializedHttpUrl(primary.getAttribute("href")) || "") !== listCanonicalKey(itemUrl)) {
      return null;
    }
    if (item.contentCard) return item.contentCard;
    var headingUrls = {};
    cardOwnedNodes(card, "h1 a[href], h2 a[href], h3 a[href], h4 a[href]").forEach(function(link) {
      if (elementSubtreeHidden(link)) return;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (url) headingUrls[listCanonicalKey(url)] = true;
    });
    if (Object.keys(headingUrls).length !== 1) return null;
    var proseCount = cardOwnedNodes(card, "p").filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 24;
    }).length;
    if (!card.matches("article, [class~='story' i], [itemtype*='Article']") && proseCount < 2) return null;
    return card;
  }

  function listDescriptionItemValues(item, primaryUrls) {
    if (!item) return [];
    var values = [item.text].concat(listItemContextValues(item, primaryUrls));
    var ownerCard = listDescriptionOwnerCard(item);
    if (ownerCard) {
      var rendered = values.join("\n");
      cardOwnedNodes(ownerCard, "p, blockquote").forEach(function(block) {
        if (elementSubtreeHidden(block)) return;
        var expected = listTextWithReferences(block, false, item.url);
        if (expected && rendered.indexOf(expected) >= 0) values.push(block.textContent || "");
      });
    }
    return values.map(normalizeText).filter(Boolean);
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

  function listDescriptionReferencesRepresented(node, values, primaryReferences) {
    return Array.prototype.every.call(node.querySelectorAll("a[href]"), function(link) {
      if (listCardNodeHidden(link)) return true;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url) return true;
      if (primaryReferences && primaryReferences.has(url)) return true;
      return values.some(function(value) { return value.indexOf(url) >= 0; });
    });
  }

  function listDescriptionCardNode(node, items, options, itemValues, primaryReferences) {
    if (!items) return closestGenericListCard(node);

    var text = normalizeText(node.textContent || "");
    var represented = text && items.find(function(item, index) {
      var values = itemValues[index];
      return values.some(function(value) {
        return value === text || value.indexOf(text) >= 0;
      }) && listDescriptionReferencesRepresented(node, values, primaryReferences);
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

    if (options && options.preserveUnrepresentedText) return null;
    return listDescriptionDuplicateCard(node, items);
  }
