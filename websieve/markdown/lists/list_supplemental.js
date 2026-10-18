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

function listOuterSupplementalCard(item, card) {
  var owner = item.contentCard;
  var primaryUrl = materializedHttpUrl(item.url || "");
  if (!owner || card !== item.card || !owner.contains(card) || !primaryUrl ||
      closestGenericListFieldCard(item.sourceNode) !== owner) return null;
  var titleLinks = cardOwnedNodes(owner, "h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4");
  if (!titleLinks.length || !titleLinks.every(function(node) {
    var link = node.matches("a[href]") ? node : node.closest("a[href]");
    var url = materializedHttpUrl(link.getAttribute("href"));
    return url && listCanonicalKey(url) === listCanonicalKey(primaryUrl);
  })) return null;
  return cardOwnedNodes(owner, "p, blockquote").some(function(node) {
    return !card.contains(node) && !!normalizeText(node.textContent || "");
  }) ? owner : null;
}

function listSupplementalDetail(item, contextValues, card, primaryUrls, primaryRecordKeys) {
  if (!card || !card.cloneNode) return listDetailWithoutContext(item.detail, contextValues);
  var selectedContentCard = item.contentCard;
  var sourceCard = item.card;
  var outerCard = listOuterSupplementalCard(item, card);
  if (outerCard) {
    selectedContentCard = card;
    sourceCard = outerCard;
    card = outerCard;
  }
  var clone = card.cloneNode(true);
  var separatelySelectedChildren = listSeparatelySelectedChildClones(item, card, clone, primaryRecordKeys);
  var compactMetadata = listCompactMetadataRow(card, item);
  var compactMetadataClone = compactMetadata && listClonedCardNode(card, clone, compactMetadata.node);
  var compactSummarySelector = "[class*='summary'], [class*='description'], [class*='excerpt'], p";
  var compactSummary = listCompactMetadataFollowingField(card, compactMetadata, compactSummarySelector, item.summary);
  var compactSummaryClone = compactSummary && listClonedCardNode(card, clone, compactSummary);
  var contentCard = selectedContentCard && listClonedCardNode(card, clone, selectedContentCard);
  var supportingCardCache = new WeakMap();
  var supportingNestedCards = Array.prototype.filter.call(card.querySelectorAll(genericListCardSelector()), function(nested) {
    return !genericListStructuredCardLink(nested) && Array.prototype.some.call(nested.querySelectorAll("a[href]"), function(link) {
      return !!genericListSupportingCard(link, item.contentCard || card, supportingCardCache);
    });
  }).map(function(nested) { return listClonedCardNode(card, clone, nested); }).filter(Boolean);
  var supportingLinks = new WeakSet();
  var primaryProseLinks = new WeakSet();
  var descriptionOwner = listDescriptionOwnerCard(item);
  var ownerProse = descriptionOwner ? cardOwnedNodes(descriptionOwner, "p, blockquote") : [];
  var outerOwnerProse = selectedContentCard && sourceCard ? cardOwnedNodes(sourceCard, "p, blockquote").filter(function(node) {
    return !selectedContentCard.contains(node);
  }) : [];
  ownerProse = ownerProse.concat(outerOwnerProse.filter(function(node) { return ownerProse.indexOf(node) === -1; }));
  if (card !== item.card && item.supplementalSourceClones) {
    ownerProse = ownerProse.map(function(node) {
      return item.supplementalSourceClones.get(node);
    }).filter(function(node) { return node && card.contains(node); });
    outerOwnerProse = outerOwnerProse.map(function(node) {
      return item.supplementalSourceClones.get(node);
    }).filter(function(node) { return node && card.contains(node); });
  }
  var selectedContext = primaryRecordKeys && primaryRecordKeys.recordContext;
  Array.prototype.forEach.call(card.querySelectorAll("a[href]"), function(link) {
    var url = materializedHttpUrl(link.getAttribute("href"));
    var representedPrimary = primaryRecordKeys ?
      primaryRecordKeys.has(listPrimaryRecordKey(url, link.textContent)) &&
        (!selectedContext || selectedContext.selectedSources.has(link)) :
      primaryUrls && primaryUrls.has(listCanonicalKey(url));
    var prose = link.closest("p, blockquote");
    var ownedProseReference = prose && ownerProse.indexOf(prose) !== -1 &&
      (outerOwnerProse.indexOf(prose) !== -1 || normalizeText(prose.textContent || "").length >= 30);
    var ownedHeadingReference = listSupplementalHeadingReference(link, item, card);
    if (!url || (!ownedProseReference && !ownedHeadingReference && (listSupplementalInteractionLink(link) ||
        representedPrimary))) return;
    var clonedLink = listClonedCardNode(card, clone, link);
    if (clonedLink) {
      supportingLinks.add(clonedLink);
      if (ownedProseReference) primaryProseLinks.add(clonedLink);
    }
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
    if (selector === compactSummarySelector && selectedContentCard) {
      filter = function(node) { return selectedContentCard.contains(node); };
    }
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
  clone.querySelectorAll("*").forEach(function(nested) {
    if (separatelySelectedChildren.has(nested)) nested.remove();
  });
  clone.querySelectorAll(genericListCardSelector()).forEach(function(nested) {
    if (nested === contentCard || (!genericListFieldBoundary(nested) &&
        nestedMetadataCards.indexOf(nested) === -1 && siblingPresentationCards.indexOf(nested) === -1)) return;
    if (supportingNestedCards.indexOf(nested) === -1) nested.remove();
  });
  var representedValues = [item.text, item.displayText].concat(contextValues || []).map(normalizeText).filter(Boolean);
  var itemUrl = materializedHttpUrl(item.url || "");
  var itemKey = itemUrl && listCanonicalKey(itemUrl);
  Array.prototype.forEach.call(clone.querySelectorAll("a, span, p, div, h1, h2, h3, h4, h5, h6, [class*='title' i]"), function(node) {
    if (representedValues.indexOf(normalizeText(node.textContent || "")) < 0) return;
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
  var supplemental = stripGenericListControlPhrases(listTextWithReferences(clone, true, item.url, supportingLinks, primaryProseLinks));
  return representedValues.indexOf(supplemental) >= 0 ? "" : supplemental;
}
