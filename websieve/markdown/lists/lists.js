function escapeMarkdownLinkLabel(text) {
  return String(text == null ? "" : text).replace(/\\/g, "\\\\").replace(/([\[\]])/g, "\\$1");
}

function markdownLink(text, url) {
  var href = materializedHttpUrl(url);
  return href ? "[" + escapeMarkdownLinkLabel(text) + "](" + href + ")" : text;
}

function markdownLinkWithFormattedLabel(markdown, url) {
  var href = materializedHttpUrl(url);
  return href ? "[" + markdown + "](" + href + ")" : markdown;
}

function listItemMaterialIdentity(item, rawHref) {
  return JSON.stringify([
    item.url || "unlinked:" + (rawHref || ""),
    normalizeText(item.text || ""),
    normalizeText(item.detail || "")
  ]);
}

function listDetailWithoutContext(detail, contextValues) {
  var remaining = stripGenericListControlPhrases(detail || "");
  if (!remaining) return "";
  var represented = contextValues.map(normalizeText).filter(Boolean);
  return remaining.split(/\s+(?:[-|·])\s+/).filter(function(segment) {
    return represented.indexOf(normalizeText(segment)) === -1;
  }).join(" - ");
}

function listClonedCardNode(card, clone, node) {
  var path = [];
  while (node && node !== card) {
    var parent = node.parentNode;
    if (!parent) return null;
    path.unshift(Array.prototype.indexOf.call(parent.childNodes, node));
    node = parent;
  }
  if (node !== card) return null;
  return path.reduce(function(current, index) {
    return current && current.childNodes[index];
  }, clone);
}

function listTextWithReferences(node, visibilityChecked, primaryUrl, allowedLinks) {
  if (!node || !node.cloneNode) return "";
  var clone = visibilityChecked ? node : node.cloneNode(true);
  if (!visibilityChecked) pruneListCardVisibility(node, clone);
  if (clone.matches && clone.matches("a[href]")) {
    var rootLabel = normalizeText(clone.textContent || clone.getAttribute("aria-label") || "");
    var rootUrl = materializedHttpUrl(clone.getAttribute("href"));
    if (primaryUrl && rootUrl && listCanonicalKey(rootUrl) === listCanonicalKey(primaryUrl)) return rootLabel;
    return markdownLink(rootLabel, clone.getAttribute("href"));
  }
  clone.querySelectorAll("a[href]").forEach(function(link) {
    var label = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
    var url = materializedHttpUrl(link.getAttribute("href"));
    var linked = (!allowedLinks || allowedLinks.has(link)) &&
      !(primaryUrl && url && listCanonicalKey(url) === listCanonicalKey(primaryUrl));
    link.replaceWith(clone.ownerDocument.createTextNode(linked ? markdownLink(label, url) : label));
  });
  return normalizeText(clone.textContent);
}

function listSupplementalInteractionLink(link) {
  if (!link || !link.matches) return false;
  var owner = link.closest("[class*='comment' i], [id*='comment' i], [class*='reply' i], [id*='reply' i]");
  var url = materializedHttpUrl(link.getAttribute("href")) || "";
  return !!owner || /\/(?:comments?|comentarios?|replies)(?:\/|$)/i.test(url);
}

function listSupplementalNavigationOwner(node) {
  var owner = node;
  while (owner) {
    if (owner.matches && owner.matches("nav, header, footer, aside")) return true;
    var roles = normalizeText(owner.getAttribute && owner.getAttribute("role") || "").toLowerCase().split(/\s+/);
    if (roles.some(function(role) { return ["navigation", "menu", "menubar"].indexOf(role) >= 0; })) return true;
    owner = owner.parentElement;
  }
  return false;
}

function listSupplementalHeadingReference(link, item, card) {
  if (!link || !item || !item.sourceNode || !card || !card.contains ||
      !card.contains(item.sourceNode)) return false;
  var heading = link.closest("h1, h2, h3, h4");
  if (!heading || !card.contains(heading) || !heading.contains(item.sourceNode) ||
      listSupplementalNavigationOwner(heading)) return false;
  var links = Array.prototype.filter.call(heading.querySelectorAll("a[href]"), function(anchor) {
    return !listCardNodeHidden(anchor);
  });
  if (links.length < 2 || links.length > 5 || links.indexOf(link) === -1 ||
      links.indexOf(item.sourceNode) === -1) return false;
  if (!links.every(function(anchor) {
    var url = materializedHttpUrl(anchor.getAttribute("href"));
    return url && new URL(url).origin === location.origin;
  })) return false;
  var clone = heading.cloneNode(true);
  clone.querySelectorAll("a[href]").forEach(function(anchor) { anchor.remove(); });
  return /^[\s»›>\/|·:;,.–—-]*$/.test(clone.textContent || "");
}

