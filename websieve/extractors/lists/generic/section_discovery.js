  function sectionHeading(region, options) {
    if (options && options.headingBuilder) return options.headingBuilder(region);
    var heading = region.querySelector((options && options.headingSelector) || "h1, h2, h3, h4");
    var label = normalizeText(heading && heading.textContent);
    if (!label || label.length > 90 || rejectedHomepageLeadText(label, "")) return "";
    return label;
  }

  function sectionRegionLabel(region, options) {
    var label = sectionHeading(region, options);
    if (!label && options.fallbackHeadingBuilder) label = options.fallbackHeadingBuilder(region);
    return label;
  }

  function nestedSectionHeadingOwner(region, options) {
    if (options && options.headingBuilder) return null;
    var heading = region.querySelector((options && options.headingSelector) || "h1, h2, h3, h4");
    var regionSelector = (options && options.regionSelector) || "section, [role='region'], main > div, main > article";
    var owner = heading && heading.closest && heading.closest(regionSelector);
    return owner && owner !== region && region.contains(owner) ? owner : null;
  }

  function sectionRegionViable(region, options) {
    if ((!options.skipEditorialGuard && !editorialSectionRegion(region)) ||
        (options.regionFilter && !options.regionFilter(region))) return false;
    if (options.allowEmptyRegions) return true;
    return sectionCards(region, options).some(function(card) {
      return !options.cardFilter || options.cardFilter(card);
    });
  }

  function viableNestedSectionRegions(region, options) {
    var regionSelector = (options && options.regionSelector) || "section, [role='region'], main > div, main > article";
    return Array.prototype.filter.call(region.querySelectorAll(regionSelector), function(candidate) {
      return !!sectionRegionLabel(candidate, options) && sectionRegionViable(candidate, options);
    });
  }

  function sectionRegionHasCardsOutside(region, nestedRegions, options) {
    return sectionCards(region, options).some(function(card) {
      if (options.cardFilter && !options.cardFilter(card)) return false;
      return card.card && !nestedRegions.some(function(nested) { return nested.contains(card.card); });
    });
  }

  function genericUnlabelledSectionRegion(region, root, options) {
    var customSectionExtraction = !!(
      options.regionSelector || options.headingSelector || options.headingBuilder ||
      options.fallbackHeadingBuilder || options.additionalRegions || options.regionFilter ||
      options.cardSelector || options.cardFilter || options.allowEmptyRegions ||
      options.skipEditorialGuard
    );
    if (customSectionExtraction || region.parentElement !== root) return false;
    if (!region.matches([
      "section", "[role='region']", "[class~='section' i]", "[class~='slider' i]",
      "[class~='push-slider' i]", "[class~='carousel' i]", "[class~='feed' i]",
      "[class~='grid' i]", "[class~='list' i]"
    ].join(", "))) return false;
    return !viableNestedSectionRegions(region, options).length;
  }

  function genericUnlabelledSectionMaterial(cards) {
    var identities = new Set();
    cards.forEach(function(card) {
      if (materializedHttpUrl(card.url)) identities.add(listItemMaterialIdentity(card));
    });
    return identities.size >= 3;
  }

  function sectionCanonicalKey(url) {
    return listCanonicalKey(url)
      .replace(/([?&])(?:utm_[^&=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)=[^&]*&?/gi, "$1")
      .replace(/[?&]$/, "");
  }

  function sectionCardNodes(region, options) {
    var customSelector = options && options.cardSelector;
    var selector = customSelector || genericListCardSelector();
    var allCards = Array.prototype.slice.call(region.querySelectorAll(selector));
    if (!customSelector) allCards = allCards.filter(genericListCardBoundary);
    var cards = allCards.filter(function(card) {
      if (allCards.some(function(ancestor) {
        return ancestor !== card && ancestor.matches && ancestor.matches("tr") && ancestor.contains(card);
      })) return false;
      return !allCards.some(function(nested) {
        return nested !== card && card.contains(nested) && genericListNestedCard(nested) &&
          genericListNestedCardReplaces(card, nested);
      });
    });
    if (!cards.length) cards = [region];
    return cards;
  }

  function sectionCards(region, options) {
    var candidates = [];
    var cards = [];

    sectionCardNodes(region, options).forEach(function(card) {
      var candidate = sectionCardCandidate(card, options);
      if (!candidate || (!candidate.url && !candidate.canonicalKey)) return;
      candidates.push(candidate);
    });

    candidates.filter(function(candidate) {
      return !candidates.some(function(nested) {
        return nested !== candidate && candidate.card.contains(nested.card) &&
          genericListNestedCardReplaces(candidate.card, nested.card);
      });
    }).forEach(function(candidate) {
      cards.push(candidate);
    });

    return cards;
  }

  function editorialSectionRegion(region) {
    var parent = region.parentElement;
    while (parent) {
      if (parent.matches && parent.matches("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return false;
      parent = parent.parentElement;
    }
    if (listNoiseNode(region) || listNoiseNode(region.parentElement)) return false;
    return true;
  }

  function sectionRegions(root, options) {
    options = options || {};
    var selector = options.regionSelector || "section, [role='region'], main > div, main > article";
    var regions = [];
    var seen = [];
    var material = {};
    var candidates = Array.prototype.slice.call(root.querySelectorAll(selector));

    if (options.additionalRegions) candidates = candidates.concat(options.additionalRegions(root));
    candidates.sort(function(a, b) {
      if (a === b) return 0;
      return a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });

    candidates.forEach(function(region) {
      var label = sectionRegionLabel(region, options);
      var unlabelled = !label && genericUnlabelledSectionRegion(region, root, options);
      if ((!label && !unlabelled) || seen.some(function(existing) { return existing.contains(region); })) return;
      if ((!options.skipEditorialGuard && !editorialSectionRegion(region)) || (options.regionFilter && !options.regionFilter(region))) return;
      var headingOwner = nestedSectionHeadingOwner(region, options);
      if (headingOwner) {
        var nestedRegions = viableNestedSectionRegions(region, options);
        if (nestedRegions.indexOf(headingOwner) >= 0 &&
            !sectionRegionHasCardsOutside(region, nestedRegions, options)) return;
      }

      var discoveredCards = sectionCards(region, options).filter(function(card) {
        return !options.cardFilter || options.cardFilter(card);
      });
      if (unlabelled && !genericUnlabelledSectionMaterial(discoveredCards)) return;

      var cards = discoveredCards.filter(function(card) {
        var key = card.canonicalKey || sectionCanonicalKey(card.url);
        var time = normalizeText(card.time || "");
        var times = material[key];
        if (times && (!time || !times.length || times.indexOf(time) >= 0)) return false;
        if (!times) times = material[key] = [];
        if (time) times.push(time);
        return true;
      });
      if (!cards.length && !options.allowEmptyRegions) return;
      seen.push(region);
      regions.push({
        label: label,
        cards: cards,
        node: region,
        headingNode: !options.headingBuilder && region.querySelector(options.headingSelector || "h1, h2, h3, h4")
      });
    });

    return regions;
  }

  function sectionedListExtraction(root, options) {
    if (typeof articleRouteFocalContent === "function" && articleRouteFocalContent()) return null;
    var regions = sectionRegions(root, options);
    if (regions.length < 2) return null;

    var items = [];
    regions.forEach(function(region) {
      region.cards.forEach(function(card) { items.push(card); });
    });
    if (materializedListItemCount(items) < 2) return null;
    var markdown = regions.map(function(region) {
      var cards = listMarkdown(region.cards);
      return region.label ? "## " + region.label + "\n\n" + cards : cards;
    }).join("\n\n");

    return {
      regions: regions,
      items: items,
      markdown: markdown,
      score: regions.length * 500 + listItemsQualityScore(items)
    };
  }

  function sectionedListMarkdownWithDescriptions(sectioned, descriptions) {
    if (!descriptions.length) return "";

    var sequence = 0;
    var blocks = [];
    sectioned.regions.forEach(function(region, regionIndex) {
      if (region.label) {
        blocks.push({
          node: region.headingNode || region.node,
          markdown: "## " + region.label,
          kind: "heading",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      }
      region.cards.forEach(function(item) {
        blocks.push({
          node: item.sourceNode || item.card || region.node,
          markdown: listMarkdown([item]),
          kind: "item",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      });
    });
    descriptions.forEach(function(description) {
      blocks.push({
        node: description.node,
        markdown: description.markdown,
        kind: "description",
        regionIndex: null,
        sequence: sequence++
      });
    });
    blocks.sort(function(left, right) {
      if (!left.node || !right.node || left.node === right.node) return left.sequence - right.sequence;
      var position = left.node.compareDocumentPosition(right.node);
      if (position & Node.DOCUMENT_POSITION_FOLLOWING) return -1;
      if (position & Node.DOCUMENT_POSITION_PRECEDING) return 1;
      return left.sequence - right.sequence;
    });

    return blocks.map(function(block, index) {
      if (!index) return block.markdown;
      var previous = blocks[index - 1];
      var separator = previous.kind === "item" && block.kind === "item" &&
        previous.regionIndex === block.regionIndex ? "\n" : "\n\n";
      return separator + block.markdown;
    }).join("");
  }

  function listExtractionIsBetter(current, candidate) {
    if (!current) return true;

    var currentSections = current.sectionCount || 0;
    var candidateSections = candidate.sectionCount || 0;
    if (candidateSections !== currentSections) return candidateSections > currentSections;

    if (candidateSections) {
      var currentRank = current.sectionRank || 0;
      var candidateRank = candidate.sectionRank || 0;
      if (candidateRank !== currentRank) return candidateRank > currentRank;
    }

    return candidate.score > current.score;
  }
