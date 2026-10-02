function materialResultsSearchQuery() {
  var params = new URLSearchParams(location.search || "");
  var keys = ["q", "query", "search", "searchtext", "keyword", "k"];
  for (var index = 0; index < keys.length; index += 1) {
    var value = normalizeText(params.get(keys[index]) || "");
    if (value) return value.toLowerCase().replace(/^[\s"'“”‘’]+|[\s"'“”‘’.,;:!?]+$/g, "");
  }
  return "";
}

function materialResultsNodeHidden(node) {
  return elementSubtreeHidden(node) || !!(node && node.closest("[hidden], [inert], [aria-hidden='true']"));
}

function materialResultsLabelMatches(region, query, owner) {
  var countPattern = /^\s*(?:[1-9]\d{0,2}(?:,\d{3})+|[1-9]\d*)\+?\s+results?\s+for\s+(.+)$/i;
  var matches = [];
  Array.prototype.forEach.call(region.querySelectorAll("*"), function(node) {
    if (owner.contains(node) || materialResultsNodeHidden(node) ||
        node.closest("nav, header, footer, aside, form, [role='navigation'], [role='complementary']")) return;
    var match = countPattern.exec(normalizeText(node.textContent || ""));
    if (!match) return;
    var declaredQuery = normalizeText(match[1]).toLowerCase().replace(/^[\s"'“”‘’]+|[\s"'“”‘’.,;:!?]+$/g, "");
    if (declaredQuery === query) matches.push(node);
  });
  return matches.filter(function(node) {
    return !matches.some(function(other) { return other !== node && node.contains(other); });
  });
}

function materialResultsLabelDescribesOwner(label, owner) {
  var countRegion = label && label.closest("[role='region'][aria-label]");
  if (!countRegion || !countRegion.id) return false;
  var countRegionId = countRegion.id;
  for (var current = owner; current; current = current.parentElement) {
    var references = normalizeText([
      current.getAttribute("aria-describedby"),
      current.getAttribute("aria-labelledby"),
      current.getAttribute("aria-controls")
    ].join(" ")).split(/\s+/);
    if (references.indexOf(countRegionId) !== -1) return true;
    if (current.matches("main, [role='main']")) break;
  }
  return false;
}

function materialResultsHasIndependentError(main, owner) {
  var errorNodes = Array.prototype.filter.call(main.querySelectorAll("h1, h2, p"), function(node) {
    return !owner.contains(node) && !materialResultsNodeHidden(node) &&
      !node.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']");
  });
  return errorNodes.some(function(node) {
    return notFoundInterstitialPattern().test(normalizeText(node.textContent || ""));
  });
}

function materialResultsHasFocalArticleHeader(main, owner) {
  return Array.prototype.some.call(main.querySelectorAll("header, article"), function(node) {
    if (owner.contains(node) || materialResultsNodeHidden(node) ||
        node.closest("nav, footer, aside, [role='navigation'], [role='complementary']")) return false;
    return !!node.querySelector("h1") && !!node.querySelector("time[datetime], [itemprop='datePublished'], [property='article:published_time']");
  });
}

function materialResultsHasForeignProse(main, owner) {
  var paragraphs = new Set();
  var characters = 0;
  Array.prototype.forEach.call(main.querySelectorAll("p"), function(paragraph) {
    if (owner.contains(paragraph) || materialResultsNodeHidden(paragraph) ||
        paragraph.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return;
    var text = normalizeText(paragraph.textContent || "");
    if (text.length < 80 || paragraphs.has(text)) return;
    paragraphs.add(text);
    characters += text.length;
  });
  return paragraphs.size >= 3 && characters >= 600;
}

function materialResultsReaderContentOwnedByQuery(proof, content, metadata) {
  if (!proof || !proof.complete || !content || content.contentType !== "article") return false;
  var label = normalizeText(proof.label.textContent || "");
  if (!label || normalizeText(content.excerpt || "") !== label ||
      materialResultsHasIndependentError(proof.main, proof.owner) || materialResultsHasForeignProse(proof.main, proof.owner)) return false;

  var readerRoot = document.createElement("div");
  readerRoot.innerHTML = content.html || "";
  if (readerRoot.querySelector("time[datetime], [itemprop='datePublished'], [property='article:published_time']")) return false;

  var sourceText = proof.cards.map(function(card) { return card.summary.text; });
  var sourceHeadings = Array.prototype.filter.call(proof.region.querySelectorAll("h1, h2, h3, h4"), function(heading) {
    return !proof.owner.contains(heading) && !materialResultsNodeHidden(heading) &&
      !heading.closest("nav, header, footer, aside, article, [role='navigation'], [role='complementary']");
  });
  var headings = Array.prototype.filter.call(readerRoot.querySelectorAll("h1, h2, h3, h4"), function(heading) {
    return !materialResultsNodeHidden(heading);
  });
  if (headings.some(function(heading) {
    var text = normalizeText(heading.textContent || "");
    if (text === label || sourceText.some(function(cardText) { return cardText.indexOf(text) !== -1; })) return false;
    return sourceHeadings.some(function(sourceHeading) {
      return normalizeText(sourceHeading.textContent || "") === text;
    });
  })) return false;

  var paragraphs = Array.prototype.filter.call(readerRoot.querySelectorAll("p"), function(paragraph) {
    return !materialResultsNodeHidden(paragraph) && normalizeText(paragraph.textContent || "");
  });
  if (paragraphs.some(function(paragraph) {
    var text = normalizeText(paragraph.textContent || "");
    return !sourceText.some(function(cardText) { return cardText.indexOf(text) !== -1; });
  })) return false;

  return Array.prototype.every.call(readerRoot.querySelectorAll("a[href]"), function(link) {
    if (materialResultsNodeHidden(link)) return true;
    var url = materializedHttpUrl(link.getAttribute("href"));
    var name = normalizeText(link.textContent || link.getAttribute("aria-label") || link.getAttribute("title") || "");
    return proof.cards.some(function(card) {
      return card.summary.links.some(function(sourceLink) {
        return sourceLink[0] === listCanonicalKey(url || "") && sourceLink[1] === name;
      });
    });
  });
}

function visibleMaterialResultsOwner(content, metadata, selectedFocalArticleOwner) {
  if (!document.body) return null;
  if (content && (content.hostAware || content.docsLike || content.legalProvision ||
      content.contentType === "medical" ||
      content.contentType === "press_release" || content.contentType === "product" ||
      content.contentType === "recipe" || content.contentType === "property" || content.contentType === "hotel" ||
      content.contentType === "event")) return null;

  var query = materialResultsSearchQuery();
  if (!query) return null;
  var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(main) {
    return !materialResultsNodeHidden(main) && !main.closest("[role='complementary']");
  });
  if (mains.length !== 1) return null;

  var main = mains[0];
  var regions = Array.prototype.filter.call(main.querySelectorAll("[role='region'][aria-label]"), function(region) {
    return /^search results?$/i.test(normalizeText(region.getAttribute("aria-label") || "")) &&
      !materialResultsNodeHidden(region);
  });
  if (regions.length !== 1) return null;

  var region = regions[0];
  var owners = Array.prototype.filter.call(region.querySelectorAll("[role='feed'], [role='list'], [role='grid']"), function(candidate) {
    return !materialResultsNodeHidden(candidate) &&
      !candidate.closest("nav, header, footer, aside, form, article, [role='navigation'], [role='complementary']");
  });
  if (owners.length !== 1) return null;
  var owner = owners[0];
  if (!main.contains(owner) || owner.closest("nav, header, footer, aside, form, article, [role='navigation'], [role='complementary']") ||
      materialResultsHasIndependentError(main, owner) || materialResultsHasFocalArticleHeader(main, owner) ||
      materialResultsHasForeignProse(main, owner)) return null;

  var labels = materialResultsLabelMatches(region, query, owner);
  if (labels.length !== 1 || !materialResultsLabelDescribesOwner(labels[0], owner)) return null;
  var sourceRecords = materialResultsSourceCards(owner);
  if (sourceRecords.complete && !sourceRecords.cards.length) return null;
  var proof = {
    owner: owner,
    main: main,
    region: region,
    label: labels[0],
    query: query,
    cards: sourceRecords.cards,
    excludedNodes: sourceRecords.excludedNodes,
    complete: sourceRecords.complete
  };
  var focalOwner = selectedFocalArticleOwner || articleRouteFocalContent(content, true);
  var articleMetadata = content && (strongArticleMetadata(metadata, content) || matchingStructuredDetailArticle(content));
  var readerOwnedByQuery = materialResultsReaderContentOwnedByQuery(proof, content, metadata);
  if (articleMetadata && !readerOwnedByQuery) return null;
  if (focalOwner && !owner.contains(focalOwner) && !readerOwnedByQuery) return null;
  if (content && content.focalPermalinkContent && !readerOwnedByQuery) return null;
  return proof;
}
