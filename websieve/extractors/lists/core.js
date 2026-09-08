  function listCandidateRank(a, b) {
    return b.rankScore - a.rankScore || b.text.length - a.text.length;
  }

  function listCandidateScoreRank(a, b) {
    return b.rankScore - a.rankScore;
  }

  function sameRootListRecordKey(item) {
    var url = materializedHttpUrl(item && item.url);
    var identity = url ? listCanonicalKey(url) : ((item && item.canonicalKey) || "");
    return JSON.stringify([
      identity,
      normalizeText(item && item.text || ""),
      normalizeText(item && item.detail || "")
    ]);
  }

  function sameRootCanonicalDestinations(items) {
    var destinations = {};
    (items || []).forEach(function(item) {
      var url = materializedHttpUrl(item && item.url);
      if (url) destinations[listCanonicalKey(url)] = true;
    });
    return Object.keys(destinations);
  }

  function sameRootFlatSectionCoverage(sectioned, flatItems) {
    if (!sectioned || sectioned.items.length * 2 >= flatItems.length) return null;

    var sectionDestinations = sameRootCanonicalDestinations(sectioned.items);
    var flatDestinations = sameRootCanonicalDestinations(flatItems);
    if (!sectionDestinations.length || sectionDestinations.length * 2 >= flatDestinations.length) return null;

    var flatKeys = flatItems.map(sameRootListRecordKey);
    var cursor = 0;
    var replacements = {};
    var headings = {};
    var complete = sectioned.regions.every(function(region) {
      var firstIndex = null;
      var regionComplete = region.cards.every(function(item) {
        var key = sameRootListRecordKey(item);
        while (cursor < flatKeys.length && flatKeys[cursor] !== key) cursor += 1;
        if (cursor >= flatKeys.length) return false;
        replacements[cursor] = item;
        if (firstIndex === null) firstIndex = cursor;
        cursor += 1;
        return true;
      });
      if (regionComplete && region.label && firstIndex !== null) {
        if (!headings[firstIndex]) headings[firstIndex] = [];
        headings[firstIndex].push(region.label);
      }
      return regionComplete;
    });
    if (!complete) return null;

    var unmatchedCount = flatItems.length - Object.keys(replacements).length;
    var unmatchedCards = [];
    flatItems.forEach(function(item, index) {
      if (replacements[index] || !item.card) return;
      var owner = unmatchedCards.find(function(entry) { return entry.card === item.card; });
      if (owner) owner.count += 1;
      else unmatchedCards.push({ card: item.card, count: 1 });
    });
    if (unmatchedCards.some(function(entry) { return entry.count * 2 >= unmatchedCount; })) return null;

    return {
      items: flatItems.map(function(item, index) { return replacements[index] || item; }),
      headings: headings
    };
  }

  function sameRootFlatListMarkdown(items, headings) {
    return items.map(function(item, index) {
      var blocks = (headings[index] || []).map(function(heading) { return "## " + heading; });
      blocks.push(listMarkdown([item]));
      return blocks.join("\n\n");
    }).join("\n");
  }

  function supplementalSameRootSectionCoverage(sectioned, flatItems, fallbackItems, root, pageTitles) {
    if (!sectioned || !sectioned.items.length) return null;
    var key = function(item) { return item.dedupeKey || listCanonicalKey(item.url || ""); };
    var nodes = Array.from(root.querySelectorAll("a[href], h1, h2, h3, h4, h5, h6"));
    var sourcePosition = function(item) {
      var node = item.sourceNode;
      if (!node || !root.contains(node)) node = nodes.find(function(candidate) {
        return candidate.tagName === "A" && (!item.card || item.card.contains(candidate)) &&
          listCanonicalKey(materializedHttpUrl(candidate.getAttribute("href")) || "") === listCanonicalKey(item.url || "");
      });
      return nodes.indexOf(node);
    };
    var represented = new Set(sectioned.items.map(key));
    var representedPositions = new Set(sectioned.items.map(sourcePosition));
    var additions = [];
    flatItems.concat(fallbackItems).forEach(function(item) {
      if (!materializedHttpUrl(item.url) || represented.has(key(item))) return;
      var position = sourcePosition(item);
      if (position >= 0 && representedPositions.has(position)) return;
      represented.add(key(item));
      representedPositions.add(position);
      additions.push(item);
    });
    if (!additions.length) return null;
    if (additions.length === 1 && (!additions[0].card || additions[0].card === root)) return null;
    var owners = new Map();
    additions.forEach(function(item) {
      if (item.card && item.groupLabel == null) owners.set(item.card, (owners.get(item.card) || 0) + 1);
    });
    if (Array.from(owners.values()).some(function(count) { return count > 1 && count * 2 >= additions.length; })) return null;
    var localParagraphs = new Set();
    var completeItems = sectioned.items.concat(additions).map(function(item) {
      if (!item.card || genericListCardBoundary(item.card) || item.groupLabel != null ||
          sameRootCanonicalDestinations(Array.from(item.card.querySelectorAll("a[href]")).map(function(link) {
            return { url: materializedHttpUrl(link.getAttribute("href")) };
          })).length < 2) return item;
      var link = nodes.find(function(node) {
        return node.tagName === "A" && item.card.contains(node) &&
          listCanonicalKey(materializedHttpUrl(node.getAttribute("href")) || "") === listCanonicalKey(item.url || "");
      });
      var paragraph = link && link.closest("p");
      if (!paragraph || !item.card.contains(paragraph) || paragraph.querySelectorAll("a[href]").length !== 1) return item;
      if (genericListStructuredCardLink(item.card) === link) return item;
      // Inline prose belongs to its paragraph, not the shared collection's introduction.
      var local = { text: item.text, url: item.url, dedupeKey: item.dedupeKey, card: paragraph, sourceNode: link };
      addCardContext(local, paragraph);
      localParagraphs.add(paragraph);
      return local;
    });
    var entries = completeItems.map(function(item) {
      return { item: item, position: sourcePosition(item) };
    });
    if (entries.some(function(entry) { return entry.position < 0; })) return null;
    entries.sort(function(a, b) { return a.position - b.position; });
    var items = entries.map(function(entry) { return entry.item; });
    var headings = {};
    sectioned.regions.forEach(function(region) {
      var index = items.findIndex(function(item) { return key(item) === key(region.cards[0]); });
      if (region.label && index >= 0) {
        if (!headings[index]) headings[index] = [];
        headings[index].push(region.label);
      }
    });
    var descriptions = listDescriptionParts(root, items, {
      includeInlineProse: true, preserveTextLengths: true,
      pageTitles: pageTitles, preserveUnrepresentedText: true
    }).filter(function(part) { return !localParagraphs.has(part.node); });
    return { items: items, headings: headings,
      markdown: sectionedListMarkdownWithDescriptions({
        regions: [{ node: root, label: "", cards: items }]
      }, descriptions) || sameRootFlatListMarkdown(items, headings) };
  }

  function buildListExtraction(node, pageTitles, options) {
    options = options || {};
    var root = visibleListClone(node, options.preservedRoots);
    cleanupListRoot(root);
    var sectioned = sectionedListExtraction(root);

    var items = extractListItems(root);
    var itemQuality = listItemsQualityScore(items);
    var descText = listDescriptionMarkdown(root);
    var fallbackItems = extractFallbackHeadlineItems(root);
    var fallbackQuality = listItemsQualityScore(fallbackItems);
    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
    }

    var flatCoverage = sameRootFlatSectionCoverage(sectioned, items) ||
      supplementalSameRootSectionCoverage(sectioned, items, fallbackItems, root, pageTitles);
    if (sectioned && !flatCoverage) {
      var sectionDescriptionParts = listDescriptionParts(root, sectioned.items, {
        excludeRecordCards: true,
        includeInlineProse: true,
        pageTitles: pageTitles,
        preserveTextLengths: true,
        sectionLabels: sectioned.regions.map(function(region) { return region.label; }),
        suppressRepresentedText: true
      });
      var sectionMarkdownWithDescription = sectionedListMarkdownWithDescriptions(sectioned, sectionDescriptionParts);

      return {
        sourceNode: node,
        root: root,
        items: sectioned.items,
        descText: "",
        sectionMarkdownWithDescription: sectionMarkdownWithDescription,
        markdown: sectioned.markdown,
        score: sectioned.score,
        sectionCount: sectioned.regions.length,
        sectionRank: (sectioned.regions.length * 100000) - root.querySelectorAll("a[href]").length
      };
    }
    if (flatCoverage) items = flatCoverage.items;

    var itemMarkdown = flatCoverage ? sameRootFlatListMarkdown(items, flatCoverage.headings) : listMarkdown(items);
    var markdown = descText ? descText + (itemMarkdown ? "\n\n" + itemMarkdown : "") : itemMarkdown;
    if (flatCoverage && flatCoverage.markdown) markdown = flatCoverage.markdown;
    if (!flatCoverage && normalizeText(markdown).length < 120 &&
        (fallbackItems.length > items.length || fallbackQuality > itemQuality)) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
      markdown = listMarkdownWithDescription(descText, items);
    }

    return {
      sourceNode: node,
      root: root,
      items: items,
      descText: descText,
      markdown: markdown,
      score: flatCoverage ? sectioned.score :
        itemQuality + (items.length * 80) + Math.min(descText.length, 4000),
      sectionCount: flatCoverage ? sectioned.regions.length : 0,
      sectionRank: flatCoverage ?
        (sectioned.regions.length * 100000) - root.querySelectorAll("a[href]").length : 0,
      portalEvidenceItemCount: flatCoverage ? sectioned.items.length : null,
      portalEvidenceMaterializedItemCount: flatCoverage ? materializedListItemCount(sectioned.items) : null
    };
  }

  function bestListExtraction(metadata, pageTitles, options) {
    options = options || {};
    var candidates = [];
    function pushCandidate(node) {
      if (!node || candidates.indexOf(node) !== -1) return;
      candidates.push(node);
    }

    pushCandidate(listCandidateRoot(metadata));
    contextualListCandidates(metadata).forEach(pushCandidate);
    pushCandidate(document.querySelector("main, [role='main']"));
    pushCandidate(document.body);

    var tableIndexRoot = linkedTableIndexRoot();
    return tableIndexRoot ? buildListExtraction(tableIndexRoot, pageTitles, options) : candidates.reduce(function(current, node) {
      var result = buildListExtraction(node, pageTitles, options);
      return listExtractionIsBetter(current, result) ? result : current;
    }, null) || buildListExtraction(document.body, pageTitles, options);
  }

  function listContent(metadata, options) {
    options = options || {};
    var pageTitles = [metadata.title, document.title];
    var best = bestListExtraction(metadata, pageTitles, options);
    var rankedMarkdown = best.markdown;
    if (!best.sectionCount) {
      best.descText = listDescriptionMarkdown(best.root, best.items);
      best.markdown = listMarkdownWithDescription(best.descText, best.items);
    }
    var namedHeadingCount = Array.prototype.filter.call(best.root.querySelectorAll("h2, h3, h4"), function(heading) {
      return !heading.closest("article, li, [class*='card' i], [class*='item' i]");
    }).length;
    var rootContext = normalizeText([location.pathname, document.title, metadata.title].join(" "));
    var docsRoot = /\b(?:docs?|documentation|api|library|libraries|reference|class|module|namespace|package)\b/i.test(rootContext);
    var substantialRoot = homepageRootPath() && !docsRoot && best.items.length >= 10 && normalizeText(rankedMarkdown).length >= 3000;
    var broadRootEvidence = substantialRoot ? 2 : 0;
    var headingRootEvidence = substantialRoot ? namedHeadingCount : 0;
    var portalSectionCount = Math.max(best.sectionCount || 0, headingRootEvidence, broadRootEvidence);
    var portalEvidenceItemCount = best.portalEvidenceItemCount == null ? best.items.length : best.portalEvidenceItemCount;
    var materializedItemCount = best.portalEvidenceMaterializedItemCount == null ? best.items.filter(function(item) {
      return !!materializedHttpUrl(item && item.url);
    }).length : best.portalEvidenceMaterializedItemCount;

    var result = listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items,
      portalRootEvidence: options.portalRoot && portalSectionCount >= 2 && portalEvidenceItemCount >= 4 && materializedItemCount >= 2 ? {
        namedSectionCount: portalSectionCount,
        canonicalCardCount: portalEvidenceItemCount
      } : null
    });
    result.listExtraction = best;
    if (best.sectionMarkdownWithDescription) result.sectionMarkdownWithDescription = best.sectionMarkdownWithDescription;
    return result;
  }
