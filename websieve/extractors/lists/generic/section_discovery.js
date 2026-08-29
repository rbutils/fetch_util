  function sectionHeading(region, options) {
    if (options && options.headingBuilder) return options.headingBuilder(region);
    var heading = region.querySelector((options && options.headingSelector) || "h1, h2, h3, h4");
    var label = normalizeText(heading && heading.textContent);
    if (!label || label.length > 90 || rejectedHomepageLeadText(label, "")) return "";
    return label;
  }

  function sectionCanonicalKey(url) {
    return listCanonicalKey(url)
      .replace(/([?&])(?:utm_[^&=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)=[^&]*&?/gi, "$1")
      .replace(/[?&]$/, "");
  }

  function sectionCardNodes(region, options) {
    var selector = (options && options.cardSelector) || [
      "tr", "article", "li", "[class*='card']", "[class*='story']", "[class*='teaser']",
      "[class*='item']", "[class*='result']", "[class*='news']", "[class*='headline']"
    ].join(", ");
    var allCards = Array.prototype.slice.call(region.querySelectorAll(selector));
    var cards = allCards.filter(function(card) {
      return !allCards.some(function(nested) {
        return nested !== card && card.contains(nested);
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
        return nested !== candidate && candidate.card.contains(nested.card);
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
      var label = sectionHeading(region, options);
      if (!label && options.fallbackHeadingBuilder) label = options.fallbackHeadingBuilder(region);
      if (!label || seen.some(function(existing) { return existing.contains(region); })) return;
      if ((!options.skipEditorialGuard && !editorialSectionRegion(region)) || (options.regionFilter && !options.regionFilter(region))) return;

      var cards = sectionCards(region, options).filter(function(card) {
        if (options.cardFilter && !options.cardFilter(card)) return false;
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
      regions.push({ label: label, cards: cards });
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
      return "## " + region.label + "\n\n" + listMarkdown(region.cards);
    }).join("\n\n");

    return {
      regions: regions,
      items: items,
      markdown: markdown,
      score: regions.length * 500 + listItemsQualityScore(items)
    };
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
