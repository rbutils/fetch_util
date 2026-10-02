function materialResultsMediaReferences(root) {
  var references = [];
  Array.prototype.forEach.call(root.querySelectorAll("img[src], img[srcset], source[srcset], video[poster]"), function(node) {
    if (materialResultsNodeHidden(node)) return;
    [node.getAttribute("src"), node.getAttribute("poster")].forEach(function(value) {
      var url = value && materializedHttpUrl(value);
      if (url) references.push(url);
    });
    var srcset = node.getAttribute("srcset") || "";
    var matcher = /(?:^|,)\s*(https?:\/\/[^\s,]+)/g;
    var match;
    while ((match = matcher.exec(srcset))) {
      var srcsetUrl = materializedHttpUrl(match[1]);
      if (srcsetUrl) references.push(srcsetUrl);
    }
  });
  return references;
}

function materialResultsRecordTitle(card) {
  var structuredLink = genericListStructuredCardLink(card, false);
  var titleLinks = Array.prototype.filter.call(card.querySelectorAll("a[href]"), function(link) {
    if (materialResultsNodeHidden(link) || !materializedHttpUrl(link.getAttribute("href")) ||
        link.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return false;

    var titleFields = Array.prototype.filter.call(link.querySelectorAll("[class*='title' i], [class*='name' i], h1, h2, h3, h4"), function(field) {
      return !materialResultsNodeHidden(field);
    });
    if (!titleFields.length && link.matches("[class*='title' i], [class*='name' i]")) titleFields = [link];
    if (titleFields.length !== 1) return false;

    var title = normalizeText(titleFields[0].textContent || "");
    return !!title && !genericListControlText(title) && !looksLikeFooterLink(title, link.getAttribute("href"));
  });
  var links = Array.from(new Set(titleLinks.concat(structuredLink ? [structuredLink] : [])));
  if (links.length !== 1) return null;

  var link = links[0];
  if (!materialResultsMediaReferences(card).length && structuredLink !== link) return null;
  var titleFields = Array.prototype.filter.call(link.querySelectorAll("[class*='title' i], [class*='name' i], h1, h2, h3, h4"), function(field) {
    return !materialResultsNodeHidden(field);
  });
  if (!titleFields.length && link.matches("[class*='title' i], [class*='name' i]")) titleFields = [link];
  var title = normalizeText((titleFields[0] && titleFields[0].textContent) || link.textContent || "");
  var url = materializedHttpUrl(link.getAttribute("href"));
  return title && url ? { title: title, url: listCanonicalKey(url), link: link } : null;
}

function materialResultsCardText(card) {
  var visible = visibleListClone(card, null, null);
  cleanupListRoot(visible, null, null);
  return normalizeText(visible.textContent || "");
}

function materialResultsCardSummary(card) {
  var record = materialResultsRecordTitle(card);
  var text = materialResultsCardText(card);
  if (!record || !text) return null;

  var links = Array.prototype.map.call(card.querySelectorAll("a[href]"), function(link) {
    if (materialResultsNodeHidden(link)) return null;
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url) return null;
    return [listCanonicalKey(url), normalizeText(link.textContent || link.getAttribute("aria-label") || link.getAttribute("title") || "")];
  }).filter(Boolean);
  return {
    title: record.title,
    url: record.url,
    titleLink: record.link,
    text: text,
    links: links,
    media: materialResultsMediaReferences(card)
  };
}

function materialResultsExplicitPromotion(node) {
  if (materialResultsMediaReferences(node).length) return false;
  var hasCampaignLink = false;
  var hasTrialAction = false;
  Array.prototype.forEach.call(node.querySelectorAll("a[href]"), function(link) {
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (href) {
      var url = new URL(href, location.href);
      if (url.searchParams.has("promoid") || url.searchParams.has("ad_id")) hasCampaignLink = true;
    }
    if (/\b(?:free trial|start trial|upgrade|subscribe)\b/i.test(normalizeText(link.textContent || ""))) {
      hasTrialAction = true;
    }
  });
  var promotionContext = /\b(?:pro|premium|upgrade)\b/i.test(normalizeText(node.textContent || ""));
  return hasTrialAction && (hasCampaignLink || promotionContext);
}

