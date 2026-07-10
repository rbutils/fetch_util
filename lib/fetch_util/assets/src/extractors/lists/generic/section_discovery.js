  function sectionHeading(region) {
    var heading = region.querySelector("h1, h2, h3, h4");
    var label = normalizeText(heading && heading.textContent);
    if (!label || label.length > 90 || rejectedHomepageLeadText(label, "")) return "";
    return label;
  }

  function sectionCardNodes(region) {
    var selector = [
      "article", "li", "[class*='card']", "[class*='story']", "[class*='teaser']",
      "[class*='item']", "[class*='result']", "[class*='news']", "[class*='headline']"
    ].join(", ");
    var cards = Array.prototype.slice.call(region.querySelectorAll(selector));
    if (!cards.length) cards = [region];
    return cards;
  }

  function sectionCards(region) {
    var seen = {};
    var cards = [];

    sectionCardNodes(region).forEach(function(card) {
      var candidate = sectionCardCandidate(card);
      if (!candidate || !candidate.url) return;
      if (seen[candidate.canonicalKey]) return;
      seen[candidate.canonicalKey] = true;
      cards.push(candidate);
    });

    return cards;
  }

  function sectionRegions(root) {
    var selector = "section, [role='region'], main > div, main > article";
    var regions = [];
    var seen = [];

    Array.prototype.forEach.call(root.querySelectorAll(selector), function(region) {
      var label = sectionHeading(region);
      if (!label || seen.some(function(existing) { return existing.contains(region); })) return;

      var cards = sectionCards(region);
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
    var markdown = regions.map(function(region) {
      region.cards.forEach(function(card) { items.push(card); });
      return "## " + region.label + "\n\n" + listMarkdown(region.cards);
    }).join("\n\n");

    return {
      regions: regions,
      items: items,
      markdown: markdown,
      score: regions.length * 500 + listItemsQualityScore(items)
    };
  }
