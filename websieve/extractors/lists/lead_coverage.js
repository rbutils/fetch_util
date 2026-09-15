  function supplementedHomepageLead(lead, content) {
    var extraction = content && content.listExtraction;
    if (!lead || !extraction || extraction.sourceNode !== lead.root || !extraction.items.length) return null;
    var root = extraction.root;
    var links = Array.from(root.querySelectorAll("a[href]"));
    var retained = new Set();
    var items = [];
    var representedDetails = [];
    for (var index = 0; index < lead.items.length; index += 1) {
      var item = lead.items[index];
      var counterparts = extraction.items.filter(function(candidate) { return candidate.url === item.url; });
      if (counterparts.length > 1) return null;
      var matches = links.filter(function(link) {
        return materializedHttpUrl(link.getAttribute("href")) === item.url &&
          normalizeText(link.textContent || link.getAttribute("aria-label")) === normalizeText(item.text);
      });
      if (!matches.length && counterparts.length && counterparts[0].text === item.text &&
          counterparts[0].sourceNode && root.contains(counterparts[0].sourceNode) &&
          materializedHttpUrl(counterparts[0].sourceNode.getAttribute("href")) === item.url) {
        matches = [counterparts[0].sourceNode];
      }
      if (matches.length !== 1 || retained.has(item.url)) return null;
      if (counterparts.length && counterparts[0].card && counterparts[0].card.contains(matches[0])) {
        representedDetails.push({ card: counterparts[0].card, text: normalizeText(item.detail) });
      }
      retained.add(item.url);
      items.push(Object.assign({}, item, { sourceNode: matches[0] }));
    }
    var additions = extraction.items.filter(function(item) { return !retained.has(item.url); });
    if (!additions.length) return null;
    for (var additionIndex = 0; additionIndex < additions.length; additionIndex += 1) {
      var addition = additions[additionIndex];
      var card = addition.card;
      if (!addition.sourceNode || addition.sourceNode.tagName !== "A" || !card || card === root ||
          !root.contains(card) || !card.contains(addition.sourceNode) || genericListPageContainer(card)) return null;
      var cardLinks = card.matches("a[href]") ? [card] : Array.from(card.querySelectorAll("a[href]"));
      var destinations = cardLinks.map(function(link) {
        return materializedHttpUrl(link.getAttribute("href"));
      });
      if (!destinations.length || destinations.some(function(url) { return !url || url !== addition.url; })) return null;
      items.push(addition);
    }
    var descriptions = listDescriptionParts(root, extraction.items, {
      includeInlineProse: true, preserveTextLengths: true, preserveUnrepresentedText: true
    }).filter(function(part) {
      var text = normalizeText(part.node.textContent);
      return !elementSubtreeHidden(part.node) && !items.some(function(item) {
        return normalizeText(item.text) === text &&
          (item.sourceNode.contains(part.node) || part.node.contains(item.sourceNode));
      }) && !representedDetails.some(function(detail) {
        return text && detail.card.contains(part.node) && detail.text.indexOf(text) !== -1;
      });
    });
    if (!descriptions.some(function(part) { return !/^#{1,6}\s/.test(part.markdown); })) return null;
    items.sort(function(left, right) {
      var position = left.sourceNode.compareDocumentPosition(right.sourceNode);
      return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0;
    });
    return { items: items, markdown: sectionedListMarkdownWithDescriptions({
      regions: [{ node: root, label: "", cards: items }]
    }, descriptions) };
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

  function sameRootSupplementalAliasKey(item) {
    var url = materializedHttpUrl(item && item.url);
    return JSON.stringify([url && listCanonicalKey(url) || "", normalizeText(item && item.text || "").toLowerCase()]);
  }

  function sameRootHeadingDestinationCount(card) {
    if (!card || !card.querySelectorAll) return 0;
    var destinations = {};
    Array.prototype.forEach.call(card.querySelectorAll("h1 a[href], h2 a[href], h3 a[href], h4 a[href]"), function(link) {
      if (elementSubtreeHidden(link)) return;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (url) destinations[listCanonicalKey(url)] = true;
    });
    return Object.keys(destinations).length;
  }

  function sameRootSectionHeadingItem(item, regions) {
    var source = item && (item.sourceNode || item.card);
    if (!source) return false;
    return regions.some(function(region) {
      if (!region.headingNode) return false;
      if (region.headingNode.contains(source)) return true;
      return source.contains(region.headingNode) && normalizeText(item.text || "") === normalizeText(region.label);
    });
  }

  function sameRootFlatSectionCoverage(sectioned, flatItems) {
    if (!sectioned) return null;
    var contentItems = flatItems.filter(function(item) {
      return !sameRootSectionHeadingItem(item, sectioned.regions);
    });
    if (sectioned.items.length * 2 >= contentItems.length) return null;

    var sectionDestinations = sameRootCanonicalDestinations(sectioned.items);
    var flatDestinations = sameRootCanonicalDestinations(contentItems);
    if (!sectionDestinations.length || sectionDestinations.length * 2 >= flatDestinations.length) return null;

    var flatKeys = contentItems.map(sameRootListRecordKey);
    var cursor = 0;
    var replacements = {};
    var headings = {};
    var headingParts = [];
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
        headings[firstIndex].push(sectionRegionMarkdown(region));
        headingParts.push({ node: region.headingNode || region.node, markdown: "## " + sectionRegionMarkdown(region) });
      }
      return regionComplete;
    });
    if (!complete) return null;

    var unmatchedCount = contentItems.length - Object.keys(replacements).length;
    var unmatchedCards = [];
    contentItems.forEach(function(item, index) {
      if (replacements[index] || !item.card) return;
      var owner = unmatchedCards.find(function(entry) { return entry.card === item.card; });
      if (owner) owner.count += 1;
      else unmatchedCards.push({ card: item.card, count: 1 });
    });
    unmatchedCards.forEach(function(entry) {
      entry.count = Math.max(entry.count, sameRootHeadingDestinationCount(entry.card));
    });
    if (unmatchedCards.some(function(entry) { return entry.count * 2 >= unmatchedCount; })) return null;

    return {
      items: contentItems.map(function(item, index) { return replacements[index] || item; }),
      headings: headings,
      headingParts: headingParts
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
    var representedAliases = new Set(sectioned.items.map(sameRootSupplementalAliasKey));
    var representedPositions = new Set(sectioned.items.map(sourcePosition));
    var additions = [];
    flatItems.concat(fallbackItems).forEach(function(item) {
      if (sameRootSectionHeadingItem(item, sectioned.regions)) return;
      var itemKey = key(item);
      var aliasKey = sameRootSupplementalAliasKey(item);
      var authoredAlias = !!item.author && represented.has(itemKey) && !representedAliases.has(aliasKey);
      if (!materializedHttpUrl(item.url) || (!authoredAlias && represented.has(itemKey))) return;
      var position = sourcePosition(item);
      if (position >= 0 && representedPositions.has(position)) return;
      represented.add(itemKey);
      representedAliases.add(aliasKey);
      representedPositions.add(position);
      additions.push(item);
    });
    if (!additions.length) return null;
    if (additions.length === 1 && (!additions[0].card || additions[0].card === root)) return null;
    var owners = new Map();
    additions.forEach(function(item) {
      if (item.card && item.groupLabel == null) owners.set(item.card, (owners.get(item.card) || 0) + 1);
    });
    if (Array.from(owners.entries()).some(function(entry) {
      var count = Math.max(entry[1], sameRootHeadingDestinationCount(entry[0]));
      return count > 1 && count * 2 >= additions.length;
    })) return null;
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
    mergeDuplicateRecordAuthorContext(root, items);
    var headings = {};
    var headingParts = [];
    sectioned.regions.forEach(function(region) {
      var regionPosition = sourcePosition(region.cards[0]);
      var index = items.findIndex(function(item) {
        return item === region.cards[0] || (regionPosition >= 0 && sourcePosition(item) === regionPosition);
      });
      if (region.label && index >= 0) {
        if (!headings[index]) headings[index] = [];
        headings[index].push(sectionRegionMarkdown(region));
        headingParts.push({ node: region.headingNode || region.node, markdown: "## " + sectionRegionMarkdown(region) });
      }
    });
    var descriptions = listDescriptionParts(root, items, {
      includeInlineProse: true, preserveTextLengths: true,
      pageTitles: pageTitles, preserveUnrepresentedText: true,
      sectionLabels: sectioned.regions.map(function(region) { return region.label; }),
      suppressRepresentedText: true
    }).filter(function(part) { return !localParagraphs.has(part.node); });
    descriptions = headingParts.concat(descriptions);
    var renderedSections = { regions: [{ node: root, label: "", cards: items }] };
    return { items: items, headings: headings, headingParts: headingParts,
      renderedSections: renderedSections, renderedDescriptions: descriptions,
      markdown: sectionedListMarkdownWithDescriptions(renderedSections, descriptions) || sameRootFlatListMarkdown(items, headings) };
  }
