  function sectionHeading(region) {
    var heading = region.querySelector("h1, h2, h3, h4");
    var label = normalizeText(heading && heading.textContent);
    if (!label || label.length > 90 || rejectedHomepageLeadText(label, "")) return "";
    return label;
  }

  function sectionCanonicalKey(url) {
    return listCanonicalKey(url)
      .replace(/([?&])(?:utm_[^&=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)=[^&]*&?/gi, "$1")
      .replace(/[?&]$/, "");
  }

  function sectionCardNodes(region) {
    var selector = [
      "article", "li", "[class*='card']", "[class*='story']", "[class*='teaser']",
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

  function sectionCards(region, seen) {
    var candidates = [];
    var cards = [];

    sectionCardNodes(region).forEach(function(card) {
      var candidate = sectionCardCandidate(card);
      if (!candidate || !candidate.url) return;
      candidates.push(candidate);
    });

    candidates.filter(function(candidate) {
      return !candidates.some(function(nested) {
        return nested !== candidate && candidate.card.contains(nested.card);
      });
    }).forEach(function(candidate) {
      var key = sectionCanonicalKey(candidate.url);
      if (seen[key]) return;
      seen[key] = true;
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

  function sectionRegions(root) {
    var selector = "section, [role='region'], main > div, main > article";
    var regions = [];
    var seen = [];
    var canonical = {};

    Array.prototype.forEach.call(root.querySelectorAll(selector), function(region) {
      var label = sectionHeading(region);
      if (!label || seen.some(function(existing) { return existing.contains(region); })) return;
      if (!editorialSectionRegion(region)) return;

      var cards = sectionCards(region, canonical);
      if (!cards.length) return;
      seen.push(region);
      regions.push({ label: label, cards: cards.slice(0, 3) });
    });

    return regions;
  }

  function sectionedListExtraction(root) {
    var regions = sectionRegions(root);
    if (regions.length < 2) return null;

    var items = [];
    var seen = {};
    var markdown = regions.map(function(region) {
      var cards = region.cards.filter(function(card) {
        var key = sectionCanonicalKey(card.url);
        if (seen[key]) return false;
        seen[key] = true;
        return true;
      });
      cards.forEach(function(card) { items.push(card); });
      return "## " + region.label + "\n\n" + listMarkdown(cards);
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