function materialResultsRelatedRail(node) {
  return Array.prototype.some.call(node.querySelectorAll("[role='region'][aria-label]"), function(region) {
    if (materialResultsNodeHidden(region) ||
        !/^(?:more on|related|recommended|similar|explore more)\b/i.test(normalizeText(region.getAttribute("aria-label") || ""))) return false;
    var linkedMediaRecords = Array.prototype.filter.call(region.querySelectorAll("a[href]"), function(link) {
      return !materialResultsNodeHidden(link) && !!link.querySelector("img[src], picture img[src], video[poster]");
    });
    return linkedMediaRecords.length > 1;
  });
}

function materialResultsExplicitChrome(node) {
  return node.matches("nav, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo'], [role='complementary']");
}

function materialResultsSourceCards(owner) {
  var cards = [];
  var excludedNodes = [];
  var complete = true;
  Array.prototype.forEach.call(owner.childNodes, function(child) {
    if (child.nodeType === Node.TEXT_NODE) {
      if (normalizeText(child.textContent || "")) complete = false;
      return;
    }
    if (child.nodeType !== Node.ELEMENT_NODE) return;
    if (/^(?:STYLE|SCRIPT|TEMPLATE)$/.test(child.tagName) || materialResultsNodeHidden(child)) return;
    var summary = materialResultsCardSummary(child);
    if (summary) {
      cards.push({ node: child, summary: summary });
      return;
    }
    if (materialResultsExplicitChrome(child) || listExplicitAdvertisementOwner(child) ||
        materialResultsExplicitPromotion(child) || materialResultsRelatedRail(child)) {
      excludedNodes.push(child);
      return;
    }
    complete = false;
  });
  return { cards: cards, excludedNodes: excludedNodes, complete: complete };
}

function materialResultsCloneProof(proof, elementMap, root) {
  if (!proof || !proof.complete || !elementMap || !root) return null;
  var cardNodes = [];
  var titleLinks = new Set();
  proof.cards.forEach(function(card) {
    var clonedCard = elementMap.get(card.node);
    var clonedTitleLink = elementMap.get(card.summary.titleLink);
    if (!clonedCard || clonedCard.parentElement !== root || !clonedTitleLink || !clonedCard.contains(clonedTitleLink)) return;
    cardNodes.push(clonedCard);
    titleLinks.add(clonedTitleLink);
  });
  if (cardNodes.length !== proof.cards.length || titleLinks.size !== proof.cards.length) return null;

  proof.excludedNodes.forEach(function(sourceNode) {
    var clonedNode = elementMap.get(sourceNode);
    if (clonedNode && clonedNode !== root && root.contains(clonedNode)) clonedNode.remove();
  });
  return { cardNodes: cardNodes, titleLinks: titleLinks };
}

function materialResultsRetainProvenItems(items, cloneProof) {
  if (!cloneProof) return items;
  return items.filter(function(item) { return cloneProof.titleLinks.has(item.sourceNode); });
}

function materialResultsCandidateCoversSource(proof, candidate) {
  var extraction = candidate && candidate.listExtraction;
  if (!proof || !proof.complete || !candidate || candidate.contentType !== "list" || !candidate.html || !extraction ||
      extraction.sourceNode !== proof.owner || extraction.items.length !== proof.cards.length) return false;

  if (!proof.cards.every(function(card, index) {
    var item = extraction.items[index];
    var itemUrl = materializedHttpUrl(item && item.url);
    return !!itemUrl && listCanonicalKey(itemUrl) === card.summary.url && item.sourceNode &&
      normalizeText(item.sourceNode.textContent || item.sourceNode.getAttribute("aria-label") || "") === card.summary.title;
  })) return false;

  var output = document.createElement("div");
  output.innerHTML = candidate.html;
  var outputRecords = materialResultsSourceCards(output);
  if (!outputRecords.complete || outputRecords.excludedNodes.length || outputRecords.cards.length !== proof.cards.length) return false;

  return proof.cards.every(function(sourceCard, index) {
    var source = sourceCard.summary;
    var rendered = outputRecords.cards[index].summary;
    return source.title === rendered.title && source.url === rendered.url && source.text === rendered.text &&
      JSON.stringify(source.links) === JSON.stringify(rendered.links) &&
      JSON.stringify(source.media) === JSON.stringify(rendered.media);
  });
}
