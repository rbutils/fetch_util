function markdownLink(text, url) {
  var href = materializedHttpUrl(url);
  return href ? "[" + text + "](" + href + ")" : text;
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

function listClonedCardFields(card, clone, selector, fieldFilter) {
  var fields = cardOwnedNodes(card, selector);
  if (fieldFilter) fields = fields.filter(fieldFilter);
  var selectedValue = fields[0] && normalizeText(
    fields[0].getAttribute("datetime") || fields[0].getAttribute("content") || fields[0].textContent || ""
  );
  return fields.filter(function(field) {
    var value = normalizeText(field.getAttribute("datetime") || field.getAttribute("content") || field.textContent || "");
    return value === selectedValue;
  }).map(function(field) {
    return listClonedCardNode(card, clone, field);
  });
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

function listSupplementalDetail(item, contextValues, card, primaryUrls, primaryRecordKeys) {
  if (!card || !card.cloneNode) return listDetailWithoutContext(item.detail, contextValues);
  var clone = card.cloneNode(true);
  var compactMetadata = listCompactMetadataRow(card, item);
  var compactMetadataClone = compactMetadata && listClonedCardNode(card, clone, compactMetadata.node);
  var compactSummarySelector = "[class*='summary'], [class*='description'], [class*='excerpt'], p";
  var compactSummary = listCompactMetadataFollowingField(card, compactMetadata, compactSummarySelector, item.summary);
  var compactSummaryClone = compactSummary && listClonedCardNode(card, clone, compactSummary);
  var contentCard = item.contentCard && listClonedCardNode(card, clone, item.contentCard);
  var supportingNestedCards = Array.prototype.filter.call(card.querySelectorAll(genericListCardSelector()), function(nested) {
    return !genericListStructuredCardLink(nested) && Array.prototype.some.call(nested.querySelectorAll("a[href]"), function(link) {
      return !!genericListSupportingCard(link, item.contentCard || card);
    });
  }).map(function(nested) { return listClonedCardNode(card, clone, nested); }).filter(Boolean);
  var supportingLinks = new WeakSet();
  var descriptionOwner = listDescriptionOwnerCard(item);
  var ownerProse = descriptionOwner ? cardOwnedNodes(descriptionOwner, "p, blockquote") : [];
  if (card !== item.card && item.supplementalSourceClones) {
    ownerProse = ownerProse.map(function(node) {
      return item.supplementalSourceClones.get(node);
    }).filter(function(node) { return node && card.contains(node); });
  }
  Array.prototype.forEach.call(card.querySelectorAll("a[href]"), function(link) {
    var url = materializedHttpUrl(link.getAttribute("href"));
    var representedPrimary = primaryRecordKeys ?
      primaryRecordKeys.has(listPrimaryRecordKey(url, link.textContent)) :
      primaryUrls && primaryUrls.has(listCanonicalKey(url));
    var prose = link.closest("p, blockquote");
    var ownedProseReference = prose && ownerProse.indexOf(prose) !== -1 &&
      normalizeText(prose.textContent || "").length >= 30;
    var ownedHeadingReference = listSupplementalHeadingReference(link, item, card);
    if (!url || (!ownedProseReference && !ownedHeadingReference && (listSupplementalInteractionLink(link) ||
        representedPrimary))) return;
    var clonedLink = listClonedCardNode(card, clone, link);
    if (clonedLink) supportingLinks.add(clonedLink);
  });
  var metadataSelector = "[rel~='author'], [itemprop~='author'], [class*='author' i], [class*='byline' i], time, [datetime], [class*='score' i], [class*='point' i], [class*='reply' i], [class*='comment' i], [class*='community' i], [class*='metric' i], [class*='stat' i]";
  var nestedMetadataCards = Array.prototype.filter.call(card.querySelectorAll(genericListCardSelector()), function(nested) {
    if (!genericListPresentationCardNode(nested)) return false;
    var nestedFields = Array.prototype.filter.call(nested.querySelectorAll(metadataSelector), function(field) {
      return !listCardNodeHidden(field);
    });
    if (!nestedFields.length) return false;
    var nestedClone = nested.cloneNode(true);
    pruneListCardVisibility(nested, nestedClone);
    nestedClone.querySelectorAll(metadataSelector).forEach(function(field) { field.remove(); });
    if (normalizeText(nestedClone.textContent || "")) return false;
    return Array.prototype.some.call(card.querySelectorAll(metadataSelector), function(field) {
      return !nested.contains(field) && !listCardNodeHidden(field);
    });
  }).map(function(nested) { return listClonedCardNode(card, clone, nested); }).filter(Boolean);
  var siblingPresentationCards = item.contentCard ? Array.prototype.filter.call(card.querySelectorAll(genericListCardSelector()), function(nested) {
    return nested !== item.contentCard && !nested.contains(item.contentCard) &&
      !item.contentCard.contains(nested) && genericListPresentationCardNode(nested);
  }).map(function(nested) { return listClonedCardNode(card, clone, nested); }).filter(Boolean) : [];
  var authorFieldSelector = "[rel='author'], [itemprop='author'], [class*='author' i], [class*='byline' i], [data-author]";
  var selectedFields = [
    "[class*='category'], [class*='eyebrow'], [class*='kicker']",
    "[class*='summary'], [class*='description'], [class*='excerpt'], p",
    authorFieldSelector,
    "time, [datetime], [class~='time'], [class*='timestamp' i], [class*='date' i]",
    "[class*='score' i], [data-score], [data-karma]",
    ".reply, .replies, .comment, .comments, [class*='reply'], [class*='replie'], [class*='comment']",
    "[class*='community' i], [class*='subreddit' i], [data-community]",
    "figcaption"
  ].reduce(function(fields, selector) {
    var filter = selector === authorFieldSelector ? function(node) {
      return genericListAuthorMetadataNode(node) && !genericListInteractionOwner(node);
    } : null;
    return fields.concat(listClonedCardFields(card, clone, selector, filter));
  }, []).filter(function(field) {
    return !(compactMetadataClone && compactMetadataClone.contains(field)) && field !== compactSummaryClone;
  }).concat((item.titleHeadings || []).concat(item.contextHeadingNode || []).map(function(heading) {
    return listClonedCardNode(card, clone, heading);
  }));
  pruneListCardVisibility(card, clone);
  selectedFields.forEach(function(field) {
    if (field && field.remove) field.remove();
  });
  Array.prototype.forEach.call(clone.querySelectorAll(authorFieldSelector), function(node) {
    if (genericListAuthorMetadataNode(node) && genericListInteractionOwner(node)) node.remove();
  });
  clone.querySelectorAll(genericListCardSelector()).forEach(function(nested) {
    if (nested === contentCard || (!genericListFieldBoundary(nested) &&
        nestedMetadataCards.indexOf(nested) === -1 && siblingPresentationCards.indexOf(nested) === -1)) return;
    if (supportingNestedCards.indexOf(nested) === -1) nested.remove();
  });
  var itemTitles = [item.text, item.displayText].map(normalizeText).filter(Boolean);
  var itemUrl = materializedHttpUrl(item.url || "");
  var itemKey = itemUrl && listCanonicalKey(itemUrl);
  Array.prototype.forEach.call(clone.querySelectorAll("a, h1, h2, h3, h4, [class*='title' i]"), function(node) {
    if (itemTitles.indexOf(normalizeText(node.textContent || "")) < 0) return;
    var linkedOwners = node.matches("a[href]") ? [node] : Array.from(node.querySelectorAll("a[href]"));
    if (!linkedOwners.length) {
      var linkedAncestor = node.closest("a[href]");
      if (linkedAncestor) linkedOwners.push(linkedAncestor);
    }
    if (linkedOwners.length && itemUrl && linkedOwners.some(function(linkedOwner) {
      var ownerUrl = materializedHttpUrl(linkedOwner.getAttribute("href"));
      if (!ownerUrl) return true;
      var ownerKey = listCanonicalKey(ownerUrl);
      if (ownerKey === itemKey) return false;
      return !primaryRecordKeys || !primaryRecordKeys.has(listPrimaryRecordKey(ownerUrl, node.textContent));
    })) {
      return;
    }
    node.remove();
  });
  pruneGenericListControls(clone);
  var supplemental = stripGenericListControlPhrases(listTextWithReferences(clone, true, item.url, supportingLinks));
  return supplemental === normalizeText(item.text || "") ? "" : supplemental;
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
  return contextValues.filter(Boolean).filter(function(value, index, values) {
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