function listItemContextValues(item, primaryUrls, primaryRecordKeys) {
   if (item.groupLabel != null) return item.groupLabel ? [item.groupLabel] : [];
  var card = item.card;
  var rowDetail = card && card.matches && card.matches("tr") ? stripGenericListControlPhrases(item.detail) : "";
  if (rowDetail) {
    if (!item.tableCells && !item.tableRowDetail) return [rowDetail];
    if (item.tableReferenceDetail == null) {
      item.tableReferenceDetail = stripGenericListControlPhrases(listTableRowDetail(card, item.text, item.tableCells, { url: item.url }));
    }
    return [item.tableReferenceDetail];
  }

  var compactMetadata = listCompactMetadataRow(card, item);
  var timeSelector = "time, [datetime], [class~='time'], [class*='timestamp' i], [class*='date' i]";
  var scoreSelector = "[class*='score' i], [data-score], [data-karma]";
  var timeNode = card && card.querySelector ? cardOwnedNodes(card, timeSelector)[0] : null;
  var scoreNode = card && card.querySelector ? cardOwnedNodes(card, scoreSelector)[0] : null;
  var compactSummary = listCompactMetadataFollowingField(
    card,
    compactMetadata,
    "[class*='summary'], [class*='description'], [class*='excerpt'], p",
    item.summary
  );
  var timeValue = cardField(card, timeSelector, item.url) || item.time;
  var scoreValue = cardField(card, scoreSelector, item.url) || item.score;
  var contextValues = [
    listCompactMetadataRepresents(compactMetadata, item.category) ? "" : item.category,
    item.contextHeading,
    compactSummary ? "" : item.summary,
    cardField(card, "[rel~='author'], [itemprop~='author'], [class*='author' i], [class*='byline' i], [data-author]", item.url, true, function(node) {
      return genericListAuthorMetadataNode(node) && !genericListInteractionOwner(node);
    }) || item.author,
    listCompactMetadataContains(compactMetadata, timeNode) ? "" : timeValue,
    listCompactMetadataContains(compactMetadata, scoreNode) ? "" : scoreValue,
    cardField(card, ".reply, .replies, .comment, .comments, [class~='reply'], [class~='replies'], [class~='comment'], [class~='comments'], [class*='reply'], [class*='replie'], [class*='comment'], [data-reply], [data-replies], [data-comment], [data-comments]", item.url, false, function(node) {
      return !genericListAuthorMetadataNode(node);
    }) || item.replyCount,
    cardField(card, "[class*='community' i], [class*='subreddit' i], [data-community]", item.url) || item.community,
    item.image,
    item.caption
  ];
  var detailCard = item.supplementalCard || card;
  var supplementalDetail = listExactPrimaryAliasDetail(item.detail, item) ? "" :
    listSupplementalDetail(item, contextValues, detailCard, primaryUrls, primaryRecordKeys);
  if (listExactPrimaryAliasDetail(supplementalDetail, item)) supplementalDetail = "";
  if (supplementalDetail) contextValues.push(supplementalDetail);
  if (item.contextHeading && item.summary) {
    var contextHeadingIndex = contextValues.indexOf(item.contextHeading);
    var summaryIndex = contextValues.indexOf(item.summary);
    if (contextHeadingIndex !== -1 && summaryIndex !== -1 && contextHeadingIndex !== summaryIndex) {
      contextValues[contextHeadingIndex] = normalizeText(item.contextHeading + " " + item.summary);
      contextValues[summaryIndex] = "";
      contextValues.forEach(function(value, index) {
        if (index !== contextHeadingIndex && normalizeText(value) === normalizeText(item.contextHeading)) {
          contextValues[index] = "";
        }
      });
    }
  }
  return contextValues.filter(function(value) {
    return value && !listEmptyRepresentedReference(value, primaryUrls);
  }).filter(function(value, index, values) {
    return values.indexOf(value) === index;
  });
}

var listMarkdown = function(items, primaryUrls, primaryRecordKeys) {
  primaryUrls = primaryUrls || new Set(items.map(function(item) {
    var url = materializedHttpUrl(item.url || "");
    return url && listCanonicalKey(url);
  }).filter(Boolean));
  primaryRecordKeys = primaryRecordKeys || listPrimaryRecordKeys(items);
  return items.map(function(item) {
    var line = "- " + markdownLink(item.displayText || item.text, item.url);
    var context = listItemContextValues(item, primaryUrls, primaryRecordKeys).join(" - ");
    if (context) line += " - " + context;
    return line;
  }).join("\n");
};
